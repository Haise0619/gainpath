import { requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import type { DocumentStore, TransactionPort } from '../../platform/firestore/store';
import { InputValidationError, requiredIdentifier } from '../../platform/validation';
import { allowed, dateEpoch, localDate, object, SLOT } from './coach-availability-contracts';
import { bookingCoachScope, bookingDaySnapshot, coachEligibilityFailure, currentBookingMembership, currentBookingPolicy, requireBookingOrganization } from './booking-validation';
import type { CoachIdentityReader } from './coach-profile-service';

export interface MemberBookingOption { branchId: string; startAtMillis: number; endAtMillis: number; startLabel: string; endLabel: string }
export interface MemberBookingOptionsResult {
  schemaVersion: 1; coachId: string; durationMinutes: 30 | 60; serverNowMillis: number;
  todayLocalDate: string; localDate: string; timeZone: string; throughLocalDate: string;
  permittedBranchIds: string[]; options: MemberBookingOption[]; unavailableReason?: 'no_open_times' | 'daily_limit';
}
export async function getMemberBookingOptionsService(store: DocumentStore,
  auth: { uid: string; token: Record<string, unknown> } | undefined, raw: unknown,
  readIdentity: CoachIdentityReader, clock = Date.now): Promise<MemberBookingOptionsResult> {
  requireVerifiedEmail(auth);
  const input = object(raw); allowed(input, ['schemaVersion', 'organizationId', 'coachId', 'localDate', 'durationMinutes']);
  if (input.schemaVersion !== 1 || (input.durationMinutes !== 30 && input.durationMinutes !== 60)) throw new InputValidationError('schemaVersion 1 and a 30/60 minute duration are required.');
  const durationMinutes = input.durationMinutes, org = requiredIdentifier(input.organizationId, 'organizationId'), coachId = requiredIdentifier(input.coachId, 'coachId'), uid = requiredIdentifier(auth!.uid, 'actorId');
  const requestedDate = input.localDate;
  if (requestedDate !== undefined) dateEpoch(requestedDate);
  const scope = async (tx: TransactionPort) => {
    const member = await currentBookingMembership(tx, org, uid);
    if (member.role !== 'member') throw new DomainError('permission-denied', 'Only Members can request booking options.');
    await requireBookingOrganization(tx, org);
    return bookingCoachScope(tx, org, coachId, member.branchIds);
  };
  await store.transact(scope); // Authorize before querying another account's Auth record.
  const eligibilityFailure = await coachEligibilityFailure(readIdentity, coachId);
  return store.transact(async tx => {
    const coach = await scope(tx);
    if (eligibilityFailure) throw eligibilityFailure;
    const policy = currentBookingPolicy(await tx.get(`orgs/${org}/settings/booking`)), now = clock();
    const date = requestedDate === undefined ? localDate(now, policy.timeZone) : requestedDate as string;
    const day = await bookingDaySnapshot(tx, org, coachId, uid, date, policy, coach.assigned, now);
    const options: MemberBookingOption[] = [], labels = new Map(day.grid.boundaries.map(b => [b.atMillis, b.label]));
    const dailyLimit = day.reservations.length >= policy.cap || (day.dailyCapacityMinutes !== undefined && day.blocked.size * 30 + durationMinutes > day.dailyCapacityMinutes);
    if (!dailyLimit) for (const start of day.grid.slots) {
      const end = start + durationMinutes * 60000;
      const window = day.windows.find(w => coach.permitted.includes(w.branchId) && w.startAtMillis <= start && w.endAtMillis >= end);
      if (start <= now || !window || day.blocked.has(start) || (durationMinutes === 60 && day.blocked.has(start + SLOT))) continue;
      options.push({ branchId: window.branchId, startAtMillis: start, endAtMillis: end, startLabel: labels.get(start)!, endLabel: labels.get(end)! });
    }
    return { schemaVersion: 1, coachId, durationMinutes, serverNowMillis: now, todayLocalDate: day.today,
      localDate: date, timeZone: policy.timeZone, throughLocalDate: day.through, permittedBranchIds: coach.permitted, options,
      ...(options.length ? {} : { unavailableReason: dailyLimit ? 'daily_limit' as const : 'no_open_times' as const }) };
  });
}
