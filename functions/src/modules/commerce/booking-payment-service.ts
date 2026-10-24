import type { DocumentData, DocumentStore, TransactionPort } from '../../platform/firestore/store';
import { requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import { InputValidationError, requiredIdentifier } from '../../platform/validation';
import { keyOf } from '../../platform/idempotency';
import { allowed, integer, object, SLOT } from '../coaching/coach-availability-contracts';
import { bookingCoachScope, bookingDaySnapshot, coachEligibilityFailure, currentBookingMembership, currentBookingPolicy, requireBookingOrganization } from '../coaching/booking-validation';
import { storedBooking } from '../coaching/booking-record';
import type { CoachIdentityReader } from '../coaching/coach-profile-service';
import type { BillplzGateway, SandboxBill } from './billplz-sandbox';
import { bookingVoucherProjection, premiumCoachVoucherOffer, preparePremiumCoachVoucherConsumption, preparePremiumCoachVoucherRelease, requireAvailablePremiumCoachVoucher, reservePremiumCoachVoucher, type PremiumCoachVoucherOffer } from './premium-coach-voucher';

type Auth = { uid: string; token: Record<string, unknown> } | undefined;
const txPath = (org: string, id: string) => `orgs/${org}/transactions/${id}`;
const review = () => new DomainError('failed-precondition', 'Payment data requires authorized review.');
function paymentInput(auth: Auth, raw: unknown, allowVoucher = false) {
  requireVerifiedEmail(auth);
  const d = object(raw); allowed(d, ['schemaVersion', 'organizationId', 'bookingId', ...(allowVoucher ? ['usePremiumVoucher'] : [])]);
  if (d.schemaVersion !== 1) throw new InputValidationError('schemaVersion 1 is required.');
  if (d.usePremiumVoucher !== undefined && typeof d.usePremiumVoucher !== 'boolean') throw new InputValidationError('Choose whether to apply the voucher.');
  return { org: requiredIdentifier(d.organizationId, 'organizationId'), id: requiredIdentifier(d.bookingId, 'bookingId'), uid: requiredIdentifier(auth!.uid, 'actorId'), usePremiumVoucher: d.usePremiumVoucher === true };
}
async function authorizedBooking(tx: TransactionPort, org: string, id: string, uid: string, write = false) {
  const actor = await currentBookingMembership(tx, org, uid); await requireBookingOrganization(tx, org);
  const b = storedBooking(await tx.get(`orgs/${org}/bookings/${id}`), org, id);
  if (write ? actor.role !== 'member' || b.memberId !== uid
    : !((actor.role === 'member' && b.memberId === uid) || actor.role === 'admin' || (actor.role === 'coach' && b.coachId === uid && actor.branchIds.includes(b.branchId) && (await tx.get(`orgs/${org}/branches/${b.branchId}`))?.status === 'active'))) {
    throw new DomainError('permission-denied', 'This account cannot access the booking payment.');
  }
  return b;
}
async function professionalQuote(tx: TransactionPort, org: string, coachId: string, branchId: string, memberBranches: readonly string[]) {
  const coach = await bookingCoachScope(tx, org, coachId, memberBranches);
  if (!coach.permitted.includes(branchId)) throw new DomainError('permission-denied', 'Branch unavailable.');
  const p = await tx.get(`orgs/${org}/coaches/${coachId}`);
  await requireCredentials(tx,org,coachId,p);
  if (!p || typeof p.displayName !== 'string' || !p.displayName.trim() || p.displayName.length > 80 || !Number.isSafeInteger(p.consultationFeeMinor) || Number(p.consultationFeeMinor) < 1 || Number(p.consultationFeeMinor) > 100000000) throw new DomainError('failed-precondition', 'The Coach needs a valid published consultation fee.');
  const branch = await tx.get(`orgs/${org}/branches/${branchId}`);
  return { amountMinor: Number(p.consultationFeeMinor), currency: 'MYR' as const, coachName: p.displayName.trim(), branchName: typeof branch?.displayName === 'string' && branch.displayName.trim() ? branch.displayName.trim().slice(0,120) : '-' };
}
async function requireCredentials(tx: TransactionPort, org: string, coachId: string, publication: DocumentData | undefined) {
  const certification = await tx.get(`orgs/${org}/coachProfiles/${coachId}/certificationState/current`);
  if (publication?.certificationVerified !== true || certification?.certificationVerified !== true || !Number.isSafeInteger(certification.approvedCount) || Number(certification.approvedCount) < 1 || Number(certification.approvedCount)>100) throw new DomainError('failed-precondition', 'Approved Coach credentials are required.');
}
export interface BookingPaymentQuoteResult {
  schemaVersion: number; amountMinor: number; currency: 'MYR'; coachName: string; branchName: string; durationMinutes: number;
  grossAmountMinor?: number; discountMinor?: number; premiumVoucher?: PremiumCoachVoucherOffer;
}
export async function getBookingPaymentQuote(store: DocumentStore, auth: Auth, raw: unknown, clock = Date.now, readIdentity?: CoachIdentityReader): Promise<BookingPaymentQuoteResult> {
  requireVerifiedEmail(auth);
  const d = object(raw); allowed(d, ['schemaVersion', 'organizationId', 'coachId', 'branchId', 'durationMinutes', 'includePremiumVoucher', 'usePremiumVoucher']);
  if (d.schemaVersion !== 1 || ![30,60].includes(Number(d.durationMinutes)) || typeof d.durationMinutes !== 'number') throw new InputValidationError('Choose a supported duration.');
  if (['includePremiumVoucher', 'usePremiumVoucher'].some(k => d[k] !== undefined && typeof d[k] !== 'boolean')) throw new InputValidationError('Invalid voucher selection.');
  const org = requiredIdentifier(d.organizationId, 'organizationId'), coachId = requiredIdentifier(d.coachId, 'coachId'), branchId = requiredIdentifier(d.branchId, 'branchId');
  if (d.includePremiumVoucher === true || d.usePremiumVoucher === true) {
    if (!readIdentity) throw new DomainError('unavailable', 'Current account verification is unavailable.');
    const failure = await coachEligibilityFailure(readIdentity, auth!.uid); if (failure) throw failure;
  }
  return store.transact(async tx => {
    const member = await currentBookingMembership(tx, org, auth!.uid); await requireBookingOrganization(tx, org);
    if (member.role !== 'member') throw new DomainError('permission-denied', 'Only Members may start checkout.');
    const quote = { schemaVersion: 1, ...await professionalQuote(tx, org, coachId, branchId, member.branchIds), durationMinutes: d.durationMinutes as number };
    if (d.includePremiumVoucher !== true && d.usePremiumVoucher !== true) return quote;
    const voucher = await premiumCoachVoucherOffer(tx, auth, org, { ...quote, coachId, branchId }, clock());
    if (d.usePremiumVoucher === true) {
      const snapshot = requireAvailablePremiumCoachVoucher(voucher);
      return { ...quote, amountMinor: snapshot.amountMinor, grossAmountMinor: quote.amountMinor, discountMinor: snapshot.discountMinor, premiumVoucher: voucher.offer };
    }
    return { ...quote, premiumVoucher: voucher.offer };
  });
}
function payment(d: DocumentData | undefined, org: string, id: string): DocumentData {
  if (!d || d.schemaVersion !== 1 || d.environment !== 'sandbox' || d.provider !== 'billplz' || d.organizationId !== org || d.bookingId !== id || d.currency !== 'MYR'
    || !Number.isSafeInteger(d.amountMinor) || Number(d.amountMinor) < 1 || !['creating','awaiting_payment','confirmed','reconciliation_required'].includes(String(d.fulfilmentStatus))
    || !['pending','cleared'].includes(String(d.paymentStatus))) throw review();
  return d;
}
function view(d: DocumentData) {
  return { schemaVersion: 1, bookingId: String(d.bookingId), status: String(d.fulfilmentStatus), amountMinor: Number(d.amountMinor), currency: 'MYR', coachName: String(d.coachName), branchName: String(d.branchName), startLabel: String(d.startLabel), endLabel: String(d.endLabel), localDate: String(d.localDate), durationMinutes: Number(d.durationMinutes), holdExpiresAtMillis: Number(d.holdExpiresAtMillis),
    ...(d.fulfilmentStatus === 'awaiting_payment' && typeof d.checkoutUrl === 'string' ? { checkoutUrl: d.checkoutUrl } : {}),
    paymentStatus:String(d.paymentStatus), ...bookingVoucherProjection(d),
    ...(typeof d.refundStatus === 'string' ? { refundStatus: d.refundStatus } : {}),
    ...(typeof d.resolutionReason === 'string' ? { resolutionReason: d.resolutionReason } : {}) };
}
function audit(tx: TransactionPort, org: string, id: string, event: string, now: number, fields: DocumentData = {}) {
  tx.create(`${txPath(org,id)}/events/${event}`, { schemaVersion: 1, environment: 'sandbox', event, atMillis: now, ...fields });
}
function closeUnpaidCheckout(tx: TransactionPort, org: string, id: string, d: DocumentData, bookingStatus: string, deadline: number, now: number): DocumentData {
  if (d.fulfilmentStatus !== 'awaiting_payment' || d.paymentStatus === 'cleared' || (bookingStatus === 'pending_hold' && now < deadline)) return d;
  const next={...d,fulfilmentStatus:'reconciliation_required',resolutionReason:'hold_closed_unpaid',updatedAtMillis:now};
  tx.set(txPath(org,id),next); audit(tx,org,id,'checkout_closed',now); return next;
}
export async function createBookingPayment(store: DocumentStore, auth: Auth, raw: unknown, gateway: BillplzGateway, readIdentity: CoachIdentityReader, clock = Date.now) {
  const {org,id,uid,usePremiumVoucher} = paymentInput(auth,raw,true);
  if (usePremiumVoucher) { const failure = await coachEligibilityFailure(readIdentity,uid); if (failure) throw failure; }
  const captured = await store.transact(async tx => {
    const b = await authorizedBooking(tx,org,id,uid,true);
    const prior = await tx.get(txPath(org,id));
    if (prior) return { existing: view(closeUnpaidCheckout(tx,org,id,payment(prior,org,id),b.status,b.holdExpiresAtMillis,clock())), b };
    return { b };
  });
  if (captured.existing) return captured.existing;
  const eligibility = await coachEligibilityFailure(readIdentity,captured.b.coachId);
  if (eligibility) throw eligibility;
  const reservation = await store.transact(async tx => {
    const b = await authorizedBooking(tx,org,id,uid,true), prior = await tx.get(txPath(org,id));
    if (prior) return { existing: view(closeUnpaidCheckout(tx,org,id,payment(prior,org,id),b.status,b.holdExpiresAtMillis,clock())) };
    const now = integer(clock(),1);
    if (b.status !== 'pending_hold' || now >= b.holdExpiresAtMillis) throw new DomainError('failed-precondition', 'This pending hold has closed. Choose a new available time.');
    const member = await currentBookingMembership(tx,org,uid);
    const quote = await professionalQuote(tx,org,b.coachId,b.branchId,member.branchIds);
    const user = await tx.get(`users/${uid}`);
    const voucher = usePremiumVoucher ? await premiumCoachVoucherOffer(tx,auth,org,{...quote,coachId:b.coachId,branchId:b.branchId,durationMinutes:b.durationMinutes},now) : undefined;
    const snapshot = voucher ? requireAvailablePremiumCoachVoucher(voucher) : undefined;
    if (typeof user?.email !== 'string' || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(user.email) || user.email.length > 254) throw new DomainError('failed-precondition','A valid account email is required.');
    const format = new Intl.DateTimeFormat('en-GB',{timeZone:b.timeZone,hour:'2-digit',minute:'2-digit',hourCycle:'h23',timeZoneName:'shortOffset'});
    const d = { schemaVersion: 1, environment: 'sandbox', provider: 'billplz', type: 'CoachingBooking', organizationId: org, bookingId: id, memberId: uid, coachId: b.coachId, branchId: b.branchId,
      ...quote, ...(snapshot ? {amountMinor:snapshot.amountMinor,grossAmountMinor:quote.amountMinor,discountMinor:snapshot.discountMinor,premiumVoucher:snapshot} : {}), durationMinutes:b.durationMinutes, localDate:b.localDate, startLabel:format.format(b.startAtMillis), endLabel:format.format(b.endAtMillis), holdExpiresAtMillis:b.holdExpiresAtMillis,
      paymentStatus:'pending', fulfilmentStatus:'creating', createdAtMillis:now, updatedAtMillis:now };
    if (snapshot) reservePremiumCoachVoucher(tx,org,id,snapshot,voucher!.prior,now);
    tx.create(txPath(org,id),d); audit(tx,org,id,'checkout_created',now,{amountMinor:d.amountMinor,currency:'MYR',...(snapshot ? {grossAmountMinor:quote.amountMinor,discountMinor:snapshot.discountMinor,voucherId:snapshot.voucherId} : {})});
    return { data:d, email:user.email, name:typeof user.displayName === 'string' ? user.displayName.slice(0,120) : 'GainPath Member' };
  });
  if (reservation.existing) return reservation.existing;
  let bill: SandboxBill;
  try { bill = await gateway.create({amountMinor:reservation.data!.amountMinor,name:reservation.name!,email:reservation.email!,reference:id,organizationId:org,description:`GainPath coaching session with ${reservation.data!.coachName}`}); }
  catch {
    return store.transact(async tx => {
      const d = payment(await tx.get(txPath(org,id)),org,id);
      if (d.fulfilmentStatus !== 'creating') return view(d);
      const next = {...d,fulfilmentStatus:'reconciliation_required',resolutionReason:'bill_creation_uncertain',updatedAtMillis:clock()};
      tx.set(txPath(org,id),next); audit(tx,org,id,'bill_creation_uncertain',clock()); return view(next);
    });
  }
  return store.transact(async tx => {
    const d = payment(await tx.get(txPath(org,id)),org,id);
    if (d.fulfilmentStatus !== 'creating') return view(d);
    const b=storedBooking(await tx.get(`orgs/${org}/bookings/${id}`),org,id);
    if (bill.amount !== d.amountMinor || bill.reference_1 !== id || bill.reference_2 !== org || bill.paid || bill.state !== 'due') throw review();
    const closed=b.status!=='pending_hold'||clock()>=b.holdExpiresAtMillis;
    const next = {...d,billId:bill.id,collectionId:bill.collection_id,checkoutUrl:bill.url,fulfilmentStatus:closed?'reconciliation_required':'awaiting_payment',...(closed?{resolutionReason:'hold_closed_unpaid'}:{}),updatedAtMillis:clock()};
    tx.set(txPath(org,id),next); audit(tx,org,id,'bill_created',clock(),{billId:bill.id}); return view(next);
  });
}

export async function settleBookingPayment(store: DocumentStore, org: string, id: string, bill: SandboxBill, readIdentity: CoachIdentityReader, clock = Date.now) {
  const initial = await store.transact(async tx => payment(await tx.get(txPath(org,id)),org,id));
  if (initial.billId !== bill.id || initial.collectionId !== bill.collection_id || initial.amountMinor !== bill.amount || bill.reference_1 !== id || bill.reference_2 !== org) throw review();
  if (initial.premiumVoucher !== undefined && initial.paymentStatus !== 'cleared' && bill.paid === false && bill.state === 'deleted' && bill.paid_amount === 0) {
    return store.transact(async tx => {
      const d = payment(await tx.get(txPath(org,id)),org,id);
      if (d.paymentStatus === 'cleared' || d.voucherReleasedAtMillis !== undefined) return view(d);
      if (d.billId !== bill.id || d.collectionId !== bill.collection_id || d.amountMinor !== bill.amount) throw review();
      const now = integer(clock(),1), release = await preparePremiumCoachVoucherRelease(tx,org,id,d,now);
      const next = {...d,fulfilmentStatus:'reconciliation_required',resolutionReason:'provider_verified_deleted',voucherReleasedAtMillis:now,updatedAtMillis:now};
      release(); tx.set(txPath(org,id),next); audit(tx,org,id,'voucher_released',now,{billId:bill.id}); return view(next);
    });
  }
  if (bill.paid !== true || bill.state !== 'paid') return view(initial); // A late failed attempt never downgrades payment.
  if (bill.paid_amount !== initial.amountMinor) throw review();
  if (initial.paymentStatus === 'cleared') return view(initial);
  const failures = await Promise.all([coachEligibilityFailure(readIdentity,String(initial.coachId)),coachEligibilityFailure(readIdentity,String(initial.memberId))]);
  if (failures.some(f => f?.code === 'unavailable')) throw new DomainError('unavailable','Account verification is temporarily unavailable.');
  return store.transact(async tx => {
    const d = payment(await tx.get(txPath(org,id)),org,id);
    if (d.paymentStatus === 'cleared') return view(d);
    if (d.billId !== bill.id || d.amountMinor !== bill.amount || d.collectionId !== bill.collection_id) throw review();
    const b = storedBooking(await tx.get(`orgs/${org}/bookings/${id}`),org,id), now = integer(clock(),1);
    let reason: string | undefined;
    let day: Awaited<ReturnType<typeof bookingDaySnapshot>> | undefined;
    let job: DocumentData | undefined;
    const locks: {path:string;data:DocumentData}[] = [];
    if (b.status !== 'pending_hold' || now < b.createdAtMillis || now >= b.holdExpiresAtMillis || now >= b.startAtMillis) reason = 'hold_closed';
    else if (failures.some(Boolean)) reason = 'account_ineligible';
    if (!reason) try {
      const member = await currentBookingMembership(tx,org,b.memberId); await requireBookingOrganization(tx,org);
      if (member.role !== 'member' || !member.branchIds.includes(b.branchId)) throw review();
      const coach = await bookingCoachScope(tx,org,b.coachId,member.branchIds);
      if (!coach.permitted.includes(b.branchId)) throw review();
      await requireCredentials(tx,org,b.coachId,await tx.get(`orgs/${org}/coaches/${b.coachId}`));
      const policy = currentBookingPolicy(await tx.get(`orgs/${org}/settings/booking`));
      if (policy.timeZone !== b.timeZone || policy.policyVersion !== b.policyVersion) throw review();
      day = await bookingDaySnapshot(tx,org,b.coachId,b.memberId,b.localDate,policy,coach.assigned,now);
      if (!day.windows.some(w => w.branchId === b.branchId && w.startAtMillis <= b.startAtMillis && w.endAtMillis >= b.endAtMillis)
        || day.reservations.length > policy.cap || (day.dailyCapacityMinutes !== undefined && day.blocked.size * 30 > day.dailyCapacityMinutes)) throw review();
      const own = day.reservations.find(r => r.bookingId === id);
      if (!own || own.status !== 'pending_hold' || own.expiresAtMillis !== b.holdExpiresAtMillis) throw review();
      for (let slot=b.startAtMillis;slot<b.endAtMillis;slot+=SLOT) {
        const path=`orgs/${org}/slotLocks/${keyOf(b.coachId,slot)}`, lock=await tx.get(path);
        if (!lock || lock.schemaVersion !== 1 || lock.bookingId !== id || lock.coachId !== b.coachId || lock.branchId !== b.branchId || lock.status !== 'pending_hold' || lock.expiresAtMillis !== b.holdExpiresAtMillis) throw review();
        locks.push({path,data:lock});
      }
      job = await tx.get(`orgs/${org}/jobs/${keyOf('expireBookingHold',id)}`);
      if (!job || job.schemaVersion !== 1 || job.type !== 'expireBookingHold' || job.bookingId !== id || job.status !== 'pending' || job.dueAtMillis !== b.holdExpiresAtMillis || !Number.isSafeInteger(job.attempts) || Number(job.attempts)<0) throw review();
    } catch (error) {
      if (error instanceof DomainError && ['failed-precondition','permission-denied','not-found','invalid-argument'].includes(error.code)) reason='booking_ineligible';
      else throw error;
    }
    const originalDay = !reason ? await tx.get(day!.dayPath) : undefined;
    const consumeVoucher = await preparePremiumCoachVoucherConsumption(tx,org,id,d,now);
    const next = {...d,paymentStatus:'cleared',fulfilmentStatus:reason ? 'reconciliation_required' : 'confirmed',paymentVerifiedAtMillis:now,updatedAtMillis:now,...(reason ? {resolutionReason:reason} : {})};
    if (!reason) {
      tx.set(`orgs/${org}/bookings/${id}`,{...b,status:'confirmed'});
      for (const lock of locks) tx.set(lock.path,{...lock.data,status:'confirmed'});
      tx.set(day!.dayPath,{...originalDay,reservations:(originalDay!.reservations as DocumentData[]).map(r => r.bookingId === id ? {...r,status:'confirmed'} : r)});
      tx.set(`orgs/${org}/jobs/${keyOf('expireBookingHold',id)}`,{...job,status:'completed',outcome:'confirmed',processedAtMillis:now,attempts:Number(job!.attempts)+1});
    }
    consumeVoucher(); tx.set(txPath(org,id),next);
    audit(tx,org,id,'payment_cleared',now,{billId:bill.id,amountMinor:d.amountMinor,currency:'MYR'});
    audit(tx,org,id,reason ? 'resolution_required' : 'booking_confirmed',now,reason ? {reason} : {});
    return view(next);
  });
}

export async function readBookingPayment(store: DocumentStore, auth: Auth, raw: unknown, gateway: BillplzGateway, readIdentity: CoachIdentityReader, clock = Date.now) {
  const {org,id,uid}=paymentInput(auth,raw);
  const captured = await store.transact(async tx => {
    const b=await authorizedBooking(tx,org,id,uid);
    let d=payment(await tx.get(txPath(org,id)),org,id);
    const now=clock();
    d=closeUnpaidCheckout(tx,org,id,d,b.status,b.holdExpiresAtMillis,now);
    if (d.fulfilmentStatus === 'creating' && now-Number(d.createdAtMillis)>120000) {
      const next:DocumentData={...d,fulfilmentStatus:'reconciliation_required',resolutionReason:'bill_creation_uncertain',updatedAtMillis:now};
      tx.set(txPath(org,id),next); audit(tx,org,id,'bill_creation_uncertain',now); return {d:next,check:false};
    }
    const check=d.paymentStatus!=='cleared' && typeof d.billId==='string' && now-Number(d.lastProviderCheckAtMillis??0)>=10000;
    if (check) tx.set(txPath(org,id),{...d,lastProviderCheckAtMillis:now});
    return {d,check};
  });
  if (captured.check) await settleBookingPayment(store,org,id,await gateway.get(String(captured.d.billId)),readIdentity,clock);
  return store.transact(async tx => {
    const b=await authorizedBooking(tx,org,id,uid),d=payment(await tx.get(txPath(org,id)),org,id);
    return view(closeUnpaidCheckout(tx,org,id,d,b.status,b.holdExpiresAtMillis,clock()));
  });
}
