import { randomBytes } from 'node:crypto';
import type { Auth, UserRecord } from 'firebase-admin/auth';
import { professional } from '../coaching/coach-profile-service';
import { branchIds } from '../coaching/coach-availability-contracts';
import { authorizeAdminReport } from '../analytics/admin-reporting';
import { DomainError } from '../../platform/errors';
import type { DocumentStore } from '../../platform/firestore/store';
import { keyOf } from '../../platform/idempotency';
import { requiredIdentifier } from '../../platform/validation';

type Actor = Parameters<typeof authorizeAdminReport>[1];
type AuthWriter = Pick<Auth, 'getUser' | 'createUser' | 'updateUser'>;
const authCode = (error: unknown) => (error as {code?: string} | null)?.code;

export async function provisionCoach(store: DocumentStore, auth: AuthWriter, actor: Actor, input: Record<string, unknown>) {
  const org = requiredIdentifier(input.organizationId, 'organizationId');
  const requestId = requiredIdentifier(input.requestId, 'requestId');
  if (Object.keys(input).some(key => !['action','organizationId','requestId','email','phone','displayName','specialty','bio','yearsExperience','consultationFeeMinor','specializationTags','branchIds'].includes(key))) {
    throw new DomainError('invalid-argument', 'Unsupported Coach account field.');
  }
  const email = typeof input.email === 'string' ? input.email.trim().toLowerCase() : '';
  const phone = typeof input.phone === 'string' ? input.phone.trim().replace(/[ ()-]/g, '') : '';
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254 || (phone && !/^\+[1-9]\d{7,14}$/.test(phone))) {
    throw new DomainError('invalid-argument', 'Enter a valid email and optional phone in international format.');
  }
  const ids = branchIds(input.branchIds);
  const profile = professional(input);
  const fingerprint = keyOf(email, phone, ids, profile);
  const uid = 'coach-' + keyOf(org, actor.uid, requestId);
  const root = `orgs/${org}`;
  const receipt = `${root}/commandReceipts/${keyOf('provisionCoach', actor.uid, requestId)}`;
  const userPath = `users/${uid}`;
  const memberPath = `${root}/members/${uid}`;
  const profilePath = `${root}/coachProfiles/${uid}`;
  const reserve = await store.transact(async tx => {
    await authorizeAdminReport(tx, actor, org);
    const prior = await tx.get(receipt);
    if (prior && prior.fingerprint !== fingerprint) throw new DomainError('already-exists', 'This request already belongs to another Coach setup.');
    if (prior?.status === 'completed') return 'completed';
    if (prior?.status === 'linked') return 'linked';
    for (const id of ids) if ((await tx.get(`${root}/branches/${id}`))?.status !== 'active') {
      throw new DomainError('failed-precondition', 'Select enabled branches.');
    }
    if (!prior) tx.create(receipt, {schemaVersion:1,command:'provisionCoach',actorId:actor.uid,coachId:uid,fingerprint,status:'reserved',createdAtMillis:Date.now()});
    return 'reserved';
  });
  if (reserve === 'completed') return {coachId:uid};
  async function existing(): Promise<UserRecord | undefined> {
    try { return await auth.getUser(uid); }
    catch (error) { if (authCode(error) !== 'auth/user-not-found') throw error; }
  }
  let identity = await existing();
  if (!identity) {
    if (reserve === 'linked') throw new DomainError('failed-precondition', 'The linked Auth account needs review.');
    try {
      identity = await auth.createUser({uid,email,displayName:String(profile.displayName),
        password:randomBytes(32).toString('base64url'),emailVerified:false,disabled:true});
    } catch (error) {
      if (['auth/email-already-exists','auth/uid-already-exists'].includes(String(authCode(error)))) {
        identity = await existing();
        if (!identity) throw new DomainError('already-exists', 'An account already uses this email address.');
      } else throw error;
    }
  }
  if (identity.email?.toLowerCase() !== email) throw new DomainError('failed-precondition', 'Coach account setup needs review.');
  await store.transact(async tx => {
    await authorizeAdminReport(tx, actor, org);
    const prior = await tx.get(receipt);
    if (prior?.fingerprint !== fingerprint) throw new DomainError('failed-precondition', 'Coach account setup needs review.');
    if (prior.status === 'linked' || prior.status === 'completed') return;
    if (!identity.disabled || identity.emailVerified ||
        await tx.get(userPath) || await tx.get(memberPath) || await tx.get(profilePath)) {
      throw new DomainError('already-exists', 'Coach identity already exists.');
    }
    for (const id of ids) if ((await tx.get(`${root}/branches/${id}`))?.status !== 'active') {
      throw new DomainError('failed-precondition', 'An assigned branch is no longer enabled.');
    }
    const now = Date.now();
    tx.create(userPath, {schemaVersion:1,organizationId:org,role:'coach',email,displayName:profile.displayName,
      primaryBranchId:ids[0],...(phone ? {phoneNumber:phone} : {}),createdAtMillis:now,updatedAtMillis:now});
    tx.create(memberPath, {schemaVersion:1,userId:uid,organizationId:org,role:'coach',status:'active',branchIds:ids,
      email,displayName:profile.displayName,createdAtMillis:now,updatedAtMillis:now});
    tx.create(profilePath, {...profile,schemaVersion:1,revision:1,createdAtMillis:now,updatedAtMillis:now});
    tx.set(receipt, {...prior,status:'linked',linkedAtMillis:now});
  });
  // A linked account can be completed after a transient Auth failure.
  // A completed request never changes an account that was later disabled.
  if (identity.disabled) await auth.updateUser(uid,{disabled:false});
  await store.transact(async tx => {
    const prior = await tx.get(receipt);
    if (prior?.status === 'linked') tx.set(receipt,{...prior,status:'completed',completedAtMillis:Date.now()});
  });
  return {coachId:uid};
}
