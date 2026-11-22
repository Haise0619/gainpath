import { DomainError } from '../../platform/errors';
import type { DocumentData } from '../../platform/firestore/store';

export const MALAYSIA_TIME_ZONE = 'Asia/Kuala_Lumpur';
export const MALAYSIA_UTC_OFFSET = 8 * 3_600_000;

export function branchReportDate(instant: number) {
  return new Date(instant + MALAYSIA_UTC_OFFSET).toISOString().slice(0, 10);
}

export function clockNumber(value: unknown): value is number {
  return typeof value === 'number' && Number.isSafeInteger(value) && value >= 0;
}

export function inBranchReportRange(value: unknown, from: number, to: number): value is number {
  return clockNumber(value) && value >= from && value < to;
}

export function successfulBranchVisit(visit: DocumentData, branchId: string, from: number, to: number) {
  const { memberId, checkedInAtMillis } = visit;
  if (visit.source !== 'branch_qr' || visit.branchId !== branchId
    || typeof memberId !== 'string' || !memberId || !inBranchReportRange(checkedInAtMillis, from, to)) return;
  return { memberId, checkedInAtMillis };
}

export function confirmedCoachingReceipt(
  payment: DocumentData & { id: string }, org: string, from: number, to: number, now: number, bills: Set<string>,
) {
  if (payment.type !== 'CoachingBooking' || payment.paymentStatus !== 'cleared'
    || payment.fulfilmentStatus !== 'confirmed' || ![undefined, 'none', 'rejected'].includes(payment.refundStatus as string | undefined)) return;
  if (!clockNumber(payment.paymentVerifiedAtMillis)) {
    throw new DomainError('failed-precondition', 'Coaching receipt dates require review.');
  }
  if (!inBranchReportRange(payment.paymentVerifiedAtMillis, from, to) || payment.paymentVerifiedAtMillis > now) return;
  const { amountMinor, paymentVerifiedAtMillis, billId } = payment;
  if (payment.organizationId !== org || payment.bookingId !== payment.id || payment.schemaVersion !== 1
    || payment.environment !== 'sandbox' || !['xendit', 'billplz'].includes(String(payment.provider))
    || payment.currency !== 'MYR' || !clockNumber(amountMinor) || amountMinor === 0 || typeof billId !== 'string' || !billId) {
    throw new DomainError('failed-precondition', 'Coaching receipts require review.');
  }
  if (bills.has(billId)) throw new DomainError('failed-precondition', 'Coaching receipts contain duplicate provider bills.');
  bills.add(billId);
  return { amountMinor, paymentVerifiedAtMillis };
}
