import { requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import { InputValidationError, requiredIdentifier } from '../../platform/validation';
import { readAll, type DocumentStore } from '../../platform/firestore/store';
import { currentBookingMembership, requireBookingOrganization } from './booking-validation';
import { allowed, object } from './coach-availability-contracts';
export interface RatingReader { aggregate(org: string, coachId: string): Promise<{ count: number; total: number }>; countCompleted?(org: string, coachId: string): Promise<number> }
export async function coachRatings(store: DocumentStore, auth: { uid: string; token: Record<string, unknown> } | undefined, raw: unknown, reader: RatingReader) {
  requireVerifiedEmail(auth); const d = object(raw); allowed(d, ['schemaVersion', 'organizationId', 'coachIds', 'includeAccountSummary']);
  const org = requiredIdentifier(d.organizationId, 'organizationId');
  if (d.schemaVersion !== 1 || !Array.isArray(d.coachIds) || d.coachIds.length > 20 || d.coachIds.length === 0) throw new InputValidationError('Choose 1–20 Coaches.');
  const ids = [...new Set(d.coachIds.map(id => requiredIdentifier(id, 'coachId')))];
  if (d.includeAccountSummary !== undefined && typeof d.includeAccountSummary !== 'boolean') throw new InputValidationError('Invalid summary option.');
  const summary = d.includeAccountSummary === true;
  const check = () => store.transact(async tx => {
    const actor = await currentBookingMembership(tx, org, auth!.uid); await requireBookingOrganization(tx, org);
    if (summary && (actor.role !== 'coach' || ids.length !== 1 || ids[0] !== auth!.uid)) throw new DomainError('permission-denied', 'Account summary is private to the Coach.');
    const labels = summary ? await readAll(tx, actor.branchIds.map(id => `orgs/${org}/branches/${id}`)) : [];
    const profiles = await readAll(tx, ids.map(id => `orgs/${org}/coaches/${id}`));
    if (profiles.some((p, i) => p?.status !== 'published' && !(actor.role === 'coach' && ids[i] === auth!.uid))) throw new DomainError('permission-denied', 'Coach ratings unavailable.');
    return { role: actor.role, branches: actor.branchIds, labels: labels.map((b,i) => ({id:actor.branchIds[i], name:typeof b?.name === 'string' && b.name.trim() ? b.name.trim() : null})) };
  });
  const before = await check();
  const records = await Promise.all(ids.map(async coachId => {
    const { count, total } = await reader.aggregate(org, coachId);
    if (!Number.isSafeInteger(count) || count < 0 || !Number.isSafeInteger(total) || total < count || total > count * 5) throw new DomainError('failed-precondition', 'Ratings need review.');
    return { coachId, reviewCount: count, averageRating: count ? total / count : null };
  }));
  let accountSummary: {completedSessions:number; branches:typeof before.labels} | undefined;
  if (summary) {
    if (!reader.countCompleted) throw new DomainError('unavailable', 'Account summary is unavailable.');
    const completedSessions = await reader.countCompleted(org, auth!.uid);
    if (!Number.isSafeInteger(completedSessions) || completedSessions < 0) throw new DomainError('failed-precondition', 'Session count needs review.');
    accountSummary = {completedSessions, branches:before.labels};
  }
  if (JSON.stringify(before) !== JSON.stringify(await check())) throw new DomainError('permission-denied', 'Account access changed.');
  return { schemaVersion: 1, records, ...(accountSummary ? {accountSummary} : {}) };
}
