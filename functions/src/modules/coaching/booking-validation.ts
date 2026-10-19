import { requireActiveMembership, requireBranchAccess } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import type { DocumentData, TransactionPort } from '../../platform/firestore/store';
import { readAll } from '../../platform/firestore/store';
import { keyOf } from '../../platform/idempotency';
import type { CreateBookingHoldInput } from '../../platform/validation';
import { branchIds, bookingPolicy, dateGrid, localDate, MAX_TIME, plusDate, SLOT } from './coach-availability-contracts';
import type { CoachIdentityReader } from './coach-profile-service';
import { resolveRosterDay, storedRoster } from './coach-roster-contracts';

export const validBookingId = (value: unknown): value is string => typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(value);
export const validBookingTime = (value: unknown): value is number => Number.isSafeInteger(value) && Number(value) > 0 && Number(value) <= MAX_TIME;
// Keep persisted/returned metadata readable by the shared pure-Dart contract.
// Intl also accepts numeric UTC offsets on some runtimes; B3 requires IANA names.
export const validBookingZone = (value: unknown): value is string => typeof value === 'string' && value.length <= 100
  && /^[A-Za-z][A-Za-z0-9_+\-]*(\/[A-Za-z0-9_+\-]+)*$/.test(value);
export const validBookingPolicyVersion = (value: unknown): value is string => typeof value === 'string'
  && value.trim().length > 0 && value.length <= 128 && !/[\x00-\x1F\x7F]/.test(value);

export async function currentBookingMembership(tx: TransactionPort, org: string, uid: string) {
  const user = await tx.get(`users/${uid}`), data = await tx.get(`orgs/${org}/members/${uid}`);
  const member = requireActiveMembership(data);
  if (user?.organizationId !== org || data?.organizationId !== org || typeof data?.role !== 'string') throw new DomainError('permission-denied', 'Current organization access is required.');
  // Empty assignments remain valid for scoped reads of existing records. New
  // holds/options separately require an actual active shared branch.
  try { return { ...member, branchIds: member.branchIds.length === 0 ? [] : branchIds(member.branchIds) }; }
  catch { throw new DomainError('permission-denied', 'Current branch assignments are required.'); }
}
export async function requireBookingOrganization(tx: TransactionPort, org: string) {
  if ((await tx.get(`orgs/${org}`))?.status !== 'active') throw new DomainError('failed-precondition', 'Organization unavailable.');
}
export async function authorizeBookingCreate(tx: TransactionPort, org: string, actorId: string, input: CreateBookingHoldInput) {
  const actor = await currentBookingMembership(tx, org, actorId);
  requireBranchAccess(actor, input.branchId);
  if (!['member', 'staff', 'admin'].includes(actor.role) || (actor.role === 'member' && actorId !== input.memberId)) throw new DomainError('permission-denied', 'Cannot book for this member.');
  const member = await currentBookingMembership(tx, org, input.memberId);
  requireBranchAccess(member, input.branchId);
  if (member.role !== 'member') throw new DomainError('permission-denied', 'The booking recipient must be a member.');
  await requireBookingOrganization(tx, org);
  return member;
}
export async function bookingCoachScope(tx: TransactionPort, org: string, coachId: string, memberBranches: readonly string[]) {
  let coach;
  try { coach = await currentBookingMembership(tx, org, coachId); }
  catch { throw new DomainError('failed-precondition', 'Coach unavailable.'); }
  const publication = await tx.get(`orgs/${org}/coaches/${coachId}`);
  if (coach.role !== 'coach' || publication?.status !== 'published') throw new DomainError('failed-precondition', 'Coach unavailable.');
  let published: string[];
  try { published = branchIds(publication.branchIds); }
  catch { throw new DomainError('failed-precondition', 'Coach publication needs review.'); }
  const permitted: string[] = [];
  for (const id of coach.branchIds) if (memberBranches.includes(id) && published.includes(id)
    && (await tx.get(`orgs/${org}/branches/${id}`))?.status === 'active') permitted.push(id);
  if (!permitted.length) throw new DomainError('permission-denied', 'No permitted Coach branches are available.');
  return { assigned: coach.branchIds, permitted };
}
// Auth cannot participate in Firestore's transaction. Call once outside callbacks,
// then apply the captured outcome only after the final current-scope/receipt read.
export async function coachEligibilityFailure(reader: CoachIdentityReader, uid: string): Promise<DomainError | undefined> {
  try {
    const identity = await reader(uid);
    if (identity.exists !== true || identity.disabled !== false || identity.emailVerified !== true) return new DomainError('failed-precondition', 'Coach account unavailable.');
  } catch { return new DomainError('unavailable', 'Could not verify Coach account eligibility. Retry later.'); }
  return undefined;
}
export function currentBookingPolicy(data: DocumentData | undefined) {
  const policy = bookingPolicy(data);
  if (!validBookingPolicyVersion(policy.policyVersion) || !validBookingZone(policy.timeZone)) throw new DomainError('failed-precondition', 'Booking policy needs review.');
  return { ...policy, cap: Number(data!.maxActiveBookingsPerMemberPerDay), holdMillis: Number(data!.holdMinutes) * 60000 };
}
export interface BookingReservation { bookingId: string; status: 'pending_hold' | 'confirmed'; expiresAtMillis: number }
export function activeBookingReservations(data: DocumentData | undefined, memberId: string, date: string, zone: string, now: number): BookingReservation[] {
  if (!data) return [];
  if (data.schemaVersion !== 1 || data.memberId !== memberId || data.localDate !== date || data.timeZone !== zone
    || !Array.isArray(data.reservations) || data.reservations.length > 32) throw new DomainError('failed-precondition', 'Daily booking accounting needs review.');
  const reservations = data.reservations as BookingReservation[];
  if (reservations.some(r => !r || !validBookingId(r.bookingId) || !validBookingTime(r.expiresAtMillis) || !['confirmed', 'pending_hold'].includes(r.status))
    || new Set(reservations.map(r => r.bookingId)).size !== reservations.length) throw new DomainError('failed-precondition', 'Daily reservations need review.');
  return reservations.filter(r => r.status === 'confirmed' || r.expiresAtMillis > now);
}
export async function bookingDaySnapshot(tx: TransactionPort, org: string, coachId: string, memberId: string,
  date: string, policy: ReturnType<typeof currentBookingPolicy>, assigned: readonly string[], now: number) {
  const root = `orgs/${org}`, roster = storedRoster(await tx.get(`${root}/coachAvailability/${coachId}`), policy.timeZone, assigned);
  const today = localDate(now, policy.timeZone), through = plusDate(today, roster.weeklyAvailability?.advanceBookingWindowDays ?? 30);
  if (date < today || date > through) throw new DomainError('invalid-argument', `Choose today through ${through}.`);
  const grid = dateGrid(date, policy.timeZone);
  const day = resolveRosterDay(await tx.get(`${root}/coachAvailability/${coachId}/days/${date}`), date, policy.timeZone, assigned, roster);
  if (day.reviewRequired) throw new DomainError('failed-precondition', 'Legacy schedule requires authorized review.');
  const dayPath = `${root}/bookingDays/${keyOf(memberId, date)}`;
  const reservations = activeBookingReservations(await tx.get(dayPath), memberId, date, policy.timeZone, now);
  const blocked = new Set<number>();
  const locks = await readAll(tx, grid.slots.map(slot => `${root}/slotLocks/${keyOf(coachId, slot)}`));
  for (const [i, slot] of grid.slots.entries()) {
    const lock = locks[i];
    if (!lock) continue;
    if (lock.schemaVersion !== 1 || lock.coachId !== coachId || !validBookingId(lock.bookingId) || !validBookingId(lock.branchId)
      || (lock.status !== 'confirmed' && lock.status !== 'pending_hold')
      || (lock.status === 'pending_hold' && (!validBookingTime(lock.expiresAtMillis) || lock.expiresAtMillis > slot))) throw new DomainError('failed-precondition', 'Reservation lock needs authorized review.');
    if (lock.status === 'confirmed' || Number(lock.expiresAtMillis) > now) {
      if (day.windows.find(w => w.startAtMillis <= slot && w.endAtMillis >= slot + SLOT)?.branchId !== lock.branchId) throw new DomainError('failed-precondition', 'Stored schedule and reservation disagree.');
      blocked.add(slot);
    }
  }
  return { today, through, grid, windows: day.windows, reservations, dayPath, blocked, dailyCapacityMinutes: roster.weeklyAvailability ? roster.weeklyAvailability.dailyCapacityHours * 60 : undefined };
}
