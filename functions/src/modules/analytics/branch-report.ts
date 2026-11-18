import type { Firestore, Query } from 'firebase-admin/firestore';
import { DomainError } from '../../platform/errors';
import { requiredIdentifier } from '../../platform/validation';

const cap = 1500;
const clockNumber = (v: unknown): v is number => typeof v === 'number' && Number.isSafeInteger(v) && v >= 0;

export async function readBranchReport(db: Firestore, org: string, input: Record<string, unknown>) {
  const from = input.startAtMillis, to = input.endAtMillis;
  if (!clockNumber(from) || !clockNumber(to) || from >= to || to > Date.now() + 86400000) {
    throw new DomainError('invalid-argument', 'Choose a valid report date range.');
  }
  const branchId = input.scope === 'unassigned' ? null : requiredIdentifier(input.branchId, 'branchId');
  const root = `orgs/${org}`;
  const ref = branchId ? db.doc(`${root}/branches/${branchId}`) : null;
  const branch = ref ? (await ref.get()).data() : undefined;
  if (branchId && !branch) throw new DomainError('not-found', 'Branch unavailable.');
  const inRange = (value: unknown) => clockNumber(value) && value >= from && value < to;
  const matches = (value: unknown) => branchId ? value === branchId : value == null || value === '';
  async function rows(query: Query) {
    const result = await query.limit(cap + 1).get();
    if (result.size > cap) throw new DomainError('resource-exhausted', 'This branch report exceeds the available record limit.');
    return result.docs.map(doc => ({ ...doc.data(), id: doc.id } as Record<string, unknown>));
  }
  const byBranch = (collection: string) => {
    const query = db.collection(`${root}/${collection}`);
    return branchId ? query.where('branchId', '==', branchId) : query;
  };
  const [memberRows, bookings, payments, workouts, equipment, visits] = await Promise.all([
    rows(db.collection(`${root}/members`)),
    rows(byBranch('bookings')),
    rows(byBranch('transactions')),
    rows(byBranch('workoutSessions')),
    ref ? rows(ref.collection('equipmentInventory')) : Promise.resolve([]),
    ref ? rows(ref.collection('gymVisits').where('checkedInAtMillis', '>=', from).where('checkedInAtMillis', '<', to)) : Promise.resolve([]),
  ]);
  const activeMembers = memberRows.filter(item => item.role === 'member' && item.status === 'active');
  let homeMembers = 0;
  for (let offset = 0; offset < activeMembers.length; offset += 150) {
    const batch = activeMembers.slice(offset, offset + 150);
    const users = await db.getAll(...batch.map(row => db.doc(`users/${row.id}`)));
    for (const snapshot of users) {
      const user = snapshot.data();
      if (user?.organizationId === org && matches(user.homeBranchId ?? user.primaryBranchId)) homeMembers++;
    }
  }
  const assignedCoaches = memberRows.filter(item => item.role === 'coach' && item.status === 'active'
    && (branchId ? Array.isArray(item.branchIds) && item.branchIds.includes(branchId)
      : !Array.isArray(item.branchIds) || item.branchIds.length === 0)).length;
  const booked = bookings.filter(item => matches(item.branchId) && inRange(item.createdAtMillis));
  const cleared = payments.filter(item => item.type === 'CoachingBooking' && matches(item.branchId)
    && item.paymentStatus === 'cleared' && item.fulfilmentStatus === 'confirmed'
    && [undefined, 'none', 'rejected'].includes(item.refundStatus as string | undefined)
    && inRange(item.paymentVerifiedAtMillis));
  const visitorCounts = new Map<string, number>();
  const hourCounts = Array<number>(24).fill(0);
  for (const item of visits) {
    if (typeof item.memberId !== 'string' || !inRange(item.checkedInAtMillis)) continue;
    visitorCounts.set(item.memberId, (visitorCounts.get(item.memberId) ?? 0) + 1);
    hourCounts[new Date(Number(item.checkedInAtMillis) + 8 * 3600000).getUTCHours()]++;
  }
  const liveStock = equipment.filter(item => item.removed !== true);
  return {
    branchId: branchId ?? 'unassigned',
    branchName: branchId ? branch!.displayName ?? branchId : 'Unassigned records',
    startAtMillis: from, endAtMillis: to,
    homeMembers, assignedCoaches,
    equipmentUnits: liveStock.reduce((sum, item) => sum + (clockNumber(item.quantity) ? item.quantity : 0), 0),
    maintenanceUnits: liveStock.reduce((sum, item) => sum + (clockNumber(item.maintenance) ? item.maintenance : 0), 0),
    bookingsCreated: booked.length,
    coachingMinor: cleared.reduce((sum, item) => sum + (clockNumber(item.amountMinor) ? item.amountMinor : 0), 0),
    acceptedWorkouts: workouts.filter(item => matches(item.branchId) && item.status === 'accepted' && inRange(item.acceptedAtMillis)).length,
    gymVisits: hourCounts.reduce((sum, count) => sum + count, 0),
    uniqueVisitors: visitorCounts.size,
    repeatVisitors: [...visitorCounts.values()].filter(count => count > 1).length,
    peakHours: hourCounts.some(count => count > 0)
      ? hourCounts.flatMap((count, hour) => count === Math.max(...hourCounts) ? [hour] : [])
      : [],
  };
}
