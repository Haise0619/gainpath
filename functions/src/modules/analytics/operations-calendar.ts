import { Timestamp, type Firestore, type Query } from 'firebase-admin/firestore';
import { requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import type { DocumentData } from '../../platform/firestore/store';
import { requiredIdentifier } from '../../platform/validation';
import { storedBooking } from '../coaching/booking-record';
import { branchIds, bookingPolicy, dateGrid } from '../coaching/coach-availability-contracts';
import { resolveRosterDay, storedRoster } from '../coaching/coach-roster-contracts';
import { validBookingId } from '../coaching/booking-validation';
import { authorizeAdminReport } from './admin-reporting';
import {
  branchReportDate, clockNumber, confirmedCoachingReceipt, inBranchReportRange,
  MALAYSIA_TIME_ZONE, MALAYSIA_UTC_OFFSET, successfulBranchVisit,
} from './branch-report-activity';

const day = 86_400_000;
const hour = 3_600_000;
const lastMidnight = Date.parse('9999-01-01T00:00:00+08:00');
const eventTypes = ['booking', 'availability', 'announcement'] as const;
const metrics = ['visits', 'bookings', 'coachingMinor'] as const;
type EventType = typeof eventTypes[number];
type Metric = typeof metrics[number];
type Auth = { uid: string; token: Record<string, unknown> } | undefined;
type Range = { from: number; to: number; branchId?: string };
type CalendarEvent = {
  id: string;
  sourceId: string;
  type: EventType;
  title: string;
  startAtMillis: number;
  endAtMillis: number;
  status: string;
  branchId?: string;
  branchIds?: string[];
  coachId?: string;
  paymentStatus?: string;
  description?: string;
  category?: string;
  allDay?: boolean;
};
type ScopedCalendar = Range & { db: Firestore; org: string; root: string; now: number };
type EventSource = { events: CalendarEvent[]; incomplete?: boolean };

function readRange(input: Record<string, unknown>): Range {
  const from = input.startAtMillis, to = input.endAtMillis;
  if (!clockNumber(from) || !clockNumber(to) || from >= to || to > lastMidnight
    || to - from > 42 * day || (from + MALAYSIA_UTC_OFFSET) % day || (to + MALAYSIA_UTC_OFFSET) % day) {
    throw new DomainError('invalid-argument', 'Choose up to 42 complete Malaysia Time calendar days.');
  }
  return { from, to, ...(input.branchId === undefined ? {} : { branchId: requiredIdentifier(input.branchId, 'branchId') }) };
}

function requestedTypes(raw: unknown): EventType[] {
  if (raw === undefined) return [...eventTypes];
  if (!Array.isArray(raw) || raw.length > eventTypes.length
    || !raw.every(type => eventTypes.includes(type as EventType))) {
    throw new DomainError('invalid-argument', 'Choose supported calendar event types.');
  }
  return [...new Set<EventType>(raw)];
}

export async function readOperationsCalendar(db: Firestore, auth: Auth, input: Record<string, unknown>, clock = Date.now) {
  requireVerifiedEmail(auth);
  const org = requiredIdentifier(input.organizationId, 'organizationId');
  const range = readRange(input);
  const scope = { db, org, root: `orgs/${org}`, now: clock(), ...range };
  const store = new FirestoreStore(db);
  const authorize = () => store.transact(async tx => {
    await authorizeAdminReport(tx, auth!, org);
    if (range.branchId && !await tx.get(`${scope.root}/branches/${range.branchId}`)) {
      throw new DomainError('not-found', 'Branch unavailable.');
    }
  });
  await authorize();
  const result = input.action === 'calendarInsights'
    ? await calendarInsights(scope)
    : await calendarEvents(scope, requestedTypes(input.types));
  await authorize();
  return result;
}

async function boundedRows(query: Query, limit = 1500) {
  const snapshot = await query.limit(limit + 1).get();
  if (snapshot.size > limit) {
    throw new DomainError('resource-exhausted', 'This calendar source exceeds the available record limit.');
  }
  return snapshot.docs.map(doc => ({ id: doc.id, data: doc.data() }));
}

async function batchDocuments(db: Firestore, paths: string[], fields?: string[]) {
  const batchSize = 240, concurrency = 4;
  const documents = new Map<string, DocumentData>();
  for (let offset = 0; offset < paths.length; offset += batchSize * concurrency) {
    const requests: ReturnType<Firestore['getAll']>[] = [];
    for (let i = offset; i < Math.min(offset + batchSize * concurrency, paths.length); i += batchSize) {
      const refs = paths.slice(i, i + batchSize).map(path => db.doc(path));
      requests.push(fields ? db.getAll(...refs, { fieldMask: fields }) : db.getAll(...refs));
    }
    for (const batch of await Promise.all(requests)) {
      for (const doc of batch) {
        const data = doc.data();
        if (data !== undefined) documents.set(doc.ref.path, data);
      }
    }
  }
  return documents;
}

function eachDate({ from, to }: Range) {
  return Array.from({ length: (to - from) / day }, (_, i) => branchReportDate(from + i * day));
}

function inScope(scope: ScopedCalendar, branchId: unknown) {
  return scope.branchId === undefined || scope.branchId === branchId;
}

function overlaps(record: { startAtMillis: number; endAtMillis: number }, { from, to }: Range) {
  return record.startAtMillis < to && record.endAtMillis > from;
}

function name(value: unknown) {
  return typeof value === 'string' && value.trim() && value.trim().length <= 80 ? value.trim() : undefined;
}

const paymentFields = [
  'type', 'schemaVersion', 'bookingId', 'organizationId', 'branchId', 'coachId', 'memberId',
  'paymentStatus', 'fulfilmentStatus', 'paymentVerifiedAtMillis', 'refundStatus',
  'amountMinor', 'billId', 'currency', 'provider', 'environment',
];

async function bookingEvents(scope: ScopedCalendar): Promise<EventSource> {
  const { db, root, from, to, org, now } = scope;
  // The booking contract caps sessions at 60 minutes. One indexed start-time
  // window covers every overlap and avoids a new branch/start composite index.
  const rows = await boundedRows(db.collection(`${root}/bookings`)
    .where('startAtMillis', '>=', from - hour).where('startAtMillis', '<', to));
  let incomplete = false;
  const bookings = rows.flatMap(({ id, data }) => {
    if (!inScope(scope, data.branchId) || data.organizationId !== org || !(Number(data.endAtMillis) > from)) return [];
    try {
      return [storedBooking(data, org, id)];
    } catch (error) {
      if (!(error instanceof DomainError)) throw error;
      incomplete = true;
      return [];
    }
  });
  const coachIds = [...new Set(bookings.map(booking => booking.coachId))];
  const [names, payments] = await Promise.allSettled([
    batchDocuments(db, coachIds.flatMap(id => [`${root}/coachProfiles/${id}`, `${root}/coaches/${id}`]), ['displayName']),
    batchDocuments(db, bookings.map(booking => `${root}/transactions/${booking.bookingId}`), paymentFields),
  ]);
  if (names.status === 'rejected' || payments.status === 'rejected') incomplete = true;
  const events = bookings.map(booking => {
    const { bookingId, coachId, branchId, startAtMillis, endAtMillis, status, memberId } = booking;
    const profiles = names.status === 'fulfilled' ? names.value : undefined;
    const title = name(profiles?.get(`${root}/coachProfiles/${coachId}`)?.displayName)
      ?? name(profiles?.get(`${root}/coaches/${coachId}`)?.displayName) ?? 'Coach session';
    const payment = payments.status === 'fulfilled' ? payments.value.get(`${root}/transactions/${bookingId}`) : undefined;
    let paymentStatus: string | undefined;
    if (payment?.type === 'CoachingBooking' && payment.organizationId === org && payment.bookingId === bookingId
      && (payment.branchId === undefined || payment.branchId === branchId)
      && (payment.coachId === undefined || payment.coachId === coachId)
      && (payment.memberId === undefined || payment.memberId === memberId)) {
      if (payment.fulfilmentStatus === 'reconciliation_required') {
        paymentStatus = 'reconciliation_required';
      } else if (payment.paymentStatus === 'pending') {
        paymentStatus = 'pending';
      } else if (payment.paymentStatus === 'cleared') {
        try {
          const receipt = confirmedCoachingReceipt({ ...payment, id: bookingId }, org, 0, now + 1, now, new Set());
          paymentStatus = receipt ? 'cleared' : undefined;
        } catch (error) {
          if (!(error instanceof DomainError)) throw error;
          paymentStatus = 'reconciliation_required';
        }
      }
    }
    return {
      id: `booking:${bookingId}`, sourceId: bookingId, type: 'booking' as const, title,
      coachId, branchId, startAtMillis, endAtMillis, status,
      ...(paymentStatus ? { paymentStatus } : {}),
    };
  });
  return { events, incomplete };
}

async function availabilityEvents(scope: ScopedCalendar): Promise<EventSource> {
  const { db, root, org, now } = scope;
  const [policyDoc, directory, coaches] = await Promise.all([
    db.doc(`${root}/settings/booking`).get(),
    boundedRows(db.collection(`${root}/branches`).where('status', '==', 'active').select(), 100),
    boundedRows(db.collection(`${root}/coaches`).where('status', '==', 'published').select('branchIds', 'displayName'), 150),
  ]);
  const { timeZone } = bookingPolicy(policyDoc.data());
  if (timeZone !== MALAYSIA_TIME_ZONE) throw new DomainError('failed-precondition', 'The booking timezone requires review.');
  const active = new Set(directory.map(doc => doc.id).filter(id => inScope(scope, id)));
  let incomplete = false;
  const published = coaches.flatMap(({ id, data }) => {
    if (!validBookingId(id)) return [];
    try {
      const visible = branchIds(data.branchIds).filter(branch => active.has(branch));
      return visible.length ? [{ id, visible, name: name(data.displayName) ?? 'Coach availability' }] : [];
    } catch (error) {
      incomplete = true;
      return [];
    }
  });
  const identity = await batchDocuments(db, published.flatMap(({ id }) => [`${root}/members/${id}`, `users/${id}`]),
    ['organizationId', 'role', 'status', 'branchIds']);
  const assigned = published.flatMap(coach => {
    const member = identity.get(`${root}/members/${coach.id}`);
    if (member?.status !== 'active' || member.role !== 'coach' || member.organizationId !== org
      || identity.get(`users/${coach.id}`)?.organizationId !== org) return [];
    try {
      const branches = branchIds(member.branchIds);
      const visible = coach.visible.filter(id => branches.includes(id));
      return visible.length ? [{ ...coach, visible, branches, path: `${root}/coachAvailability/${coach.id}` }] : [];
    } catch (error) {
      incomplete = true;
      return [];
    }
  });
  const through = branchReportDate(now + 30 * day);
  const dates = eachDate(scope).filter(date => date <= through)
    .map(date => ({ date, slots: dateGrid(date, timeZone).slots }));
  const schedule = await batchDocuments(db, assigned.flatMap(({ path }) => [path, ...dates.map(({ date }) => `${path}/days/${date}`)]));
  const events: CalendarEvent[] = [];
  const today = branchReportDate(now);
  for (const coach of assigned) {
    try {
      const roster = storedRoster(schedule.get(coach.path), timeZone, coach.branches);
      for (const { date, slots } of dates) {
        const override = schedule.get(`${coach.path}/days/${date}`);
        // The weekly record describes the current roster. A past date needs
        // a dated source because the roster is mutable and has no history.
        if (!override && date < today) continue;
        const resolved = resolveRosterDay(override, date, timeZone, coach.branches, roster, slots);
        if (resolved.reviewRequired) {
          incomplete = true;
          continue;
        }
        for (const window of resolved.windows) {
          if (coach.visible.includes(window.branchId)) {
            events.push({
              ...window, id: `availability:${coach.id}:${window.branchId}:${window.startAtMillis}`,
              sourceId: coach.id, type: 'availability', coachId: coach.id,
              title: coach.name, status: 'published',
            });
          }
        }
      }
    } catch (error) {
      if (!(error instanceof DomainError)) throw error;
      incomplete = true;
    }
  }
  return { events, incomplete };
}

const categories = new Set(['general', 'maintenance', 'closure', 'promotion', 'event', 'update']);

async function announcementEvents(scope: ScopedCalendar): Promise<EventSource> {
  const { db, root, org, from, now } = scope;
  // There is no fixed maximum publication length. Index on expiry and filter
  // validity start in memory to retain long-running notices in every view.
  const rows = await boundedRows(db.collection(`${root}/announcements`)
    .where('validTo', '>', Timestamp.fromMillis(from))
    .select('organizationId', 'schemaVersion', 'revision', 'status', 'title', 'body', 'validFrom',
      'validTo', 'audienceScope', 'targetBranchIds', 'category'), 600);
  let incomplete = false;
  const events: CalendarEvent[] = [];
  for (const { id, data } of rows) {
    if (data.status !== 'published' || (data.organizationId !== undefined && data.organizationId !== org)) continue;
    if (data.schemaVersion !== 1 || !clockNumber(data.revision) || data.revision < 1
      || !(data.validFrom instanceof Timestamp) || !(data.validTo instanceof Timestamp)
      || typeof data.title !== 'string' || !data.title.trim() || data.title.length > 120
      || typeof data.body !== 'string' || !data.body.trim() || data.body.length > 4000) {
      incomplete = true;
      continue;
    }
    const startAtMillis = Math.floor(data.validFrom.toMillis());
    const endAtMillis = Math.floor(data.validTo.toMillis());
    if (endAtMillis <= startAtMillis) {
      incomplete = true;
      continue;
    }
    if (!overlaps({ startAtMillis, endAtMillis }, scope)) continue;
    const audience = data.audienceScope ?? 'all';
    const target = data.targetBranchIds ?? [];
    const category = data.category ?? 'general';
    let targets: string[] = [];
    try {
      if (audience === 'branches') targets = branchIds(target);
      else if (audience !== 'all' || !Array.isArray(target) || target.length !== 0) throw Error();
      if (typeof category !== 'string' || !categories.has(category)) throw Error();
    } catch {
      incomplete = true;
      continue;
    }
    if (scope.branchId && targets.length && !targets.includes(scope.branchId)) continue;
    const message = data.body.trim();
    events.push({
      id: `announcement:${id}`, sourceId: id, type: 'announcement', title: data.title.trim(),
      startAtMillis, endAtMillis, status: now < startAtMillis ? 'scheduled' : now >= endAtMillis ? 'expired' : 'active',
      description: message.length > 240 ? `${message.slice(0, 239)}…` : message, category,
      ...(targets.length ? { branchIds: targets } : {}),
      allDay: (startAtMillis + MALAYSIA_UTC_OFFSET) % day === 0
        && (endAtMillis + MALAYSIA_UTC_OFFSET) % day === 0,
    });
  }
  return { events, incomplete };
}

async function calendarEvents(scope: ScopedCalendar, types: EventType[]) {
  const sources = { booking: bookingEvents, availability: availabilityEvents, announcement: announcementEvents };
  const results = await Promise.allSettled(types.map(type => sources[type](scope)));
  const events: CalendarEvent[] = [];
  const unavailable: EventType[] = [];
  for (const [i, result] of results.entries()) {
    if (result.status === 'fulfilled') events.push(...result.value.events);
    if (result.status === 'rejected' || result.value.incomplete) unavailable.push(types[i]);
  }
  events.sort((a, b) => a.startAtMillis - b.startAtMillis || a.id.localeCompare(b.id));
  return { events, unavailable };
}

async function calendarInsights(scope: ScopedCalendar) {
  const { db, root, org, branchId, from, now } = scope;
  const to = Math.min(scope.to, now + 1);
  const today = branchReportDate(now);
  const countByDay = (rows: Iterable<[number, number]>) => {
    const counts = new Map<string, number>();
    for (const [instant, value] of rows) {
      const date = branchReportDate(instant);
      const count = (counts.get(date) ?? 0) + value;
      if (!Number.isSafeInteger(count)) throw new DomainError('failed-precondition', 'Daily totals exceed the supported range.');
      counts.set(date, count);
    }
    return counts;
  };
  const activity = (collection: string, field: string) =>
    db.collection(`${root}/${collection}`).where(field, '>=', from).where(field, '<', to);
  const sources: Record<Metric, () => Promise<Map<string, number>>> = {
    visits: async () => {
      const ids = branchId ? [branchId] : (await boundedRows(db.collection(`${root}/branches`).select(), 100))
        .map(row => row.id);
      const counts: [number, number][] = [];
      for (let offset = 0; offset < ids.length; offset += 10) {
        const results = await Promise.all(ids.slice(offset, offset + 10).map(async id => {
          const visits = await boundedRows(activity(`branches/${id}/gymVisits`, 'checkedInAtMillis')
            .select('branchId', 'memberId', 'source', 'checkedInAtMillis'));
          return visits.flatMap(({ data }) => {
            const visit = successfulBranchVisit(data, id, from, to);
            return visit ? [visit.checkedInAtMillis] : [];
          });
        }));
        for (const result of results) for (const instant of result) counts.push([instant, 1]);
      }
      return countByDay(counts);
    },
    bookings: async () => {
      const rows = await boundedRows(activity('bookings', 'createdAtMillis').select('organizationId', 'branchId', 'createdAtMillis'));
      return countByDay(rows.flatMap(({ data }) =>
        inScope(scope, data.branchId) && (data.organizationId === undefined || data.organizationId === org)
        && inBranchReportRange(data.createdAtMillis, from, to) ? [[data.createdAtMillis, 1]] : []));
    },
    coachingMinor: async () => {
      const rows = await boundedRows(activity('transactions', 'paymentVerifiedAtMillis').select(...paymentFields));
      const bills = new Set<string>();
      return countByDay(rows.flatMap(({ id, data }) => {
        if (!inScope(scope, data.branchId)) return [];
        const receipt = confirmedCoachingReceipt({ ...data, id }, org, from, to, now, bills);
        return receipt ? [[receipt.paymentVerifiedAtMillis, receipt.amountMinor]] : [];
      }));
    },
  };
  const results = from < to
    ? await Promise.allSettled(metrics.map(metric => sources[metric]()))
    : [];
  const unavailable = metrics.filter((_, i) => results[i]?.status === 'rejected');
  const daily = eachDate(scope).map(date => {
    const value = (index: number) => {
      const result = results[index];
      return date <= today && result?.status === 'fulfilled' ? result.value.get(date) ?? 0 : null;
    };
    return { date, visits: value(0), bookings: value(1), coachingMinor: value(2) };
  });
  return { daily, unavailable };
}
