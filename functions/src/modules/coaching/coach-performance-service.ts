import type { DocumentData, DocumentStore } from '../../platform/firestore/store';
import { requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import { InputValidationError, requiredIdentifier } from '../../platform/validation';
import { allowed, object, localDate, plusDate } from './coach-availability-contracts';
import { currentBookingMembership, requireBookingOrganization, currentBookingPolicy } from './booking-validation';
import { getBookingListService, type BookingQueryReader, type PersistedBookingRecord, type BookingCursor } from './booking-list-service';
import { storedBooking } from './booking-record';
import { validatedPremiumCoachVoucherSnapshot } from '../commerce/premium-coach-voucher';

// Explicit Sandbox agreement, never a claim that money has been disbursed.
export const COMMISSION_POLICY = { version: 'sandbox-coach-80-v1', coachBasisPoints: 8000, currency: 'MYR', environment: 'sandbox' } as const;
export function commissionFor(booking: DocumentData, payment: DocumentData | undefined, basisPoints = 8000) {
  if (booking.status !== 'completed' || !payment || payment.schemaVersion !== 1 || payment.environment !== 'sandbox'
    || payment.provider !== 'billplz' || payment.currency !== 'MYR' || payment.paymentStatus !== 'cleared'
    || payment.fulfilmentStatus !== 'confirmed' || payment.refundReviewRequired === true
    || (payment.refundStatus !== undefined && payment.refundStatus !== 'none')
    || !Number.isSafeInteger(payment.amountMinor) || Number(payment.amountMinor) <= 0 || Number(payment.amountMinor) > 100000000) return null;
  const voucher = payment.premiumVoucher === undefined ? undefined : validatedPremiumCoachVoucherSnapshot(payment);
  if (payment.premiumVoucher !== undefined && (!voucher || voucher.commissionPolicyVersion !== COMMISSION_POLICY.version || basisPoints !== COMMISSION_POLICY.coachBasisPoints)) return null;
  const grossMinor = voucher?.grossAmountMinor ?? Number(payment.amountMinor), coachMinor = Math.floor((grossMinor * basisPoints + 5000) / 10000);
  if (voucher) return { grossMinor, coachMinor, platformMinor: Number(payment.amountMinor) - coachMinor,
    collectedMinor: Number(payment.amountMinor), discountMinor: voucher.discountMinor };
  return { grossMinor, coachMinor, platformMinor: grossMinor - coachMinor };
}
export async function coachPerformance(store: DocumentStore, auth: { uid: string; token: Record<string, unknown> } | undefined, raw: unknown, reader: BookingQueryReader, clock = Date.now) {
  requireVerifiedEmail(auth);
  const d = object(raw); allowed(d, ['schemaVersion', 'organizationId']);
  if (d.schemaVersion !== 1) throw new InputValidationError('schemaVersion 1 is required.');
  const org = requiredIdentifier(d.organizationId, 'organizationId'), uid = requiredIdentifier(auth!.uid, 'actorId');
  const scope = async (tx: Parameters<Parameters<DocumentStore['transact']>[0]>[0]) => {
    const actor = await currentBookingMembership(tx, org, uid); await requireBookingOrganization(tx, org);
    if (actor.role !== 'coach') throw new DomainError('permission-denied', 'Coach performance is private to the assigned Coach.');
    const active: string[] = [];
    for (const branch of actor.branchIds) if ((await tx.get(`orgs/${org}/branches/${branch}`))?.status === 'active') active.push(branch);
    return { active, policy: currentBookingPolicy(await tx.get(`orgs/${org}/settings/booking`)) };
  };
  const before = await store.transact(scope), now = clock();
  const today = localDate(now, before.policy.timeZone), firstLocalDate = plusDate(today, -30);
  const bookings: PersistedBookingRecord[] = [];
  let cursor: BookingCursor | undefined;
  do {
    const page = await getBookingListService(store, auth, { schemaVersion: 1, organizationId: org, coachId: uid, firstLocalDate, dayCount: 31, includeParticipantNames: true, ...(cursor ? { cursor } : {}) }, reader, () => now);
    bookings.push(...page.records); cursor = page.nextCursor;
    if (bookings.length > 2000) throw new DomainError('resource-exhausted', 'Report exceeds 2000 sessions. Contact Admin for an extended report.');
  } while (cursor);
  // Each small transaction revalidates membership and the canonical booking/payment.
  // The immutable policy snapshot prevents future rate changes repricing old earnings.
  const sessions: DocumentData[] = [];
  for (let offset = 0; offset < bookings.length; offset += 6) {
    const batch = await Promise.all(bookings.slice(offset, offset + 6).map(async item => {
    const session = await store.transact(async tx => {
      if (JSON.stringify(await scope(tx)) !== JSON.stringify(before)) throw new DomainError('permission-denied', 'Coach access changed. Reload the report.');
      const root = `orgs/${org}/bookings/${item.bookingId}`;
      const booking = storedBooking(await tx.get(root), org, item.bookingId);
      if (booking.coachId !== uid || !before.active.includes(booking.branchId)) throw new DomainError('permission-denied', 'Booking access changed.');
      const payment = await tx.get(`orgs/${org}/transactions/${item.bookingId}`);
      const note = await tx.get(`${root}/consultation/current`);
      const review = await tx.get(`${root}/review/current`);
      const earningPath = `orgs/${org}/coachEarnings/${item.bookingId}`, existing = await tx.get(earningPath);
      if (existing && (existing.coachId !== uid || existing.bookingId !== item.bookingId || existing.organizationId !== org
        || existing.policyVersion !== COMMISSION_POLICY.version || existing.coachBasisPoints !== 8000)) throw new DomainError('failed-precondition', 'Earning snapshot needs Admin review.');
      const ownerMatches = payment?.organizationId === org && payment.bookingId === item.bookingId && payment.memberId === booking.memberId;
      const amounts = ownerMatches && note?.schemaVersion === 1 && note.bookingId === item.bookingId && note.organizationId === org && note.coachId === uid && note.memberId === booking.memberId ? commissionFor(booking as unknown as DocumentData, payment) : null;
      if (existing && amounts && existing.grossMinor !== amounts.grossMinor) throw new DomainError('failed-precondition', 'Payment amount changed after earnings recognition.');
      if (existing && amounts?.discountMinor !== undefined && ['coachMinor','platformMinor','collectedMinor','discountMinor'].some(k => existing[k] !== amounts[k as keyof typeof amounts])) throw new DomainError('failed-precondition', 'Voucher earnings require Admin review.');
      const stars = booking.status === 'completed' && review?.schemaVersion === 1 && review.coachId === uid && review.memberId === booking.memberId
        && Number.isInteger(review.stars) && Number(review.stars) >= 1 && Number(review.stars) <= 5 ? Number(review.stars) : null;
      if (amounts && !existing) tx.create(earningPath, { schemaVersion: 1, organizationId: org, bookingId: item.bookingId, coachId: uid,
        ...amounts, coachBasisPoints: 8000, policyVersion: COMMISSION_POLICY.version, recognizedAtMillis: now });
      return { bookingId: item.bookingId, memberName: item.memberDisplayName ?? 'Member', startAtMillis: booking.startAtMillis,
        durationMinutes: booking.durationMinutes, branchId: booking.branchId, status: booking.status,
        grossMinor: amounts?.grossMinor ?? 0, coachMinor: amounts?.coachMinor ?? 0, platformMinor: amounts?.platformMinor ?? 0,
        ...(amounts?.discountMinor !== undefined ? {collectedMinor:amounts.collectedMinor,discountMinor:amounts.discountMinor} : {}),
        reversedMinor: !amounts && existing ? Number(existing.coachMinor) : 0, eligible: amounts !== null, stars };
    });
      return session;
    }));
    sessions.push(...batch);
  }
  if (JSON.stringify(await store.transact(scope)) !== JSON.stringify(before)) throw new DomainError('permission-denied', 'Coach access changed. Reload the report.');
  const rated = sessions.filter(s => s.stars !== null);
  return { schemaVersion: 1, coachId: uid, firstLocalDate, throughLocalDate: today, policyVersion: COMMISSION_POLICY.version,
    coachBasisPoints: 8000, currency: 'MYR', environment: 'sandbox', payoutStatus: 'not_available', sessions,
    reviewCount: rated.length, averageRating: rated.length ? rated.reduce((sum, s) => sum + Number(s.stars), 0) / rated.length : null,
    grossMinor: sessions.reduce((sum, s) => sum + Number(s.grossMinor), 0), coachMinor: sessions.reduce((sum, s) => sum + Number(s.coachMinor), 0),
    platformMinor: sessions.reduce((sum, s) => sum + Number(s.platformMinor), 0), reversedMinor: sessions.reduce((sum, s) => sum + Number(s.reversedMinor), 0),
    ...(sessions.some(s=>s.discountMinor !== undefined) ? {
      collectedMinor:sessions.reduce((sum,s)=>sum+Number(s.collectedMinor??s.grossMinor),0),
      discountMinor:sessions.reduce((sum,s)=>sum+Number(s.discountMinor??0),0),
    } : {}) };
}
