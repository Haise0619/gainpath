import {AggregateField, FieldPath, type Firestore, type Query, type QueryDocumentSnapshot} from 'firebase-admin/firestore';
import {DomainError} from '../../platform/errors';
import type {DocumentData, DocumentStore} from '../../platform/firestore/store';
import {requiredIdentifier} from '../../platform/validation';
import {coachRatings} from '../coaching/coach-rating-service';
import {getCoachAvailabilityService, getCoachRosterService} from '../coaching/coach-availability-service';
import {getBookingListService} from '../coaching/booking-list-service';
import {getMemberBookingOptionsService} from '../coaching/member-booking-options-service';
import {module9MemberCommand, type NotificationReader} from '../coaching/module9-member-service';
import {getCoachCertifications} from '../coaching/coach-certification-service';
import {getCoachPublishedPhoto} from '../coaching/coach-photo-service';
import {adminReport} from '../analytics/admin-reporting';
import {adminCheckInReport} from '../analytics/admin-check-in-reporting';
import {workoutPrograms} from '../content/workout-programs';
import type {FreshAuthIdentity, InsightsRequest} from '../recommendation/exercise-insights-contracts';
import {requireFypScope, isFypAdminReadScope, requireFypRuntimeCapability, type FypScope, type FypRuntimeCapability} from './fyp-scope';

export interface FypModuleReadDependencies {
  db: Firestore;
  scope: FypScope;
  /** Already bound through createFypScopedStore; services retain logical paths. */
  store: DocumentStore;
  clock: () => number;
  readAuthIdentity: (uid: string) => Promise<FreshAuthIdentity>;
  fypCapability: FypRuntimeCapability;
  projectRecommendation?: NotificationReader['projectRecommendation'];
}

const operations = new Set(['getCoachRatingsCommand', 'getCoachAvailabilityCommand', 'getCoachRosterCommand',
  'getBookingListCommand', 'getMemberBookingOptionsCommand', 'module9MemberCommandCallable', 'adminReportingCommand', 'adminCheckInReportingCommand',
  'workoutProgramCommand', 'getCoachCertificationsCommand', 'getCoachPublishedPhotoCommand'].map(name => `module/${name}`));
const unavailable = () => new DomainError('failed-precondition', 'This action is unavailable for the fictional dataset.');
const denied = () => new DomainError('permission-denied', 'Current dataset access is required.');

/** Only fixed existing read operations. No client-selected paths, roles or scopes. */
export async function fypModuleRead(operation: string, request: InsightsRequest, deps: FypModuleReadDependencies): Promise<unknown> {
  requireFypScope(deps.scope);
  if (!requireFypRuntimeCapability(deps.fypCapability, deps.scope.organizationId)) throw denied();
  if (!operations.has(operation)) throw unavailable();
  const auth = request.auth;
  if (!request.app?.appId || !auth || auth.token.email_verified !== true || typeof auth.token.email !== 'string'
      || !Number.isSafeInteger(auth.token.auth_time)) throw new DomainError('unauthenticated', 'Verified Auth and App Check are required.');
  if (auth.uid !== deps.scope.uid) throw denied();
  const d = request.data as DocumentData;
  if (!d || typeof d !== 'object' || Array.isArray(d) || requiredIdentifier(d.organizationId, 'organizationId') !== deps.scope.organizationId) throw denied();
  if (operation === 'module/workoutProgramCommand' && !['list', 'adminList'].includes(String(d.action))) throw unavailable();
  if (operation === 'module/module9MemberCommandCallable' && !['inbox', 'readNotification'].includes(String(d.action))) throw unavailable();

  const org = deps.scope.organizationId, root = deps.scope.rootPath;
  const fresh = async () => {
    const current = await deps.readAuthIdentity(auth.uid);
    if (current.uid !== auth.uid || current.disabled || !current.emailVerified || current.email !== auth.token.email
        || !Number.isFinite(current.tokensValidAfterMillis) || Number(auth.token.auth_time) * 1000 < current.tokensValidAfterMillis) {
      throw new DomainError('unauthenticated', 'Your account session changed.');
    }
    // The bound transaction also revalidates the current assignment and manifest.
    await deps.store.transact(async tx => {
      const user = await tx.get(`users/${auth.uid}`), member = await tx.get(`orgs/${org}/members/${auth.uid}`);
      if (user?.organizationId !== org || user.role !== deps.scope.role && (!isFypAdminReadScope(deps.scope) || user.role !== undefined) || (!isFypAdminReadScope(deps.scope) || user.status !== undefined) && user.status !== 'active'
          || member?.organizationId !== org || member.userId !== auth.uid || member.role !== deps.scope.role || member.status !== 'active') throw denied();
    });
  };
  await fresh();
  // Prevent accidental authoring if any reused service later gains a write branch.
  // The existing nonrecommendation read acknowledgement is the sole exception.
  const acknowledgement = operation === 'module/module9MemberCommandCallable' && d.action === 'readNotification'
    ? `orgs/${org}/notifications/${requiredIdentifier(d.notificationId, 'notificationId')}` : undefined;
  const store: DocumentStore = {transact: work => deps.store.transact(tx => work({
    get: path => tx.get(path),
    ...(tx.getAll ? {getAll: (paths: readonly string[]) => tx.getAll!(paths)} : {}),
    create: () => {throw unavailable();},
    set: (path, value) => {
      const data = value as DocumentData;
      if (!acknowledgement || path !== acknowledgement || data.recipientId !== auth.uid || data.read !== true) throw unavailable();
      tx.set(path, value);
    },
  }))};
  const checkOrg = (value: string) => {if (value !== org) throw denied();};
  const checkPath = (path: string) => {
    if (!path.startsWith(root + '/') || path.split('/').some(p => !/^[A-Za-z0-9_-]{1,140}$/.test(p))) throw denied();
  };
  const checkedRows = (path: string, rows: QueryDocumentSnapshot[]) => rows.map(doc => {
    if (doc.ref.path !== `${path}/${doc.id}`) throw denied();
    return {id: doc.id, data: doc.data()};
  });
  const page = async (path: string, after: string | undefined, count: number) => {
    checkPath(path);
    let q = deps.db.collection(path).orderBy(FieldPath.documentId()).limit(count);
    if (after) q = q.startAfter(after);
    return checkedRows(path, (await q.get()).docs);
  };

  let result: unknown;
  switch (operation) {
    case 'module/getCoachRatingsCommand':
      result = await coachRatings(store, auth, d, {aggregate: async (organizationId, coachId) => {
        checkOrg(organizationId); requiredIdentifier(coachId, 'coachId');
        const data = (await deps.db.collection(`${root}/coaches/${coachId}/reviews`).where('stars', '>=', 1).where('stars', '<=', 5)
          .aggregate({count: AggregateField.count(), total: AggregateField.sum('stars')}).get()).data();
        return {count: data.count, total: data.total};
      }}); break;
    case 'module/getCoachAvailabilityCommand':
      result = await getCoachAvailabilityService(store, auth, d, deps.clock); break;
    case 'module/getCoachRosterCommand':
      result = await getCoachRosterService(store, auth, d, deps.clock); break;
    case 'module/getCoachCertificationsCommand':
      result = await getCoachCertifications(store, auth, d); break;
    case 'module/getCoachPublishedPhotoCommand':
      // No object is present in this source graph. The real service returns its
      // normal null contract for no photo, and denies malformed/publication drift.
      result = await getCoachPublishedPhoto(store, auth, d, async () => {throw unavailable();}); break;
    case 'module/getBookingListCommand':
      result = await getBookingListService(store, auth, d, {read: async input => {
        checkOrg(input.organizationId);
        const path = `${root}/bookings`;
        let q: Query = deps.db.collection(path).where(input.ownerField, '==', input.ownerId);
        if (input.branchIds !== undefined) q = q.where('branchId', 'in', [...input.branchIds]);
        q = q.where('startAtMillis', '>=', input.firstStartAtMillis).where('startAtMillis', '<', input.throughStartAtMillis)
          .orderBy('startAtMillis', 'asc').orderBy(FieldPath.documentId(), 'asc');
        if (input.cursor) q = q.startAfter(input.cursor.startAtMillis, input.cursor.bookingId);
        return checkedRows(path, (await q.limit(input.limit).get()).docs)
          .map(row => ({path: `orgs/${org}/bookings/${row.id}`, data: row.data}));
      }}, deps.clock); break;
    case 'module/getMemberBookingOptionsCommand':
      result = await getMemberBookingOptionsService(store, auth, d, async uid => {
        try {
          const current = await deps.readAuthIdentity(uid);
          return {exists: current.uid === uid, disabled: current.disabled, emailVerified: current.emailVerified};
        } catch (error) {
          if ((error as {code?: string}).code === 'auth/user-not-found') return {exists: false, disabled: false, emailVerified: false};
          throw error;
        }
      }, deps.clock); break;
    case 'module/module9MemberCommandCallable':
      result = await module9MemberCommand(store, auth, d, deps.clock, {
        projectRecommendation: deps.projectRecommendation,
        list: async (organizationId, uid, afterId) => {
          checkOrg(organizationId); if (uid !== auth.uid) throw denied();
          const path = `${root}/notifications`;
          let q = deps.db.collection(path).where('recipientId', '==', uid).orderBy('createdAtMillis', 'desc').orderBy(FieldPath.documentId(), 'desc');
          if (afterId) {
            requiredIdentifier(afterId, 'afterId');
            const cursor = await deps.db.doc(`${path}/${afterId}`).get();
            if (!cursor.exists || cursor.data()?.recipientId !== uid) throw denied();
            q = q.startAfter(cursor);
          }
          return checkedRows(path, (await q.limit(31).get()).docs);
        },
      }); break;
    case 'module/workoutProgramCommand':
      result = await workoutPrograms(store, auth, d, {freshAuth: fresh, clock: deps.clock}); break;
    case 'module/adminReportingCommand':
      result = await adminReport(store, auth, d, {
        page: (kind, after, count) => page(`${root}/${kind}`, after, count),
        identity: async uid => {
          try {const current = await deps.readAuthIdentity(uid); return {exists: true, disabled: current.disabled, emailVerified: current.emailVerified};}
          catch (error) {if ((error as {code?: string}).code === 'auth/user-not-found') return {exists: false, disabled: false, emailVerified: false}; throw error;}
        },
      }, deps.clock); break;
    case 'module/adminCheckInReportingCommand':
      result = await adminCheckInReport(store, auth, d, {
        members: (after, count) => page(`${root}/members`, after, count),
        claims: (uid, after, count) => page(`${root}/appCheckInProfiles/${requiredIdentifier(uid, 'uid')}/claims`, after, count),
        page: (kind, after, count) => page(`${root}/${kind}`, after, count),
        observations: {
          page: (kind, after, count) => page(`${root}/${kind}`, after, count),
          backups: (uid, after, count) => page(`${root}/members/${requiredIdentifier(uid, 'uid')}/workoutBackups`, after, count),
        },
      }, deps.clock); break;
    default: throw unavailable();
  }
  await fresh();
  return result;
}
