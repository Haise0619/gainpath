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
  keys(v, write
    ? ['schemaVersion','organizationId','memberId','consented','kind','id','baseDigest','payload']
    : ['schemaVersion','organizationId','memberId','consented','after']);
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
  return {schemaVersion:1,records,nextCursor:docs.length === 3 ? String(docs.at(-1)!.key) : kind === 'session' ? 'routines' : null};
}
