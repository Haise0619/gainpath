import { Timestamp, type Firestore } from 'firebase-admin/firestore';
import { describe, expect, it } from 'vitest';
import { readOperationsCalendar } from '../src/modules/analytics/operations-calendar';

const org = 'calendar-org';
const root = `orgs/${org}`;
const auth = { uid: 'admin', token: { email_verified: true } };
const from = Date.parse('2026-11-22T16:00:00Z'); // Monday, 23 November in MYT.
const day = 86_400_000;
const hour = 3_600_000;
const to = from + 2 * day;
const now = from + day + hour;
const zone = 'Asia/Kuala_Lumpur';
const request = { action: 'calendarEvents', organizationId: org, startAtMillis: from, endAtMillis: to };

type Data = Record<string, unknown>;
function firestore(fixture: Record<string, Data>, options: { fail?: string; revoke?: boolean } = {}) {
  type Condition = [string, '==' | '>=' | '<' | '>', unknown];
  const reads: string[] = [];
  const transactions: string[] = [];
  const doc = (path: string) => ({
    id: path.split('/').at(-1)!,
    ref: { path },
    data: () => fixture[path],
    get: async () => doc(path),
    exists: fixture[path] !== undefined,
    collection: (name: string) => query(`${path}/${name}`),
  });
  const coerce = (value: unknown) => value instanceof Timestamp ? value.toMillis() : value;
  const query = (path: string, conditions: Condition[] = [], limit = Infinity) => ({
    where: (...condition: Condition) => query(path, [...conditions, condition], limit),
    limit: (count: number) => query(path, conditions, count),
    select: (..._fields: string[]) => query(path, conditions, limit),
    get: async () => {
      reads.push(path);
      if (options.fail === path) throw Error('Source unavailable');
      const docs = Object.entries(fixture).filter(([key, value]) =>
        key.startsWith(path + '/') && !key.slice(path.length + 1).includes('/') &&
        conditions.every(([field, operation, target]) => {
          const lhs = coerce(value[field]), rhs = coerce(target);
          if (operation === '==') return lhs === rhs;
          if (typeof lhs !== 'number' || typeof rhs !== 'number') return false;
          if (operation === '>=') return lhs >= rhs;
          return operation === '>' ? lhs > rhs : lhs < rhs;
        })).map(([key]) => doc(key)).slice(0, limit);
      return { docs, size: docs.length };
    },
  });
  const db = {
    doc,
    collection: query,
    getAll: async (...refs: (ReturnType<typeof doc> | { fieldMask: string[] })[]) =>
      refs.filter((ref): ref is ReturnType<typeof doc> => 'data' in ref),
    runTransaction: async (work: (tx: {
      get: (ref: ReturnType<typeof doc>) => Promise<ReturnType<typeof doc>>;
      getAll: (...refs: ReturnType<typeof doc>[]) => Promise<ReturnType<typeof doc>[]>;
    }) => Promise<unknown>) => {
      transactions.push('authorize');
      if (options.revoke && transactions.length === 2) {
        fixture[`${root}/members/admin`] = { organizationId: org, branchIds: [], role: 'coach', status: 'active' };
      }
      return work({ get: async ref => ref, getAll: async (...refs) => refs });
    },
  };
  return { db: db as unknown as Firestore, reads, transactions };
}

function receipt(id: string, patch: Data = {}): Data {
  return {
    organizationId: org, bookingId: id, schemaVersion: 1, environment: 'sandbox', provider: 'xendit',
    branchId: 'west', currency: 'MYR', type: 'CoachingBooking', paymentStatus: 'cleared',
    fulfilmentStatus: 'confirmed', amountMinor: 5000, billId: `fixture-${id}`, paymentVerifiedAtMillis: from,
    ...patch,
  };
}
function booking(id: string, patch: Data = {}): Data {
  return {
    schemaVersion: 1, bookingId: id, organizationId: org, memberId: 'member', coachId: 'coach',
    branchId: 'west', requestId: `request-${id}`, createdBy: 'member', startAtMillis: from + hour,
    endAtMillis: from + 2 * hour, durationMinutes: 60, status: 'confirmed',
    holdExpiresAtMillis: from + hour / 2, createdAtMillis: from,
    localDate: '2026-11-23', timeZone: zone, policyVersion: 'booking-v1',
    ...patch,
  };
}

function announcement(patch: Data = {}): Data {
  return {
    schemaVersion: 1, revision: 1, status: 'published', title: 'Gym Notice', body: 'Service work',
    validFrom: Timestamp.fromMillis(from - day), validTo: Timestamp.fromMillis(from + day),
    ...patch,
  };
}
function seeds(): Record<string, Data> {
  const roster = {
    schemaVersion: 1, revision: 1, timeZone: zone, policyVersion: 'booking-v1',
    createdAtMillis: from - day, updatedAtMillis: from - day,
  };
  return {
    [root]: { status: 'active' },
    'users/admin': { organizationId: org, role: 'admin' },
    [`${root}/members/admin`]: { organizationId: org, branchIds: [], role: 'admin', status: 'active' },
    [`${root}/branches/east`]: { status: 'active', displayName: 'East' },
    [`${root}/branches/west`]: { status: 'inactive', displayName: 'West' },
    [`${root}/settings/booking`]: { schemaVersion: 1, timeZone: zone, policyVersion: 'booking-v1', holdMinutes: 15, maxActiveBookingsPerMemberPerDay: 4 },
    [`${root}/coaches/coach`]: { displayName: 'Coach Jade', branchIds: ['east', 'west'], status: 'published' },
    [`${root}/members/coach`]: { organizationId: org, branchIds: ['east', 'west'], role: 'coach', status: 'active' },
    'users/coach': { organizationId: org, role: 'coach' },
    [`${root}/coachAvailability/coach`]: {
      ...roster, weeklyAvailability: {
        dailyCapacityHours: 5, advanceBookingWindowDays: 30,
        schedule: Array.from({ length: 7 }, (_, index) => ({
          dayOfWeek: index + 1, isActive: index < 2, startMinute: 600, endMinute: 720, branchId: 'east',
        })),
      },
      exceptions: [{
        id: 'break', type: 'breakTime', reason: 'Hidden', startAtMillis: from + (day + 10.5 * hour), endAtMillis: from + (day + 11 * hour),
      }],
    },
    [`${root}/coachAvailability/coach/days/2026-11-23`]: {
      ...roster, windows: [{ branchId: 'east', startAtMillis: from + 8 * hour, endAtMillis: from + 10 * hour }],
    },
    [`${root}/bookings/confirmed`]: booking('confirmed'),
    [`${root}/bookings/pending`]: booking('pending', { status: 'pending_hold', branchId: 'east' }),
    [`${root}/bookings/boundary`]: booking('boundary', { startAtMillis: to, endAtMillis: to + hour, localDate: '2026-11-25' }),
    [`${root}/bookings/foreign`]: booking('foreign', { organizationId: 'other' }),
    [`${root}/transactions/confirmed`]: receipt('confirmed'),
    [`${root}/transactions/pending`]: receipt('pending', { branchId: 'east', paymentStatus: 'pending', fulfilmentStatus: 'awaiting_payment' }),
    [`${root}/transactions/review`]: receipt('review', { fulfilmentStatus: 'reconciliation_required' }),
    [`${root}/transactions/refunded`]: receipt('refunded', { refundStatus: 'completed' }),
    [`${root}/announcements/global`]: announcement(),
    [`${root}/announcements/west`]: announcement({
      audienceScope: 'branches', targetBranchIds: ['west'], category: 'closure',
      validFrom: Timestamp.fromMillis(from - hour / 2), validTo: Timestamp.fromMillis(from + hour / 2),
    }),
    [`${root}/announcements/draft`]: announcement({ status: 'draft' }),
    [`${root}/announcements/inactive`]: announcement({ status: 'inactive' }),
    [`${root}/announcements/old`]: announcement({ validTo: Timestamp.fromMillis(from) }),
    [`${root}/announcements/future`]: announcement({ validFrom: Timestamp.fromMillis(to), validTo: Timestamp.fromMillis(to + day) }),
    [`${root}/branches/west/gymVisits/canonical`]: { branchId: 'west', memberId: 'member', source: 'branch_qr', checkedInAtMillis: from },
    [`${root}/branches/west/gymVisits/daily`]: { branchId: 'west', memberId: 'member', source: 'daily', checkedInAtMillis: from },
    [`${root}/members/member/gymVisits/duplicate`]: { branchId: 'west', memberId: 'member', source: 'branch_qr', checkedInAtMillis: from },
  };
}

describe('Operations Calendar reads', () => {
  it('keeps a valid refunded booking visible without marking its source unavailable', async () => {
    const fixture = seeds();
    fixture[`${root}/bookings/refunded`] = booking('refunded', {
      status: 'refunded', resolution: 'coach_cancelled', resolvedAtMillis: from + 1000,
    });
    const { db } = firestore(fixture);
    const result = await readOperationsCalendar(db, auth, { ...request, types: ['booking'] }, () => now);
    expect(result).toMatchObject({ unavailable: [], events: expect.arrayContaining([
      expect.objectContaining({ sourceId: 'refunded', status: 'refunded' }),
    ]) });
  });

  it('uses actual booking branches, projects confirmed and pending payments, and includes valid announcement overlaps once', async () => {
    const { db, reads, transactions } = firestore(seeds());
    const result = await readOperationsCalendar(db, auth, { ...request, branchId: 'west' }, () => now);
    expect(result).toMatchObject({
      unavailable: [],
      events: [
        { sourceId: 'global', type: 'announcement', status: 'expired', allDay: true },
        { sourceId: 'west', type: 'announcement', branchIds: ['west'], category: 'closure', allDay: false },
        { sourceId: 'confirmed', type: 'booking', branchId: 'west', title: 'Coach Jade', status: 'confirmed', paymentStatus: 'cleared' },
      ],
    });
    const all = await readOperationsCalendar(db, auth, { ...request, types: ['booking'] }, () => now);
    expect(all).toMatchObject({ events: [{ sourceId: 'confirmed' }, { sourceId: 'pending', paymentStatus: 'pending' }] });
    expect(JSON.stringify(result)).not.toMatch(/memberId|billId|amountMinor|requestId|targetBranchIds/);
    expect(reads.filter(path => path === `${root}/announcements`)).toHaveLength(1);
    expect(transactions).toHaveLength(4);
  });

  it('reads the day override and masks weekly windows with the existing break, preserving real branches', async () => {
    const { db } = firestore(seeds());
    const result = await readOperationsCalendar(db, auth, { ...request, branchId: 'east', types: ['availability'] }, () => now);
    expect(result).toMatchObject({
      unavailable: [],
      events: [
        { coachId: 'coach', branchId: 'east', startAtMillis: from + 8 * hour, endAtMillis: from + 10 * hour },
        { coachId: 'coach', branchId: 'east', startAtMillis: from + day + 10 * hour, endAtMillis: from + day + 10.5 * hour },
        { coachId: 'coach', branchId: 'east', startAtMillis: from + day + 11 * hour, endAtMillis: from + day + 12 * hour },
      ],
    });
    expect(JSON.stringify(result)).not.toContain('Hidden');
  });

  it('reports legacy availability requiring review instead of calling it published', async () => {
    const documents = seeds();
    const date = new Date(from + 8 * hour).toISOString().slice(0, 10);
    documents[`${root}/coachAvailability/coach/days/${date}`] = {
      schemaVersion: 1,
      windows: [{ branchId: 'east', startAtMillis: from + 8 * hour, endAtMillis: from + 10 * hour }],
    };
    const { db } = firestore(documents);
    const result = await readOperationsCalendar(db, auth, {
      ...request, types: ['availability'], endAtMillis: from + day,
    }, () => now);
    expect(result).toEqual({ events: [], unavailable: ['availability'] });
  });

  it('buckets booking creation, verified sandbox receipts, and successful branch visits in MYT', async () => {
    const { db } = firestore(seeds());
    const result = await readOperationsCalendar(db, auth, {
      ...request, action: 'calendarInsights', branchId: 'west', endAtMillis: to + day,
    }, () => now);
    expect(result).toEqual({
      daily: [
        { date: '2026-11-23', bookings: 2, coachingMinor: 5000, visits: 1 },
        { date: '2026-11-24', bookings: 0, coachingMinor: 0, visits: 0 },
        { date: '2026-11-25', bookings: null, coachingMinor: null, visits: null },
      ],
      unavailable: [],
    });
  });

  it('keeps a failed series unavailable while returning confirmed zeros for working series', async () => {
    const { db } = firestore(seeds(), { fail: `${root}/transactions` });
    const result = await readOperationsCalendar(db, auth, { ...request, action: 'calendarInsights', branchId: 'east' }, () => now);
    expect(result).toMatchObject({
      daily: [
        { date: '2026-11-23', bookings: 1, coachingMinor: null, visits: 0 },
        { date: '2026-11-24', bookings: 0, coachingMinor: null, visits: 0 },
      ], unavailable: ['coachingMinor'],
    });
  });

  it('rejects invalid dates, unknown branches, and unauthorized or revoked callers', async () => {
    const { db, reads } = firestore(seeds());
    await expect(readOperationsCalendar(db, undefined, request)).rejects.toMatchObject({ code: 'unauthenticated' });
    await expect(readOperationsCalendar(db, { uid: 'admin', token: {} }, request)).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(readOperationsCalendar(db, auth, { ...request, organizationId: 'other' })).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(readOperationsCalendar(db, auth, { ...request, branchId: 'invalid' })).rejects.toMatchObject({ code: 'not-found' });
    await expect(readOperationsCalendar(db, auth, { ...request, startAtMillis: from + 1 })).rejects.toMatchObject({ code: 'invalid-argument' });
    await expect(readOperationsCalendar(db, auth, { ...request, endAtMillis: from + 43 * day })).rejects.toMatchObject({ code: 'invalid-argument' });
    expect(reads).toEqual([]);
    const revoked = firestore(seeds(), { revoke: true });
    await expect(readOperationsCalendar(revoked.db, auth, request, () => now)).rejects.toMatchObject({ code: 'permission-denied' });
  });
});
