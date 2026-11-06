import {beforeAll, expect, it} from 'vitest';
import type {Firestore} from 'firebase-admin/firestore';
import type {DocumentData} from '../src/platform/firestore/store';
import {MemoryStore} from './memory-store';
import {buildFypDataset, FYP_ROOT, fypDigest, type FypDataset} from '../src/modules/dataset/fyp-dataset';
import {createFypScopedStore, mintFypRuntimeCapability, resolveFypScope} from '../src/modules/dataset/fyp-scope';
import {fypModuleRead} from '../src/modules/dataset/fyp-module-services';

const now = Date.UTC(2026, 10, 3, 4);
let dataset: FypDataset;
beforeAll(async () => {dataset = await buildFypDataset({anchorMillis: now});});

/** Deliberately fails any Admin SDK query escaping the cohort root. */
function queryDb(store: MemoryStore) {
  const paths: string[] = [];
  let onRead: (() => void) | undefined;
  const document = (path: string) => ({id: path.split('/').at(-1)!, ref: {path}, exists: store.documents.has(path), data: () => store.documents.get(path)});
  const db = {collection(path: string) {
    if (!path.startsWith(`${FYP_ROOT}/`)) throw Error(`Unscoped Admin SDK query: ${path}`);
    paths.push(path);
    const filters: [string, string, unknown][] = [], orders: [string, string][] = [];
    let count = Infinity, after: unknown[] = [];
    const rows = () => {
      let records = [...store.documents.keys()].filter(p => p.startsWith(path + '/') && p.slice(path.length + 1).indexOf('/') < 0).map(document);
      records = records.filter(r => filters.every(([key, op, value]) => {
        const actual = r.data()?.[key];
        if (op === '==') return actual === value;
        if (op === 'in') return (value as unknown[]).includes(actual);
        if (op === '>=') return Number(actual) >= Number(value);
        if (op === '<=') return Number(actual) <= Number(value);
        if (op === '<') return Number(actual) < Number(value);
        throw Error(`Unsupported test filter ${op}`);
      }));
      records.sort((a, b) => {for (const [key, dir] of orders) {
        const av = key === '__name__' ? a.id : a.data()?.[key], bv = key === '__name__' ? b.id : b.data()?.[key];
        const c = av === bv ? 0 : av! < bv! ? -1 : 1; if (c) return dir === 'desc' ? -c : c;
      } return 0;});
      if (after.length && typeof after[0] === 'string' && orders[0]?.[0] === '__name__') records = records.filter(r => r.id > String(after[0]));
      return records.slice(0, count);
    };
    const q = {
      where(key: string, op: string, value: unknown) {filters.push([key, op, value]); return q;},
      orderBy(key: unknown, dir = 'asc') {orders.push([typeof key === 'string' ? key : '__name__', dir]); return q;},
      startAfter(...values: unknown[]) {after = values; return q;},
      limit(value: number) {count = value; return q;},
      async get() {onRead?.(); return {docs: rows()};},
      aggregate() {return {get: async () => {onRead?.(); return {data: () => ({count: rows().length, total: rows().reduce((n, r) => n + Number(r.data()?.stars), 0)})};}};},
    }; return q;
  }, doc(path: string) {
    if (!path.startsWith(`${FYP_ROOT}/`)) throw Error(`Unscoped Admin SDK document: ${path}`);
    paths.push(path); return {get: async () => document(path)};
  }};
  return {db: db as unknown as Firestore, paths, beforeRead: (hook: () => void) => {onRead = hook;}};
}

async function fixture(role: 'member' | 'coach' | 'admin' = 'member') {
  const store = new MemoryStore();
  for (const [p, d] of Object.entries(dataset.documents)) store.documents.set(p, structuredClone(d));
  const uid = role === 'admin' ? dataset.adminId : role === 'coach' ? dataset.coachIds[0] : dataset.memberIds[0];
  const identity = dataset.identities.find(i => i.uid === uid)!;
  store.documents.set(`datasetAssignments/${uid}`, {schemaVersion: 1, datasetId: 'fyp-v1', organizationId: 'gainpath', seedId: 'gainpath-fyp-v1', enabled: true, role, revision: 1, authCreatedAtMillis: 1000});
  const request = {app: {appId: 'test-app'}, auth: {uid, token: {email: identity.email, email_verified: true, auth_time: Math.floor(now / 1000), fypAuthCreatedAtMillis: 1000}}, data: {schemaVersion: 1, organizationId: 'gainpath'}};
  const readAuthIdentity = async (target: string) => ({uid: target, email: dataset.identities.find(i => i.uid === target)!.email, emailVerified: true, disabled: false, tokensValidAfterMillis: 0, creationTimeMillis: 1000});
  const scope = await resolveFypScope({...request, data: {schemaVersion: 1}}, {store, identity: readAuthIdentity});
  const query = queryDb(store);
  const deps = {db: query.db, scope, store: createFypScopedStore(store, scope), clock: () => now, readAuthIdentity, fypCapability: mintFypRuntimeCapability(scope)};
  const call = (op: string, data: DocumentData = {}) => fypModuleRead(`module/${op}`, {...request, data: {...request.data, ...data}}, deps);
  return {store, deps, request, call, uid, paths: query.paths, beforeRead: query.beforeRead};
}

it('uses real published Coach rating aggregates only inside the cohort namespace', async () => {
  const f = await fixture(), coachId = dataset.coachIds[0];
  f.store.documents.set(`${FYP_ROOT}/coaches/${coachId}/reviews/a`, {stars: 4});
  f.store.documents.set(`${FYP_ROOT}/coaches/${coachId}/reviews/b`, {stars: 5});
  f.store.documents.set(`orgs/gainpath/coaches/${coachId}/reviews/ordinary`, {stars: 1});
  expect(await f.call('getCoachRatingsCommand', {coachIds: [coachId]})).toEqual({schemaVersion: 1, records: [{coachId, reviewCount: 2, averageRating: 4.5}]});
  expect(f.paths).toEqual([`${FYP_ROOT}/coaches/${coachId}/reviews`]);
});
it('reuses existing availability, Program and photo contracts against scoped source records', async () => {
  const f = await fixture(), coachId = dataset.coachIds[0];
  expect(await f.call('getCoachAvailabilityCommand', {coachId, dayCount: 7})).toMatchObject({schemaVersion: 1, coachId, todayLocalDate: '2026-11-03'});
  const programs = await f.call('workoutProgramCommand', {action: 'list'}) as {programs: unknown[]};
  expect(programs.programs).toHaveLength(3);
  expect(await f.call('getCoachPublishedPhotoCommand', {coachId})).toEqual({schemaVersion: 1, photoPath: null, contentType: null, bytesBase64: null});
});
it('returns the existing owned booking-list contract without canonical queries or mutations', async () => {
  const f = await fixture(), before = structuredClone([...f.store.documents]);
  expect(await f.call('getBookingListCommand', {})).toMatchObject({schemaVersion: 1, records: [], firstLocalDate: '2026-11-03'});
  expect(f.paths).toEqual([`${FYP_ROOT}/bookings`]);
  expect([...f.store.documents]).toEqual(before);
});
it('returns real bounded Member booking options without creating holds or payment records', async () => {
  const f = await fixture(), before = structuredClone([...f.store.documents]), coachId = dataset.coachIds[0];
  const result = await f.call('getMemberBookingOptionsCommand', {coachId, durationMinutes: 60, localDate: dataset.legacyDataset.bookingDate}) as {options: {branchId: string; startAtMillis: number; endAtMillis: number}[]};
  expect(result).toMatchObject({schemaVersion: 1, coachId, durationMinutes: 60, localDate: dataset.legacyDataset.bookingDate, permittedBranchIds: ['main']});
  expect(result.options.length).toBeGreaterThan(0);
  expect(result.options.length).toBeLessThanOrEqual(48);
  expect(result.options.every(o => o.branchId === 'main' && o.endAtMillis - o.startAtMillis === 3600000)).toBe(true);
  expect([...f.store.documents]).toEqual(before);
  expect(f.paths).toEqual([]);
  f.store.documents.get(`${FYP_ROOT}/coaches/${coachId}`)!.status = 'inactive';
  await expect(f.call('getMemberBookingOptionsCommand', {coachId, durationMinutes: 30})).rejects.toMatchObject({code: 'failed-precondition'});
});
it('booking options preserve Member-only ownership, target Auth verification and malformed-input rejection', async () => {
  const admin = await fixture('admin');
  await expect(admin.call('getMemberBookingOptionsCommand', {coachId: dataset.coachIds[0], durationMinutes: 30})).rejects.toMatchObject({code: 'permission-denied'});
  const f = await fixture(), data = {...f.request.data, coachId: dataset.coachIds[0], durationMinutes: 60};
  await expect(fypModuleRead('module/getMemberBookingOptionsCommand', {...f.request, data}, {...f.deps,
    readAuthIdentity: async uid => ({...await f.deps.readAuthIdentity(uid), disabled: uid === dataset.coachIds[0]})})).rejects.toMatchObject({code: 'failed-precondition'});
  await expect(f.call('getMemberBookingOptionsCommand', {coachId: dataset.coachIds[0], durationMinutes: 45})).rejects.toThrow();
  await expect(f.call('getMemberBookingOptionsCommand', {coachId: dataset.coachIds[0], durationMinutes: 30, memberId: dataset.memberIds[1]})).rejects.toThrow();
});
it('reuses Admin roster, credential, Program and reporting services with cohort-only denominators', async () => {
  const f = await fixture('admin'), coachId = dataset.coachIds[0];
  f.store.documents.set('users/ordinary', {organizationId: 'gainpath', role: 'member'});
  f.store.documents.set('orgs/gainpath/members/ordinary', {organizationId: 'gainpath', userId: 'ordinary', role: 'member', status: 'active'});
  expect(await f.call('getCoachRosterCommand', {coachId})).toMatchObject({schemaVersion: 1, coachId});
  expect(await f.call('getCoachCertificationsCommand', {coachId})).toMatchObject({schemaVersion: 1, approvedCount: 1, certificationVerified: true});
  expect((await f.call('workoutProgramCommand', {action: 'adminList'}) as {drafts: unknown[]}).drafts).toHaveLength(3);
  const dates = {schemaVersion: 2, startAtMillis: now - 30 * 86400000, endAtMillis: now};
  expect(await f.call('adminReportingCommand', dates)).toMatchObject({currentAccounts: {members: 18, coaches: 7}, sourceCounts: {bookings: 0, transactions: 0}});
  expect(await f.call('adminCheckInReportingCommand', dates)).toMatchObject({coverage: {activeMembers: 18, claimsScanned: 0}, totals: {claims: 0, claimingMembers: 0, pointsAwarded: 0}});
  expect(f.paths.every(p => p.startsWith(`${FYP_ROOT}/`))).toBe(true);
});
it('preserves role checks and rejects foreign organization, forged scope and mismatched actor', async () => {
  const f = await fixture();
  for (const op of ['getCoachRosterCommand', 'getCoachCertificationsCommand']) await expect(f.call(op, {coachId: dataset.coachIds[0]})).rejects.toMatchObject({code: 'permission-denied'});
  await expect(f.call('workoutProgramCommand', {action: 'adminList'})).rejects.toMatchObject({code: 'permission-denied'});
  await expect(f.call('adminReportingCommand', {startAtMillis: now - 1000, endAtMillis: now})).rejects.toMatchObject({code: 'permission-denied'});
  await expect(f.call('getCoachRatingsCommand', {organizationId: 'foreign', coachIds: [dataset.coachIds[0]]})).rejects.toMatchObject({code: 'permission-denied'});
  await expect(fypModuleRead('module/getCoachRatingsCommand', {...f.request, auth: {...f.request.auth, uid: 'ordinary'}}, f.deps)).rejects.toMatchObject({code: 'permission-denied'});
  await expect(fypModuleRead('module/getCoachRatingsCommand', f.request, {...f.deps, scope: {...f.deps.scope}})).rejects.toMatchObject({code: 'permission-denied'});
});
it('rejects unsupported commands and authoring actions before any writes or Admin SDK query', async () => {
  const f = await fixture('admin'), before = structuredClone([...f.store.documents]);
  for (const op of ['saveCoachRosterCommand', 'createBookingHoldCommand', 'manageAdminBookingPaymentCommand', 'miniGameRewardsCommand', '../../payments']) {
    await expect(f.call(op)).rejects.toMatchObject({code: 'failed-precondition'});
  }
  for (const action of ['saveDraft', 'publish']) await expect(f.call('workoutProgramCommand', {action})).rejects.toMatchObject({code: 'failed-precondition'});
  await expect(f.call('module9MemberCommandCallable', {action: 'sharing', enabled: true})).rejects.toMatchObject({code: 'failed-precondition'});
  expect(f.paths).toEqual([]); expect([...f.store.documents]).toEqual(before);
});
it('serves only owned notifications and preserves idempotent nonrecommendation reads', async () => {
  const f = await fixture(), own = `${FYP_ROOT}/notifications/own`;
  const notice = {schemaVersion: 1, recipientId: f.uid, type: 'booking', title: 'Fictional reminder', message: 'Source reminder', createdAtMillis: now - 1000, read: false};
  f.store.documents.set(own, notice);
  f.store.documents.set(`${FYP_ROOT}/generatedOwnership/${fypDigest(own)}`,{schemaVersion:1,datasetId:dataset.datasetId,seedId:dataset.seedId,path:own,digest:fypDigest(notice)});
  f.store.documents.set(`${FYP_ROOT}/notifications/foreign`, {...notice, recipientId: dataset.memberIds[1]});
  expect(await f.call('module9MemberCommandCallable', {action: 'inbox'})).toMatchObject({schemaVersion: 1, records: [{id: 'own', title: notice.title, read: false}], nextAfterId: null});
  await expect(f.call('module9MemberCommandCallable', {action: 'inbox', afterId: 'foreign'})).rejects.toMatchObject({code: 'permission-denied'});
  for (let i = 0; i < 2; i++) expect(await f.call('module9MemberCommandCallable', {action: 'readNotification', notificationId: 'own'})).toEqual({schemaVersion: 1, id: 'own', read: true});
  await expect(f.call('module9MemberCommandCallable', {action: 'readNotification', notificationId: 'foreign'})).rejects.toMatchObject({code: 'permission-denied'});
  expect(f.store.documents.get(own)).toEqual({...notice, read: true});
});
it('fails closed when current Auth or assignment is revoked rather than returning partial results', async () => {
  const f = await fixture();
  await expect(fypModuleRead('module/getCoachRatingsCommand', {...f.request, data: {...f.request.data, coachIds: [dataset.coachIds[0]]}}, {...f.deps, readAuthIdentity: async uid => ({...await f.deps.readAuthIdentity(uid), disabled: true})})).rejects.toMatchObject({code: 'unauthenticated'});
  f.store.documents.get(`datasetAssignments/${f.uid}`)!.enabled = false;
  await expect(f.call('getCoachRatingsCommand', {coachIds: [dataset.coachIds[0]]})).rejects.toMatchObject({code: 'permission-denied'});
});
it('requires App Check and verified Auth even when given a legitimate scoped capability', async () => {
  const f = await fixture();
  for (const request of [{...f.request, app: undefined}, {...f.request, auth: undefined},
    {...f.request, auth: {...f.request.auth, token: {...f.request.auth.token, email_verified: false}}}]) {
    await expect(fypModuleRead('module/getCoachRatingsCommand', request, f.deps)).rejects.toMatchObject({code: 'unauthenticated'});
  }
  expect(f.paths).toEqual([]);
});
it('passes recommendation notices through the protected projection and forbids the ordinary read mutation', async () => {
  const f = await fixture(), recommendationId = 'a'.repeat(64), expiresAtMillis = now + 60000;
  f.store.documents.set(`${FYP_ROOT}/notifications/recommendation`, {schemaVersion: 1, recipientId: f.uid, type: 'recommendation',
    recommendationId, recommendationKind: 'trainer', title: 'Private title', message: 'Private message', createdAtMillis: now - 1000, read: false});
  const recommendation = {schemaVersion: 1 as const, recommendationId, kind: 'trainer' as const, state: 'unavailable' as const, expiresAtMillis, target: null};
  const result = await fypModuleRead('module/module9MemberCommandCallable', {...f.request, data: {...f.request.data, action: 'inbox'}}, {
    ...f.deps, projectRecommendation: async (org, uid, id) => {
      expect([org, uid, id]).toEqual(['gainpath', f.uid, 'recommendation']);
      return {title: 'Recommendation unavailable', message: 'Current consent checked', recommendation};
    },
  });
  expect(result).toMatchObject({records: [{id: 'recommendation', title: 'Recommendation unavailable', message: 'Current consent checked', recommendation}]});
  await expect(f.call('module9MemberCommandCallable', {action: 'readNotification', notificationId: 'recommendation'})).rejects.toMatchObject({code: 'failed-precondition'});
});
it('does not access Storage or invent an asset when published photo metadata claims a missing image', async () => {
  const f = await fixture(), coachId = dataset.coachIds[0];
  f.store.documents.get(`${FYP_ROOT}/coaches/${coachId}`)!.photoPath = `orgs/gainpath/coachProfilePhotos/${coachId}/${'a'.repeat(32)}`;
  await expect(f.call('getCoachPublishedPhotoCommand', {coachId})).rejects.toMatchObject({code: 'failed-precondition'});
  expect(f.paths).toEqual([]);
});
it('revalidates Auth and the server-owned assignment after asynchronous query reads', async () => {
  const f = await fixture(); let checks = 0;
  const request = {...f.request, data: {...f.request.data, coachIds: [dataset.coachIds[0]]}};
  await expect(fypModuleRead('module/getCoachRatingsCommand', request, {...f.deps, readAuthIdentity: async uid => ({...await f.deps.readAuthIdentity(uid), disabled: ++checks > 1})})).rejects.toMatchObject({code: 'unauthenticated'});
  expect(checks).toBe(2);
  f.beforeRead(() => {f.store.documents.get(`datasetAssignments/${f.uid}`)!.enabled = false;});
  await expect(f.call('getCoachRatingsCommand', {coachIds: [dataset.coachIds[0]]})).rejects.toMatchObject({code: 'permission-denied'});
});
