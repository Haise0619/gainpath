import { DomainError } from '../../platform/errors';
import { InputValidationError, requiredIdentifier } from '../../platform/validation';
import type { DocumentData, TransactionPort } from '../../platform/firestore/store';
import { readAll } from '../../platform/firestore/store';
import { keyOf } from '../../platform/idempotency';
import { allowed, dateEpoch, dateGrid, integer, MAX_TIME, normalizeWindows, object, SLOT, storedDay, type AvailabilityWindow } from './coach-availability-contracts';

export interface WeeklyDay { dayOfWeek: number; isActive: boolean; startMinute: number; endMinute: number; branchId: string }
export interface WeeklyAvailability { dailyCapacityHours: number; advanceBookingWindowDays: number; schedule: WeeklyDay[] }
export interface RosterException { id: string; type: 'breakTime' | 'offDay' | 'leave'; reason: string; startAtMillis: number; endAtMillis: number }
export interface CoachRoster { revision: number; weeklyAvailability: WeeklyAvailability | null; exceptions: RosterException[] }
export const rosterReview = () => new DomainError('failed-precondition', 'Coach roster requires authorized review.');
export function weeklyAvailability(raw: unknown, assigned: readonly string[]): WeeklyAvailability | null {
  if (raw === null) return null;
  const w = object(raw); allowed(w, ['dailyCapacityHours', 'advanceBookingWindowDays', 'schedule']);
  const dailyCapacityHours = integer(w.dailyCapacityHours, 1, 24), advanceBookingWindowDays = integer(w.advanceBookingWindowDays, 1, 30);
  if (!Array.isArray(w.schedule) || w.schedule.length !== 7) throw new InputValidationError('Exactly seven weekly days are required.');
  const schedule = w.schedule.map(value => {
    const d = object(value); allowed(d, ['dayOfWeek', 'isActive', 'startMinute', 'endMinute', 'branchId']);
    const dayOfWeek = integer(d.dayOfWeek, 1, 7), startMinute = integer(d.startMinute, 0, 1410), endMinute = integer(d.endMinute, 30, 1440), branchId = requiredIdentifier(d.branchId, 'branchId');
    if (typeof d.isActive !== 'boolean' || startMinute % 30 || endMinute % 30 || (d.isActive && endMinute <= startMinute) || !assigned.includes(branchId)) throw new InputValidationError('Check weekly day, branch and half-hour boundaries.');
    return { dayOfWeek, isActive: d.isActive, startMinute, endMinute, branchId };
  }).sort((a, b) => a.dayOfWeek - b.dayOfWeek);
  if (new Set(schedule.map(d => d.dayOfWeek)).size !== 7) throw new InputValidationError('Weekly days must be unique.');
  return { dailyCapacityHours, advanceBookingWindowDays, schedule };
}
export function rosterExceptions(raw: unknown): RosterException[] {
  if (!Array.isArray(raw) || raw.length > 64) throw new InputValidationError('At most 64 exceptions are allowed.');
  const result = raw.map((value): RosterException => {
    const e = object(value); allowed(e, ['id', 'type', 'reason', 'startAtMillis', 'endAtMillis']);
    const id = requiredIdentifier(e.id, 'exceptionId'), startAtMillis = integer(e.startAtMillis, 1, MAX_TIME), endAtMillis = integer(e.endAtMillis, 1, MAX_TIME);
    if ((e.type !== 'breakTime' && e.type !== 'offDay' && e.type !== 'leave') || typeof e.reason !== 'string' || e.reason.length > 200
      || /[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/.test(e.reason) || startAtMillis % SLOT || endAtMillis % SLOT || endAtMillis <= startAtMillis || endAtMillis - startAtMillis > 31 * 26 * 3600000) throw new InputValidationError('Check exception type, reason and half-hour boundaries.');
    return { id, type: e.type, reason: e.reason, startAtMillis, endAtMillis };
  }).sort((a, b) => a.id.localeCompare(b.id));
  if (new Set(result.map(e => e.id)).size !== result.length) throw new InputValidationError('Exception IDs must be unique.');
  return result;
}
export function storedRoster(data: DocumentData | undefined, zone: string, assigned: readonly string[]): CoachRoster {
  if (!data) return { revision: 0, weeklyAvailability: null, exceptions: [] };
  try {
    allowed(data, ['schemaVersion', 'revision', 'weeklyAvailability', 'exceptions', 'timeZone', 'policyVersion', 'createdAtMillis', 'updatedAtMillis']);
    if (data.schemaVersion !== 1 || data.timeZone !== zone || typeof data.policyVersion !== 'string' || !data.policyVersion) throw Error();
    const revision = integer(data.revision, 1, Number.MAX_SAFE_INTEGER - 1);
    integer(data.createdAtMillis, 1); integer(data.updatedAtMillis, 1);
    return { revision, weeklyAvailability: weeklyAvailability(data.weeklyAvailability, assigned), exceptions: rosterExceptions(data.exceptions) };
  } catch { throw rosterReview(); }
}
export function weeklyWindows(date: string, zone: string, weekly: WeeklyAvailability | null): AvailabilityWindow[] {
  if (!weekly) return [];
  const dayOfWeek = ((new Date(dateEpoch(date)).getUTCDay() + 6) % 7) + 1, day = weekly.schedule.find(d => d.dayOfWeek === dayOfWeek)!;
  if (!day.isActive) return [];
  const formatter = new Intl.DateTimeFormat('en-GB', { timeZone: zone, hour: '2-digit', minute: '2-digit', hourCycle: 'h23' });
  const windows = dateGrid(date, zone).slots.filter(slot => {
    const parts = formatter.formatToParts(slot), minute = Number(parts.find(p => p.type === 'hour')!.value) * 60 + Number(parts.find(p => p.type === 'minute')!.value);
    return minute >= day.startMinute && minute < day.endMinute;
  }).map(slot => ({ branchId: day.branchId, startAtMillis: slot, endAtMillis: slot + SLOT }));
  return normalizeWindows(windows, date, zone, [day.branchId], 52);
}
export function maskWindows(windows: AvailabilityWindow[], exceptions: readonly RosterException[]): AvailabilityWindow[] {
  const result: AvailabilityWindow[] = [];
  for (const window of windows) {
    let pieces = [{ ...window }];
    for (const e of exceptions) pieces = pieces.flatMap(w => {
      if (e.endAtMillis <= w.startAtMillis || e.startAtMillis >= w.endAtMillis) return [w];
      return [ ...(e.startAtMillis > w.startAtMillis ? [{ ...w, endAtMillis: e.startAtMillis }] : []), ...(e.endAtMillis < w.endAtMillis ? [{ ...w, startAtMillis: e.endAtMillis }] : []) ];
    });
    result.push(...pieces);
  }
  return result;
}
export function resolveRosterDay(data: DocumentData | undefined, date: string, zone: string, assigned: readonly string[], roster: CoachRoster) {
  const day = storedDay(data, date, zone, assigned);
  const baseWindows = data ? day.windows : weeklyWindows(date, zone, roster.weeklyAvailability);
  return { ...day, baseWindows, windows: maskWindows(baseWindows, roster.exceptions) };
}
export function coverage(windows: readonly AvailabilityWindow[], slot: number) { return windows.find(w => w.startAtMillis <= slot && w.endAtMillis >= slot + SLOT)?.branchId; }
export async function activeCoachLocks(tx: TransactionPort, root: string, coachId: string, slots: readonly number[], now: number) {
  const records = await readAll(tx, slots.map(slot => `${root}/slotLocks/${keyOf(coachId, slot)}`)), active = new Map<number, string>();
  const validId = (value: unknown) => typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(value);
  for (const [i, lock] of records.entries()) {
    if (!lock) continue;
    if (lock.schemaVersion !== 1 || lock.coachId !== coachId || !validId(lock.bookingId) || !validId(lock.branchId)
      || (lock.status !== 'confirmed' && lock.status !== 'pending_hold') || (lock.status === 'pending_hold' && (!Number.isSafeInteger(lock.expiresAtMillis) || Number(lock.expiresAtMillis) < 1 || Number(lock.expiresAtMillis) > slots[i]))) throw new DomainError('failed-precondition', 'Reservation lock requires authorized review.');
    if (lock.status === 'confirmed' || Number(lock.expiresAtMillis) > now) active.set(slots[i], String(lock.branchId));
  }
  return active;
}
export function assertLockCoverage(windows: readonly AvailabilityWindow[], locks: ReadonlyMap<number, string>) {
  for (const [slot, branch] of locks) if (coverage(windows, slot) !== branch) throw new DomainError('failed-precondition', 'Stored schedule and reservation disagree.');
}
