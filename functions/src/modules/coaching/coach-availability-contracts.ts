import type { DocumentData } from '../../platform/firestore/store';
import { DomainError } from '../../platform/errors';
import { InputValidationError, requiredIdentifier } from '../../platform/validation';

export const SLOT = 1800000, MAX_TIME = 8639999996400000;
export interface AvailabilityWindow { branchId: string; startAtMillis: number; endAtMillis: number }
export interface TimeBoundary { atMillis: number; label: string }
export function object(value: unknown): DocumentData {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new InputValidationError('A scheduling object is required.');
  return value as DocumentData;
}
export function allowed(data: DocumentData, keys: readonly string[]) {
  if (Object.keys(data).some(k => !keys.includes(k))) throw new InputValidationError('Unsupported scheduling field.');
}
export function integer(value: unknown, min = 0, max = MAX_TIME): number {
  if (!Number.isSafeInteger(value) || Number(value) < min || Number(value) > max) throw new InputValidationError('Invalid scheduling number.');
  return Number(value);
}
export function branchIds(value: unknown): string[] {
  if (!Array.isArray(value) || value.length < 1 || value.length > 8) throw new InputValidationError('Valid current branch assignments are required.');
  const ids = value.map(v => requiredIdentifier(v, 'branchId')).sort();
  if (new Set(ids).size !== ids.length) throw new InputValidationError('Branch assignments must be unique.');
  return ids;
}
export function dateEpoch(value: unknown): number {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) throw new InputValidationError('A calendar date is required.');
  const epoch = Date.parse(`${value}T00:00:00Z`);
  if (!Number.isFinite(epoch) || new Date(epoch).toISOString().slice(0, 10) !== value) throw new InputValidationError('Invalid calendar date.');
  return epoch;
}
export function plusDate(date: string, days: number) { return new Date(dateEpoch(date) + days * 86400000).toISOString().slice(0, 10); }
function dateFormatter(zone: string) {
  return new Intl.DateTimeFormat('en-CA', { timeZone: zone, year: 'numeric', month: '2-digit', day: '2-digit' });
}
function formattedDate(formatter: Intl.DateTimeFormat, millis: number) {
  const parts = formatter.formatToParts(millis), part = (key: string) => parts.find(p => p.type === key)!.value;
  return `${part('year')}-${part('month')}-${part('day')}`;
}
export function localDate(millis: number, zone: string) { return formattedDate(dateFormatter(zone), millis); }
export function dateGrid(date: string, zone: string): { slots: number[]; boundaries: TimeBoundary[] } {
  const epoch = dateEpoch(date), formatter = dateFormatter(zone);
  const label = new Intl.DateTimeFormat('en-GB', { timeZone: zone, hour: '2-digit', minute: '2-digit', hourCycle: 'h23', timeZoneName: 'shortOffset' });
  const slots: number[] = [];
  for (let t = epoch - 36 * 3600000; t < epoch + 60 * 3600000; t += SLOT) {
    if (formattedDate(formatter, t) === date && formattedDate(formatter, t + SLOT - 1) === date) slots.push(t);
  }
  if (!slots.length || slots.length > 52) throw new DomainError('failed-precondition', 'This local date is unsupported by the scheduling grid.');
  const ends = [...new Set(slots.flatMap(t => [t, t + SLOT]))].sort((a, b) => a - b);
  return { slots, boundaries: ends.map(atMillis => ({ atMillis, label: label.format(atMillis) })) };
}
export function bookingPolicy(data: DocumentData | undefined) {
  if (data?.schemaVersion !== 1 || typeof data.policyVersion !== 'string' || !data.policyVersion
    || typeof data.timeZone !== 'string' || !Number.isInteger(data.maxActiveBookingsPerMemberPerDay)
    || Number(data.maxActiveBookingsPerMemberPerDay) < 1 || Number(data.maxActiveBookingsPerMemberPerDay) > 32
    || !Number.isInteger(data.holdMinutes) || Number(data.holdMinutes) < 1 || Number(data.holdMinutes) > 30) throw new DomainError('failed-precondition', 'Organization booking policy needs configuration.');
  try { dateFormatter(data.timeZone).format(); }
  catch { throw new DomainError('failed-precondition', 'Organization timezone needs review.'); }
  return { timeZone: data.timeZone, policyVersion: data.policyVersion };
}
export function normalizeWindows(raw: unknown, date: string, zone: string, permitted: readonly string[], max = 16): AvailabilityWindow[] {
  if (!Array.isArray(raw) || raw.length > max) throw new InputValidationError('Too many scheduling windows.');
  const slots = new Set(dateGrid(date, zone).slots);
  const list = raw.map(value => {
    const w = object(value); allowed(w, ['branchId', 'startAtMillis', 'endAtMillis']);
    const branchId = requiredIdentifier(w.branchId, 'branchId'), startAtMillis = integer(w.startAtMillis, 1), endAtMillis = integer(w.endAtMillis, 1);
    if (!permitted.includes(branchId) || endAtMillis <= startAtMillis || startAtMillis % SLOT || endAtMillis % SLOT || endAtMillis - startAtMillis > 26 * 3600000) throw new InputValidationError('Check the branch and UTC time boundaries.');
    for (let t = startAtMillis; t < endAtMillis; t += SLOT) if (!slots.has(t)) throw new InputValidationError('A window must stay within its local date.');
    return { branchId, startAtMillis, endAtMillis };
  }).sort((a, b) => a.startAtMillis - b.startAtMillis || a.branchId.localeCompare(b.branchId));
  const result: AvailabilityWindow[] = [];
  for (const w of list) {
    const previous = result.at(-1);
    if (previous && previous.endAtMillis > w.startAtMillis) throw new InputValidationError('Scheduling windows cannot overlap.');
    if (previous && previous.branchId === w.branchId && previous.endAtMillis === w.startAtMillis) previous.endAtMillis = w.endAtMillis;
    else result.push({ ...w });
  }
  return result;
}
export function storedDay(data: DocumentData | undefined, date: string, zone: string, permitted: readonly string[]) {
  if (!data) return { revision: 0, windows: [] as AvailabilityWindow[], reviewRequired: false };
  try {
    allowed(data, ['schemaVersion', 'windows', 'revision', 'timeZone', 'policyVersion', 'createdAtMillis', 'updatedAtMillis']);
    if (data.schemaVersion !== 1) throw Error();
    const windows = normalizeWindows(data.windows, date, zone, permitted, 96);
    const metadata = ['revision', 'timeZone', 'policyVersion', 'createdAtMillis', 'updatedAtMillis'];
    if (metadata.every(k => !Object.hasOwn(data, k))) return { revision: 0, windows, reviewRequired: true };
    const revision = integer(data.revision, 1, Number.MAX_SAFE_INTEGER - 1);
    integer(data.createdAtMillis); integer(data.updatedAtMillis);
    if (data.timeZone !== zone || typeof data.policyVersion !== 'string' || !data.policyVersion) throw Error();
    return { revision, windows, reviewRequired: false };
  } catch { throw new DomainError('failed-precondition', 'The stored schedule requires authorized review.'); }
}
