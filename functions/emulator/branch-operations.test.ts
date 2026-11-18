import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { expect, it } from 'vitest';
import { FirestoreStore } from '../src/platform/firestore/firestore-store';
import { branchOperations } from '../src/modules/identity/branch-operations';
import { now, seeds } from '../test/booking-fixture';

it('deduplicates concurrent physical visit calls with real Firestore transactions', async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Firestore Emulator is required.');
  const app = initializeApp({ projectId: 'demo-gainpath' }, 'branch-visits');
  const db = getFirestore(app);
  try {
    const batch = db.batch();
    for (const [path, data] of Object.entries(seeds)) batch.set(db.doc(path), data);
    batch.set(db.doc('users/branch-admin'), { organizationId: 'org-1' });
    batch.set(db.doc('orgs/org-1/members/branch-admin'), {
      organizationId: 'org-1', status: 'active', role: 'admin', branchIds: [],
    });
    batch.set(db.doc('orgs/org-1/branches/visit-fixture'), { displayName: 'Visit fixture', status: 'active' });
    await batch.commit();
    const store = new FirestoreStore(db);
    const invoke = (uid: string, action: string, input: object = {}) => branchOperations(store, async path => {
      const snapshot = await db.collection(path).limit(31).get();
      return snapshot.docs.map(doc => ({ id: doc.id, data: doc.data() }));
    }, { uid, token: { email_verified: true, auth_time: Math.floor(now / 1000) } },
    { organizationId: 'org-1', branchId: 'visit-fixture', action, ...input }, () => now);
    const { qr } = await invoke('branch-admin', 'issueVisitCode') as { qr: string };
    const token = qr.split(':')[2];
    const results = await Promise.all([invoke('member-1', 'checkIn', { token }), invoke('member-1', 'checkIn', { token })]);
    expect(results.filter(result => 'duplicate' in result && !result.duplicate)).toHaveLength(1);
    const snapshot = await db.collection('orgs/org-1/branches/visit-fixture/gymVisits').get();
    expect(snapshot.docs).toHaveLength(1);
    expect(await invoke('member-1', 'myVisits')).toMatchObject({ records: [{ branchId: 'visit-fixture' }] });
  } finally {
    await db.terminate();
    await deleteApp(app);
  }
});
