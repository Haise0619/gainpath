import { credentialGateEnabled } from './coach-management-common';
import { requireActiveMembership, requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import type { DocumentData, DocumentStore, TransactionPort } from '../../platform/firestore/store';
import { keyOf } from '../../platform/idempotency';
import { InputValidationError, requiredIdentifier } from '../../platform/validation';

type Auth = { uid: string; token: Record<string, unknown> } | undefined;
export type CoachIdentityReader = (uid: string) => Promise<{ exists: boolean; disabled: boolean; emailVerified: boolean }>;
export interface CoachCommandResult { schemaVersion: 1; requestId: string; coachId: string; revision: number; outcome: 'saved' | 'published' | 'inactive' }
const editable = ['displayName', 'specialty', 'bio', 'specializationTags', 'yearsExperience', 'consultationFeeMinor', 'photoPath'] as const;
const publicKeys = [...editable, 'schemaVersion', 'revision', 'sourceRevision', 'status', 'branchIds', 'createdAtMillis', 'updatedAtMillis', 'publishedAtMillis', 'certificationVerified', 'approvedCertificationCount'];
function object(value: unknown): DocumentData {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new InputValidationError('A command object is required.');
  return value as DocumentData;
}
function keys(data: DocumentData, allowed: readonly string[]) {
  if (Object.keys(data).some(k => !allowed.includes(k))) throw new InputValidationError('Unsupported command field.');
}
function revision(value: unknown): number {
  if (!Number.isSafeInteger(value) || Number(value) < 0) throw new InputValidationError('A nonnegative expected revision is required.');
  return Number(value);
}
function branches(value: unknown): string[] {
  if (!Array.isArray(value) || !value.length || value.length > 8) throw new InputValidationError('Valid branch assignments are required.');
  const ids = value.map(v => requiredIdentifier(v, 'branchId')).sort();
  if (new Set(ids).size !== ids.length) throw new InputValidationError('Branch assignments must be unique.');
  return ids;
}
function professional(raw: DocumentData): DocumentData {
  const result: DocumentData = {};
  for (const [key, max, empty] of [['displayName', 80, false], ['specialty', 80, false], ['bio', 1000, true]] as const) {
    if (typeof raw[key] !== 'string') throw new InputValidationError('Professional text fields are required.');
    const text = (raw[key] as string).trim();
    if ((!empty && !text) || text.length > max) throw new InputValidationError('Professional text is outside the supported length.');
    result[key] = text;
  }
  if (!Array.isArray(raw.specializationTags) || !raw.specializationTags.length || raw.specializationTags.length > 8) throw new InputValidationError('Provide 1–8 specialties.');
  const tags = raw.specializationTags.map(t => {
    if (typeof t !== 'string' || !t.trim() || t.trim().length > 40) throw new InputValidationError('Invalid specialty tag.');
    return t.trim();
  });
  if (new Set(tags).size !== tags.length) throw new InputValidationError('Specialty tags must be unique.');
  if (raw.yearsExperience !== null && (!Number.isSafeInteger(raw.yearsExperience) || Number(raw.yearsExperience) < 0 || Number(raw.yearsExperience) > 60)) throw new InputValidationError('Experience must be null or an integer from 0 to 60.');
  result.specializationTags = tags;
  result.yearsExperience = raw.yearsExperience;
  if (Object.hasOwn(raw, 'consultationFeeMinor')) {
    if (raw.consultationFeeMinor !== null && (!Number.isSafeInteger(raw.consultationFeeMinor) || Number(raw.consultationFeeMinor) < 0 || Number(raw.consultationFeeMinor) > 1000000)) throw new InputValidationError('Fee must be null or integer MYR minor units from 0 to 1000000 (input guard).');
    result.consultationFeeMinor = raw.consultationFeeMinor;
  }
  if (Object.hasOwn(raw, 'photoPath')) {
    if (raw.photoPath !== null && (typeof raw.photoPath !== 'string' || !/^orgs\/[^/]+\/coachProfilePhotos\/[^/]+\/[a-f0-9]{32}$/.test(raw.photoPath))) throw new InputValidationError('Invalid photo path.');
    result.photoPath = raw.photoPath;
  }
  return result;
}
function stored(data: DocumentData | undefined, isPublic = false): DocumentData | undefined {
  if (!data) return undefined;
  if (data.schemaVersion !== 1 || !Number.isSafeInteger(data.revision) || Number(data.revision) < 1
    || !Number.isSafeInteger(data.createdAtMillis) || Number(data.createdAtMillis) < 0
    || !Number.isSafeInteger(data.updatedAtMillis) || Number(data.updatedAtMillis) < 0) throw new DomainError('failed-precondition', 'The profile needs an authorized schema review.');
  try {
    professional(data);
    if (isPublic && (Object.keys(data).some(k => !publicKeys.includes(k)) || !['published', 'inactive'].includes(String(data.status))
      || !Number.isSafeInteger(data.sourceRevision) || Number(data.sourceRevision) < 1 || !Number.isSafeInteger(data.publishedAtMillis) || Number(data.publishedAtMillis) < 0)) throw Error();
    if (isPublic) branches(data.branchIds);
  } catch { throw new DomainError('failed-precondition', 'The profile needs an authorized schema review.'); }
  return data;
}
function compare(data: DocumentData | undefined, expected: number) {
  if ((data ? Number(data.revision) : 0) !== expected) throw new DomainError('aborted', 'The profile changed. Discard and reload before saving.');
}
async function authority(tx: TransactionPort, org: string, uid: string, role: 'coach' | 'admin') {
  const user = await tx.get(`users/${uid}`), memberData = await tx.get(`orgs/${org}/members/${uid}`);
  const member = requireActiveMembership(memberData);
  if (user?.organizationId !== org || memberData?.organizationId !== org || member.role !== role) throw new DomainError('permission-denied', 'This operation is not authorized for the current account.');
  if ((await tx.get(`orgs/${org}`))?.status !== 'active') throw new DomainError('failed-precondition', 'Organization unavailable.');
  return member;
}
async function activeBranches(tx: TransactionPort, org: string, ids: readonly string[]) {
  for (const id of ids) if ((await tx.get(`orgs/${org}/branches/${id}`))?.status !== 'active') throw new DomainError('failed-precondition', 'Assigned branch unavailable.');
}
function context(auth: Auth, raw: unknown, allowed: string[]) {
  requireVerifiedEmail(auth);
  const uid = requiredIdentifier(auth!.uid, 'actorId'), data = object(raw);
  keys(data, allowed);
  if (data.schemaVersion !== 1) throw new InputValidationError('schemaVersion must be 1.');
  return { uid, data, org: requiredIdentifier(data.organizationId, 'organizationId'), requestId: requiredIdentifier(data.requestId, 'requestId') };
}
function replay(receipt: DocumentData | undefined, fingerprint: string): CoachCommandResult | undefined {
  if (!receipt) return undefined;
  if (receipt.fingerprint !== fingerprint) throw new DomainError('already-exists', 'The request ID already belongs to another operation.');
  if (receipt.schemaVersion !== 1 || !receipt.result) throw new DomainError('failed-precondition', 'Command receipt requires review.');
  return receipt.result as CoachCommandResult;
}
export async function saveCoachProfile(store: DocumentStore, auth: Auth, raw: unknown, clock = Date.now): Promise<CoachCommandResult> {
  const { uid, org, requestId, data } = context(auth, raw, ['schemaVersion', 'organizationId', 'requestId', 'expectedRevision', 'patch']);
  const expected = revision(data.expectedRevision), patch = object(data.patch);
  keys(patch, editable);
  if (!Object.keys(patch).length) throw new InputValidationError('Change at least one professional field.');
  if (patch.photoPath !== undefined && patch.photoPath !== null && (typeof patch.photoPath !== 'string' || (!patch.photoPath.startsWith(`orgs/${org}/coachProfilePhotos/${uid}/`) || !/^[a-f0-9]{32}$/.test(patch.photoPath.slice(`orgs/${org}/coachProfilePhotos/${uid}/`.length))))) throw new InputValidationError('Photo must belong to this Coach.');
  const canonicalPatch = Object.fromEntries(editable.filter(k => Object.hasOwn(patch, k)).map(k => [k, patch[k]]));
  const fingerprint = keyOf(org, expected, canonicalPatch), receiptPath = `orgs/${org}/commandReceipts/${keyOf('saveCoachProfile', uid, requestId)}`;
  return store.transact(async tx => {
    const membership = await authority(tx, org, uid, 'coach');
    const ids = branches(membership.branchIds); await activeBranches(tx, org, ids);
    const replayed = replay(await tx.get(receiptPath), fingerprint); if (replayed) return replayed;
    const path = `orgs/${org}/coachProfiles/${uid}`, current = stored(await tx.get(path));
    compare(current, expected);
    if (!current && editable.filter(k => k !== 'consultationFeeMinor' && k !== 'photoPath').some(k => !Object.hasOwn(patch, k))) throw new InputValidationError('A complete professional profile is required.');
    const validated = professional({ ...current, ...canonicalPatch });
    const changed = Object.fromEntries(Object.keys(canonicalPatch).map(k => [k, validated[k]]));
    if (current && Object.keys(changed).every(k => JSON.stringify(changed[k]) === JSON.stringify(current[k]))) throw new InputValidationError('Change at least one professional field.');
    const now = clock(), next = expected + 1;
    const result: CoachCommandResult = { schemaVersion: 1, requestId, coachId: uid, revision: next, outcome: 'saved' };
    tx.set(path, { ...current, ...changed, schemaVersion: 1, revision: next, createdAtMillis: current?.createdAtMillis ?? now, updatedAtMillis: now });
    tx.create(receiptPath, { schemaVersion: 1, command: 'saveCoachProfile', actorId: uid, fingerprint, createdAtMillis: now, result });
    return result;
  });
}
export async function setCoachDirectoryStatus(store: DocumentStore, auth: Auth, raw: unknown, identityReader: CoachIdentityReader, clock = Date.now): Promise<CoachCommandResult> {
  const { uid, org, requestId, data } = context(auth, raw, ['schemaVersion', 'organizationId', 'coachId', 'requestId', 'action', 'expectedPublicRevision', 'expectedProfileRevision', 'expectedCoachBranchIds']);
  const coachId = requiredIdentifier(data.coachId, 'coachId'), expectedPublic = revision(data.expectedPublicRevision);
  if (!['publish', 'deactivate'].includes(String(data.action))) throw new InputValidationError('Unsupported directory action.');
  const publishing = data.action === 'publish';
  if (!publishing && (Object.hasOwn(data, 'expectedProfileRevision') || Object.hasOwn(data, 'expectedCoachBranchIds'))) throw new InputValidationError('Deactivation does not accept a draft baseline.');
  const expectedSource = publishing ? revision(data.expectedProfileRevision) : null;
  const expectedBranches = publishing ? branches(data.expectedCoachBranchIds) : null;
  const fingerprint = keyOf(org, coachId, data.action, expectedPublic, expectedSource, expectedBranches);
  const receiptPath = `orgs/${org}/commandReceipts/${keyOf('setCoachDirectoryStatus', uid, requestId)}`;
  // No external Auth calls inside retryable Firestore transactions, and no
  // target-identity lookup before current Admin authorization or on receipt replay.
  const prior = await store.transact(async tx => { await authority(tx, org, uid, 'admin'); return replay(await tx.get(receiptPath), fingerprint); });
  if (prior) return prior;
  if (publishing) {
    const target = await identityReader(coachId);
    if (!target.exists || target.disabled || !target.emailVerified) throw new DomainError('failed-precondition', 'A verified, active Coach account is required for publication.');
  }
  return store.transact(async tx => {
    await authority(tx, org, uid, 'admin');
    const prior = replay(await tx.get(receiptPath), fingerprint); if (prior) return prior;
    const path = `orgs/${org}/coaches/${coachId}`, current = stored(await tx.get(path), true);
    if (!publishing && !current) throw new DomainError('not-found', 'Public Coach profile not found.');
    compare(current, expectedPublic);
    let fields: DocumentData | undefined, ids: string[] = [], credentialState: DocumentData | undefined;
    if (publishing) {
      const targetMember = await authority(tx, org, coachId, 'coach');
      ids = branches(targetMember.branchIds); await activeBranches(tx, org, ids);
      if (JSON.stringify(ids) !== JSON.stringify(expectedBranches)) throw new DomainError('aborted', 'Coach assignments changed. Reload the review.');
      const source = stored(await tx.get(`orgs/${org}/coachProfiles/${coachId}`));
      if (!source) throw new DomainError('not-found', 'Coach professional profile not found.');
      compare(source, expectedSource!); fields = professional(source);
      credentialState = await tx.get(`orgs/${org}/coachProfiles/${coachId}/certificationState/current`);
      if (credentialGateEnabled() && (credentialState?.certificationVerified !== true || !Number.isSafeInteger(credentialState.approvedCount) || Number(credentialState.approvedCount) < 1 || Number(credentialState.approvedCount) > 100)) throw new DomainError('failed-precondition', 'An approved certification is required for publication.');
    } else if (!current) throw new DomainError('not-found', 'Public Coach profile not found.');
    const now = clock(), noop = !publishing && current?.status === 'inactive', next = noop ? expectedPublic : expectedPublic + 1;
    const result: CoachCommandResult = { schemaVersion: 1, requestId, coachId, revision: next, outcome: publishing ? 'published' : 'inactive' };
    if (publishing) tx.set(path, { ...fields, certificationVerified: credentialState?.certificationVerified === true, approvedCertificationCount: credentialState?.approvedCount ?? 0, schemaVersion: 1, revision: next, sourceRevision: expectedSource, status: 'published', branchIds: ids, createdAtMillis: current?.createdAtMillis ?? now, updatedAtMillis: now, publishedAtMillis: now });
    else if (!noop) tx.set(path, { ...current, status: 'inactive', revision: next, updatedAtMillis: now });
    tx.create(receiptPath, { schemaVersion: 1, command: 'setCoachDirectoryStatus', actorId: uid, fingerprint, createdAtMillis: now, result });
    return result;
  });
}
