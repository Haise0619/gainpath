import { DomainError } from '../../platform/errors';
import { requireVerifiedEmail, requireActiveMembership } from '../../platform/auth-context';
import { requiredIdentifier, InputValidationError } from '../../platform/validation';
import type { DocumentStore, DocumentData, TransactionPort } from '../../platform/firestore/store';
import { object, keys, digestOf, validateBackupPayload } from './workout-backup-validation';
import type { WorkoutAuth } from './workout-service';

export interface BackupStore extends DocumentStore {
  // Scan ascending keys within one kind; sessions are paged before routines.
  list(prefix: string, after: string | null, limit: number, kind: 'session' | 'routine'): Promise<DocumentData[]>;
}
function input(auth: WorkoutAuth | undefined, raw: unknown, write: boolean) {
  requireVerifiedEmail(auth);
  const v = object(raw);
  const required = write
    ? ['schemaVersion','organizationId','memberId','consented','kind','id','baseDigest','payload']
    : ['schemaVersion','organizationId','memberId','consented','after'];
  keys(v, write ? required : [...required,'maxPoseMetricsSchemaVersion'], required);
  const org = requiredIdentifier(v.organizationId,'organizationId');
  const uid = requiredIdentifier(v.memberId,'memberId');
  if (auth!.uid !== uid) throw new DomainError('permission-denied','Only your own backup is accessible.');
  if (v.schemaVersion !== 1 || v.consented !== true) throw new InputValidationError('Explicit backup consent required.');
  return {v,org,uid};
}
async function member(tx: TransactionPort, auth: WorkoutAuth, org: string, uid: string) {
  const [u,m,o] = await Promise.all([
    tx.get('users/'+uid),tx.get(`orgs/${org}/members/${uid}`),tx.get('orgs/'+org),
  ]);
  if (u?.organizationId !== org || m?.organizationId !== org ||
      requireActiveMembership(m).role !== 'member' || o?.status !== 'active' ||
      (m.userId !== undefined && m.userId !== uid)) {
    throw new DomainError('permission-denied','Active canonical membership required.');
  }
  if (u.accountLifecycle !== undefined) {
    const a = object(u.accountLifecycle);
    if (a.state !== 'active' || a.revocationPending !== false ||
        !Number.isSafeInteger(a.sessionNotBeforeSeconds) || !Number.isSafeInteger(auth.token.auth_time) ||
        Number(auth.token.auth_time) < Number(a.sessionNotBeforeSeconds)) {
      throw new DomainError('permission-denied','Account session changed.');
    }
  }
}
export async function backupWorkout(store: BackupStore, auth: WorkoutAuth | undefined, raw: unknown) {
  const {v,org,uid} = input(auth,raw,true);
  const kind = String(v.kind), id = requiredIdentifier(v.id,'id');
  const payload = validateBackupPayload(kind,id,org,uid,v.payload), digest = digestOf(payload);
  if (v.baseDigest !== null && (typeof v.baseDigest !== 'string' || !/^[a-f0-9]{64}$/.test(v.baseDigest))) {
    throw new InputValidationError('Invalid base revision.');
  }
  const key = kind+'-'+id, path = `orgs/${org}/members/${uid}/workoutBackups/${key}`;
  return store.transact(async tx => {
    await member(tx,auth!,org,uid);
    const previous = await tx.get(path);
    if (previous?.digest === digest) return {schemaVersion:1,status:'backed_up',kind,id,digest};
    if ((previous && (kind === 'session' || previous.digest !== v.baseDigest)) ||
        (!previous && v.baseDigest !== null)) {
      throw new DomainError('already-exists','Backup conflict. Both copies are retained.');
    }
    const revision = await tx.get(path+'/revisions/'+digest);
    const record = {schemaVersion:1,kind,id,key,digest,payloadJson:JSON.stringify(payload),
      classification:'provisional_member_backup',updatedAtMillis:Date.now()};
    if (!revision) tx.create(path+'/revisions/'+digest,record);
    tx.set(path,record);
    return {schemaVersion:1,status:'backed_up',kind,id,digest};
  });
}
export async function listWorkoutBackups(store: BackupStore, auth: WorkoutAuth | undefined, raw: unknown) {
  const {v,org,uid} = input(auth,raw,false);
  // Existing clients understand metric schemas 1/2 and send no negotiation.
  const maximum = 'maxPoseMetricsSchemaVersion' in v ? v.maxPoseMetricsSchemaVersion : 2;
  if (!Number.isSafeInteger(maximum) || Number(maximum) < 2 || Number(maximum) > 6) {
    throw new InputValidationError('Invalid supported pose metric version.');
  }
  const after = v.after === null ? null : String(v.after);
  if (after !== null && after !== 'routines' && !/^(session|routine)-[A-Za-z0-9_-]{1,128}$/.test(after)) {
    throw new InputValidationError('Invalid cursor.');
  }
  const kind = after === 'routines' || after?.startsWith('routine-') ? 'routine' : 'session';
  await store.transact(tx => member(tx,auth!,org,uid));
  const docs = await store.list(`orgs/${org}/members/${uid}/workoutBackups`,after === 'routines' ? null : after,3,kind);
  await store.transact(tx => member(tx,auth!,org,uid));
  const records = docs.map(d => {
    if (d.classification !== 'provisional_member_backup' || typeof d.payloadJson !== 'string') {
      throw new DomainError('failed-precondition','Invalid backup record.');
    }
    const p = validateBackupPayload(String(d.kind),String(d.id),org,uid,JSON.parse(d.payloadJson));
    if (d.digest !== digestOf(p) || d.key !== d.kind+'-'+d.id) {
      throw new DomainError('failed-precondition','Backup integrity failed.');
    }
    return {kind:d.kind,id:d.id,digest:d.digest,payload:p};
  });
  // Verify the whole scanned page before compatibility filtering: an unreadable
  // client schema never hides corruption. Cursor progress follows scanned docs.
  const supported = records.filter(record => {
    if (record.kind === 'session') return Number(object(record.payload.poseMetrics).schemaVersion) <= Number(maximum);
    if (Number(maximum) >= 6) return true;
    const routine = object(object(record.payload.attempt).routine);
    return !(routine.exercises as unknown[]).some(exercise => {
      const id = object(exercise).exerciseId;
      return id === 'standing-lateral-raise-front-v1' ||
        (Number(maximum) < 5 && id === 'bodyweight-reverse-lunge-side-v1') ||
        (Number(maximum) < 4 && id === 'dumbbell-shoulder-press-front-v1') ||
        (Number(maximum) < 3 && id === 'single-arm-dumbbell-row-side-v1');
    });
  });
  return {schemaVersion:1,records:supported,nextCursor:docs.length === 3 ? String(docs.at(-1)!.key) : kind === 'session' ? 'routines' : null};
}
