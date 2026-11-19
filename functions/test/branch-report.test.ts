import type { Firestore } from 'firebase-admin/firestore';
import { describe, expect, it } from 'vitest';
import { readBranchReport } from '../src/modules/analytics/branch-report';

const root = 'orgs/gainpath';
const startAtMillis = Date.parse('2025-03-01T16:00:00Z');
const endAtMillis = Date.parse('2025-03-03T16:00:00Z');
const instant = startAtMillis + 1;

function firestore(documents: Record<string, Record<string, unknown>>) {
  type Condition = [string, '==' | '>=' | '<', string | number];
  const reads: string[] = [];
  const doc = (path: string) => ({
    id: path.split('/').at(-1)!,
    exists: documents[path] !== undefined,
    data: () => documents[path],
    get: async () => doc(path),
    collection: (name: string) => query(path + '/' + name),
  });
  const query = (path: string, conditions: Condition[] = [], cap = Infinity) => ({
    where: (...condition: Condition) => query(path, [...conditions, condition], cap),
    limit: (limit: number) => query(path, conditions, limit),
    get: async () => {
      reads.push(path);
      const docs = Object.entries(documents).filter(([key, value]) =>
        key.startsWith(path + '/') && !key.slice(path.length + 1).includes('/') &&
        conditions.every(([field, op, target]) => {
          if (op === '==') return value[field] === target;
          const item = value[field];
          if (typeof item !== 'number' || typeof target !== 'number') return false;
          return op === '>=' ? item >= target : item < target;
        })).map(([key]) => doc(key)).slice(0, cap);
      return { docs, size: docs.length };
    },
  });
  const db = { doc, collection: query, getAll: async (...refs: ReturnType<typeof doc>[]) => refs };
  return { db: db as unknown as Firestore, reads };
}

function receipt(id: string, fields: Record<string, unknown> = {}) {
  return {
    organizationId: 'gainpath', bookingId: id, schemaVersion: 1, environment: 'sandbox',
    provider: 'xendit', currency: 'MYR', type: 'CoachingBooking', paymentStatus: 'cleared',
    fulfilmentStatus: 'confirmed', amountMinor: 10000, billId: 'ps-' + id,
    paymentVerifiedAtMillis: instant, ...fields,
  };
}

describe('branch analytics', () => {
  it('reads each organizational collection once and deduplicates cross-branch visitors and assignments', async () => {
    const { db, reads } = firestore({
      [root + '/branches/main']: { displayName: 'HQ', status: 'active' },
      [root + '/branches/second']: { displayName: 'Former studio', status: 'inactive' },
      [root + '/members/m1']: { role: 'member', status: 'active' },
      [root + '/members/m2']: { role: 'member', status: 'active' },
      [root + '/members/coach']: { role: 'coach', status: 'active', branchIds: ['main', 'second'] },
      'users/m1': { organizationId: 'gainpath', primaryBranchId: 'second', selectedBranchId: 'main' },
      'users/m2': { organizationId: 'gainpath' },
      [root + '/bookings/b1']: { branchId: 'second', status: 'completed', createdAtMillis: instant, startAtMillis: instant },
      [root + '/bookings/legacy']: { status: 'cancelled', createdAtMillis: instant, startAtMillis: instant },
      [root + '/transactions/b1']: receipt('b1', { branchId: 'second' }),
      [root + '/transactions/pending']: receipt('pending', { branchId: 'main', billId: undefined, paymentStatus: 'pending', fulfilmentStatus: 'reconciliation_required' }),
      [root + '/transactions/review']: receipt('review', { branchId: 'main', fulfilmentStatus: 'reconciliation_required' }),
      [root + '/branches/main/gymVisits/v1']: { branchId: 'main', memberId: 'm1', source: 'branch_qr', checkedInAtMillis: instant },
      [root + '/branches/second/gymVisits/v2']: { branchId: 'second', memberId: 'm1', source: 'branch_qr', checkedInAtMillis: instant },
      [root + '/branches/second/gymVisits/v3']: { branchId: 'second', memberId: 'm2', source: 'branch_qr', checkedInAtMillis: endAtMillis },
      [root + '/branches/second/gymVisits/daily']: { branchId: 'second', memberId: 'm2', source: 'daily', checkedInAtMillis: instant },
    });

    const report = await readBranchReport(db, 'gainpath', { scope: 'all', startAtMillis, endAtMillis });
    expect(report).toMatchObject({
      activeBranches: 1, homeMembers: 2, assignedCoaches: 1, gymVisits: 2, uniqueVisitors: 1,
      bookingsCreated: 2, completedSessions: 1, cancelledSessions: 1, coachingMinor: 10000, actualCoachingMinor: null,
      branches: [
        { branchId: 'main', coachingMinor: 0, assignedCoaches: 1, gymVisits: 1 },
        { branchId: 'second', status: 'inactive', homeMembers: 1, assignedCoaches: 1, coachingMinor: 10000, gymVisits: 1 },
        { branchId: 'unassigned', homeMembers: 1, bookingsCreated: 1, gymVisits: null },
      ],
    });
    for (const collection of ['members', 'bookings', 'transactions']) {
      expect(reads.filter(p => p === root + '/' + collection)).toHaveLength(1);
    }
  });

  it('preserves MYT activity buckets and treats inventory as a current snapshot', async () => {
    const { db } = firestore({
      [root + '/branches/main']: { displayName: 'HQ', status: 'active' },
      [root + '/branches/main/equipmentInventory/stock']: { quantity: 5, maintenance: 1, updatedAtMillis: endAtMillis + 1 },
      [root + '/branches/main/equipmentInventory/removed']: { removed: true, quantity: 8, maintenance: 0 },
      [root + '/bookings/b1']: { branchId: 'main', status: 'confirmed', createdAtMillis: instant },
      [root + '/transactions/b1']: receipt('b1', { branchId: 'main' }),
    });
    const report = await readBranchReport(db, 'gainpath', { branchId: 'main', startAtMillis, endAtMillis });
    expect(report).toMatchObject({ equipmentUnits: 5, maintenanceUnits: 1, usableUnits: 4,
      daily: [{ date: '2025-03-02', bookings: 1, completed: 0, cancelled: 0, coachingMinor: 10000, visits: 0 }] });
  });
});
