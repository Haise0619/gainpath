import { requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import { InputValidationError, requiredIdentifier } from '../../platform/validation';
import { readAll, type DocumentStore } from '../../platform/firestore/store';
import { currentBookingMembership, requireBookingOrganization } from './booking-validation';
import { allowed, object } from './coach-availability-contracts';
export interface RatingReader { aggregate(org: string, coachId: string): Promise<{ count: number; total: number }> }
export async function coachRatings(store: DocumentStore, auth: { uid: string; token: Record<string, unknown> } | undefined, raw: unknown, reader: RatingReader) {
  requireVerifiedEmail(auth); const d = object(raw); allowed(d, ['schemaVersion', 'organizationId', 'coachIds']);
  const org = requiredIdentifier(d.organizationId, 'organizationId');
  if (d.schemaVersion !== 1 || !Array.isArray(d.coachIds) || d.coachIds.length > 20 || d.coachIds.length === 0) throw new InputValidationError('Choose 1–20 Coaches.');
  const ids = [...new Set(d.coachIds.map(id => requiredIdentifier(id, 'coachId')))];
  const check = () => store.transact(async tx => {
    const actor = await currentBookingMembership(tx, org, auth!.uid); await requireBookingOrganization(tx, org);
    const profiles = await readAll(tx, ids.map(id => `orgs/${org}/coaches/${id}`));
    if (profiles.some((p, i) => p?.status !== 'published' && !(actor.role === 'coach' && ids[i] === auth!.uid))) throw new DomainError('permission-denied', 'Coach ratings unavailable.');
    return { role: actor.role, branches: actor.branchIds };
  });
  const before = await check();
  const records = await Promise.all(ids.map(async coachId => {
    const { count, total } = await reader.aggregate(org, coachId);
    if (!Number.isSafeInteger(count) || count < 0 || !Number.isSafeInteger(total) || total < count || total > count * 5) throw new DomainError('failed-precondition', 'Ratings need review.');
    return { coachId, reviewCount: count, averageRating: count ? total / count : null };
  }));
  if (JSON.stringify(before) !== JSON.stringify(await check())) throw new DomainError('permission-denied', 'Account access changed.');
  return { schemaVersion: 1, records };
}
