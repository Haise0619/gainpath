import type { Firestore, Query } from 'firebase-admin/firestore';
import { DomainError } from '../../platform/errors';
import { requiredIdentifier } from '../../platform/validation';

const cap = 1500;
const unassigned = 'unassigned';
const clockNumber = (v: unknown): v is number => typeof v === 'number' && Number.isSafeInteger(v) && v >= 0;

type Daily = { date: string; bookings: number; completed: number; cancelled: number;
  coachingMinor: number; workouts: number; visits: number | null };

function reportBucket(branchId: string, branchName: string, status: string | null, visitsAvailable = true) {
  return {
    branchId, branchName, status, homeMembers: 0, assignedCoaches: 0,
    bookingsCreated: 0, completedSessions: 0, cancelledSessions: 0,
    acceptedWorkouts: 0, coachingMinor: 0, actualCoachingMinor: null,
    visitsAvailable, daily: new Map<string, Daily>(), visitorCounts: new Map<string, number>(),
    hours: Array<number>(24).fill(0),
  };
}

type Bucket = ReturnType<typeof reportBucket>;

function increment(bucket: Bucket, instant: number, metric: Exclude<keyof Daily, 'date'>, amount = 1) {
  const date = new Date(instant + 8 * 3600000).toISOString().slice(0, 10);
  const row = bucket.daily.get(date) ?? { date, bookings: 0, completed: 0, cancelled: 0,
    coachingMinor: 0, workouts: 0, visits: bucket.visitsAvailable ? 0 : null };
  row[metric] = (row[metric] ?? 0) + amount;
  bucket.daily.set(date, row);
}

function summarize(bucket: Bucket) {
  const { daily, visitorCounts, hours, visitsAvailable, ...totals } = bucket;
  const peak = Math.max(...hours);
  return {
    ...totals,
    daily: [...daily.values()].sort((a, b) => a.date.localeCompare(b.date)),
    gymVisits: visitsAvailable ? hours.reduce((sum, count) => sum + count, 0) : null,
    uniqueVisitors: visitsAvailable ? visitorCounts.size : null,
    repeatVisitors: visitsAvailable ? [...visitorCounts.values()].filter(count => count > 1).length : null,
    peakHours: peak > 0 ? hours.flatMap((count, hour) => count === peak ? [hour] : []) : [],
  };
}

async function rows(query: Query) {
  const result = await query.limit(cap + 1).get();
  if (result.size > cap) throw new DomainError('resource-exhausted', 'This branch report exceeds the available record limit.');
  return result.docs.map(doc => ({ ...doc.data(), id: doc.id } as Record<string, unknown> & { id: string }));
}

export async function readBranchReport(db: Firestore, org: string, input: Record<string, unknown>) {
  const from = input.startAtMillis, to = input.endAtMillis, now = Date.now();
  if (!clockNumber(from) || !clockNumber(to) || from >= to || to > now + 86400000) {
    throw new DomainError('invalid-argument', 'Choose a valid report date range.');
  }
  const all = input.scope === 'all';
  const branchId = all || input.scope === unassigned ? null : requiredIdentifier(input.branchId, 'branchId');
  const root = `orgs/${org}`;
  const ref = branchId ? db.doc(`${root}/branches/${branchId}`) : null;
  const directory = ref
    ? await ref.get().then(snapshot => snapshot.exists ? [{ ...snapshot.data(), id: snapshot.id }] : [])
    : await rows(db.collection(`${root}/branches`));
  if (branchId && directory.length === 0) throw new DomainError('not-found', 'Branch unavailable.');

  const buckets = new Map(directory.map(branch => {
    const data = branch as Record<string, unknown> & { id: string };
    if (typeof data.displayName !== 'string' || !['active', 'inactive'].includes(String(data.status))) {
      throw new DomainError('failed-precondition', 'Branch directory requires review.');
    }
    return [data.id, reportBucket(data.id, data.displayName, String(data.status))];
  }));
  const orphan = reportBucket(unassigned, 'Unassigned records', null, false);
  const combined = reportBucket('all', 'All branches', null);
  const bucketFor = (value: unknown) => typeof value === 'string' ? buckets.get(value) ?? orphan : orphan;
  function forScope(value: unknown, update: (bucket: Bucket) => void) {
    const bucket = bucketFor(value);
    if (!branchId || bucket === buckets.get(branchId)) update(bucket);
    if (all) update(combined);
  }

  const inRange = (value: unknown): value is number => clockNumber(value) && value >= from && value < to;
  const byBranch = (collection: string) => {
    const query = db.collection(`${root}/${collection}`);
    return branchId ? query.where('branchId', '==', branchId) : query;
  };
  const [membership, bookings, payments, workouts, equipment] = await Promise.all([
    rows(db.collection(`${root}/members`)),
    rows(byBranch('bookings')),
    rows(byBranch('transactions')),
    all ? Promise.resolve([]) : rows(byBranch('workoutSessions')),
    ref ? rows(ref.collection('equipmentInventory')) : Promise.resolve([]),
  ]);

  const activeMembers = membership.filter(item => item.role === 'member' && item.status === 'active');
  for (let offset = 0; offset < activeMembers.length; offset += 150) {
    const batch = activeMembers.slice(offset, offset + 150);
    const users = await db.getAll(...batch.map(row => db.doc(`users/${row.id}`)));
    for (const snapshot of users) {
      const user = snapshot.data();
      if (user?.organizationId === org) {
        forScope(user.homeBranchId ?? user.primaryBranchId, bucket => bucket.homeMembers++);
      }
    }
  }
  for (const member of membership) {
    if (member.role !== 'coach' || member.status !== 'active') continue;
    const ids = Array.isArray(member.branchIds) ? new Set(member.branchIds) : new Set();
    const assignments = [...ids].map(bucketFor).filter(bucket => bucket !== orphan);
    if (assignments.length === 0 && !branchId) orphan.assignedCoaches++;
    if (all && assignments.length > 0) combined.assignedCoaches++;
    for (const bucket of assignments) bucket.assignedCoaches++;
  }
  for (const booking of bookings) {
    forScope(booking.branchId, bucket => {
      if (inRange(booking.createdAtMillis)) {
        bucket.bookingsCreated++;
        increment(bucket, booking.createdAtMillis, 'bookings');
      }
      if (!inRange(booking.startAtMillis)) return;
      if (booking.status === 'completed') {
        bucket.completedSessions++;
        increment(bucket, booking.startAtMillis, 'completed');
      }
      if (booking.status === 'cancelled') {
        bucket.cancelledSessions++;
        increment(bucket, booking.startAtMillis, 'cancelled');
      }
    });
  }
  for (const session of workouts) {
    if (session.status === 'accepted' && inRange(session.acceptedAtMillis)) {
      const acceptedAt = session.acceptedAtMillis;
      forScope(session.branchId, bucket => {
        bucket.acceptedWorkouts++;
        increment(bucket, acceptedAt, 'workouts');
      });
    }
  }
  const bills = new Set<string>();
  for (const payment of payments) {
    if (payment.type !== 'CoachingBooking' || payment.paymentStatus !== 'cleared'
      || payment.fulfilmentStatus !== 'confirmed' || ![undefined, 'none', 'rejected'].includes(payment.refundStatus as string | undefined)) continue;
    if (!clockNumber(payment.paymentVerifiedAtMillis)) {
      throw new DomainError('failed-precondition', 'Coaching receipt dates require review.');
    }
    if (!inRange(payment.paymentVerifiedAtMillis) || payment.paymentVerifiedAtMillis > now) continue;
    const { amountMinor, paymentVerifiedAtMillis, billId } = payment;
    if (payment.organizationId !== org || payment.bookingId !== payment.id || payment.schemaVersion !== 1
      || payment.environment !== 'sandbox' || !['xendit', 'billplz'].includes(String(payment.provider))
      || payment.currency !== 'MYR' || !clockNumber(amountMinor) || amountMinor === 0 || typeof billId !== 'string' || !billId) {
      throw new DomainError('failed-precondition', 'Coaching receipts require review.');
    }
    if (bills.has(billId)) throw new DomainError('failed-precondition', 'Coaching receipts contain duplicate provider bills.');
    bills.add(billId);
    forScope(payment.branchId, bucket => {
      bucket.coachingMinor += amountMinor;
      if (!Number.isSafeInteger(bucket.coachingMinor)) {
        throw new DomainError('failed-precondition', 'Coaching receipt totals exceed the supported range.');
      }
      increment(bucket, paymentVerifiedAtMillis, 'coachingMinor', amountMinor);
    });
  }
  async function countVisits(bucket: Bucket) {
    const visits = await rows(db.collection(`${root}/branches/${bucket.branchId}/gymVisits`)
      .where('checkedInAtMillis', '>=', from).where('checkedInAtMillis', '<', to));
    for (const visit of visits) {
      const { memberId, checkedInAtMillis } = visit;
      if (visit.source !== 'branch_qr' || visit.branchId !== bucket.branchId
        || typeof memberId !== 'string' || !memberId || !inRange(checkedInAtMillis)) continue;
      const hour = new Date(checkedInAtMillis + 8 * 3600000).getUTCHours();
      forScope(bucket.branchId, result => {
        result.visitorCounts.set(memberId, (result.visitorCounts.get(memberId) ?? 0) + 1);
        result.hours[hour]++;
        increment(result, checkedInAtMillis, 'visits');
      });
    }
  }
  if (all || branchId) {
    const branches = [...buckets.values()];
    for (let offset = 0; offset < branches.length; offset += 10) {
      await Promise.all(branches.slice(offset, offset + 10).map(countVisits));
    }
  }
  if (all) {
    const orphanHasData = orphan.homeMembers + orphan.assignedCoaches + orphan.bookingsCreated
      + orphan.completedSessions + orphan.cancelledSessions + orphan.coachingMinor > 0;
    return {
      ...summarize(combined), acceptedWorkouts: null, startAtMillis: from, endAtMillis: to,
      activeBranches: [...buckets.values()].filter(bucket => bucket.status === 'active').length,
      branches: [...buckets.values(), ...(orphanHasData ? [orphan] : [])].map(bucket => {
        const { daily, ...summary } = summarize(bucket);
        return summary;
      }),
    };
  }
  const liveStock = equipment.filter(item => item.removed !== true);
  const validStock = liveStock.every(item =>
    clockNumber(item.quantity) && clockNumber(item.maintenance) && item.maintenance <= item.quantity);
  const equipmentUnits = ref && validStock ? liveStock.reduce((total, item) => total + Number(item.quantity), 0) : null;
  const maintenanceUnits = ref && validStock ? liveStock.reduce((total, item) => total + Number(item.maintenance), 0) : null;
  return {
    ...summarize(branchId ? buckets.get(branchId)! : orphan),
    startAtMillis: from, endAtMillis: to, equipmentUnits, maintenanceUnits,
    usableUnits: equipmentUnits != null && maintenanceUnits != null ? equipmentUnits - maintenanceUnits : null,
  };
}
