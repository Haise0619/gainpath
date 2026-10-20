import { requireActiveMembership, requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import type { DocumentData, DocumentStore, TransactionPort } from '../../platform/firestore/store';
import { keyOf } from '../../platform/idempotency';
import { InputValidationError, requiredIdentifier } from '../../platform/validation';
export type CoachAuth = { uid: string; token: Record<string, unknown> } | undefined;
export function commandContext(auth: CoachAuth, raw: unknown, allowed: string[]) {
  requireVerifiedEmail(auth);
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) throw new InputValidationError('A command is required.');
  const data = raw as DocumentData;
  if (data.schemaVersion !== 1 || Object.keys(data).some(k => !allowed.includes(k))) throw new InputValidationError('Unsupported command schema.');
  return { uid: requiredIdentifier(auth!.uid, 'actorId'), org: requiredIdentifier(data.organizationId, 'organizationId'), data };
}
export async function coachAuthority(tx: TransactionPort, org: string, uid: string, roles: string[]) {
  const user = await tx.get(`users/${uid}`), membership = await tx.get(`orgs/${org}/members/${uid}`);
  const member = requireActiveMembership(membership);
  if (user?.organizationId !== org || membership?.organizationId !== org || !roles.includes(member.role)) throw new DomainError('permission-denied', 'Account is not authorized.');
  if ((await tx.get(`orgs/${org}`))?.status !== 'active') throw new DomainError('failed-precondition', 'Organization unavailable.');
}
export function expectedRevision(value: unknown) { if (!Number.isSafeInteger(value) || Number(value) < 0) throw new InputValidationError('Invalid expected revision.'); return Number(value); }
export function boundedText(value: unknown, max: number) { if (typeof value !== 'string' || !value.trim() || value.trim().length > max) throw new InputValidationError('Invalid text.'); return value.trim(); }
export function receipt(org: string, uid: string, command: string, request: unknown) { return `orgs/${org}/commandReceipts/${keyOf(command, uid, requiredIdentifier(request, 'requestId'))}`; }
export function replayReceipt(data: DocumentData | undefined, fingerprint: string): DocumentData | undefined { if (!data) return; if (data.fingerprint !== fingerprint) throw new DomainError('already-exists', 'Request ID already used.'); return data.result as DocumentData; }
export function saveReceipt(tx: TransactionPort, path: string, uid: string, fingerprint: string, result: DocumentData, now: number) { tx.create(path, { schemaVersion: 1, actorId: uid, fingerprint, result, createdAtMillis: now }); }
// Deliberately disabled until explicit approval to change existing directory eligibility.
export function credentialGateEnabled() { return process.env.COACH_CERTIFICATION_ELIGIBILITY_ENABLED === 'true'; }
