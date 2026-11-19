import { deleteApp, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { expect, it } from 'vitest';
import { readBranchReport } from '../src/modules/analytics/branch-report';

it('reads only branch QR visits and matches the real Firestore comparison with specific daily results', async () => {
  if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:18088') {
    throw new Error('Dedicated loopback emulator required.');
  }
  const app = initializeApp({ projectId: 'demo-gainpath-reporting' }, 'branch-analytics');
  const db = getFirestore(app);
  try {
    const org = 'branch-emulator';
    const root = `orgs/${org}`;
    const startAtMillis = Date.parse('2025-03-01T16:00:00Z');
    const endAtMillis = Date.parse('2025-03-02T16:00:00Z');
    const checkedInAtMillis = startAtMillis + 1;
    const batch = db.batch();
    batch.set(db.doc(`${root}/branches/east`), { displayName: 'East', status: 'active' });
    batch.set(db.doc(`${root}/branches/west`), { displayName: 'West', status: 'inactive' });
    batch.set(db.doc(`${root}/members/coach`), { role: 'coach', status: 'active', branchIds: ['east', 'west'] });
    const visit = { branchId: 'west', memberId: 'member', source: 'branch_qr', checkedInAtMillis };
    batch.set(db.doc(`${root}/branches/east/gymVisits/v1`), { ...visit, branchId: 'east' });
    batch.set(db.doc(`${root}/branches/west/gymVisits/v2`), visit);
    batch.set(db.doc(`${root}/members/member/gymVisits/v2`), visit);
    batch.set(db.doc(`${root}/branches/west/gymVisits/outside`), { ...visit, checkedInAtMillis: endAtMillis });
    batch.set(db.doc(`${root}/branches/west/equipmentInventory/equipment`), { quantity: 4, maintenance: 1 });
    batch.set(db.doc(`${root}/transactions/review`), { branchId: 'west', type: 'CoachingBooking',
      paymentStatus: 'pending', fulfilmentStatus: 'reconciliation_required' });
    await batch.commit();
    const all = await readBranchReport(db, org, { scope: 'all', startAtMillis, endAtMillis });
    const specific = await readBranchReport(db, org, { branchId: 'west', startAtMillis, endAtMillis });
    expect(all).toMatchObject({ activeBranches: 1, assignedCoaches: 1, gymVisits: 2, uniqueVisitors: 1 });
    expect(specific).toMatchObject({ status: 'inactive', gymVisits: 1, uniqueVisitors: 1,
      usableUnits: 3, coachingMinor: 0, daily: [{ date: '2025-03-02', visits: 1 }] });
  } finally {
    await db.terminate();
    await deleteApp(app);
  }
});
