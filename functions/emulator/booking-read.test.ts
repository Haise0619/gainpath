import { initializeApp, deleteApp, type App } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { beforeAll, beforeEach, afterAll, expect, it } from 'vitest';
import { FirestoreStore } from '../src/platform/firestore/firestore-store';
import { FirestoreBookingQueryReader } from '../src/modules/coaching/booking-query-reader';
import { getBookingListService, type BookingQueryReader } from '../src/modules/coaching/booking-list-service';
import { createBookingHoldService } from '../src/modules/coaching/booking-service';
import { command, now, start, seeds, eligibleCoach } from '../test/booking-fixture';

let app: App, db: Firestore, reader: FirestoreBookingQueryReader, bookingId: string;
const input = { schemaVersion: 1, organizationId: 'org-1' };
const read = (uid = 'member-1', changes = {}, source: BookingQueryReader = reader) => getBookingListService(new FirestoreStore(db), { uid, token: { email_verified: true } }, { ...input, ...changes }, source, () => now);
beforeAll(() => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Firestore emulator required; never target a live project.');
  app = initializeApp({ projectId: 'demo-gainpath' }, 'booking-read'); db = getFirestore(app); reader = new FirestoreBookingQueryReader(db);
});
afterAll(async () => { await db?.terminate(); if (app) await deleteApp(app); });
beforeEach(async () => {
  await db.recursiveDelete(db.collection('orgs')); await db.recursiveDelete(db.collection('users'));
  const batch = db.batch(); Object.entries(seeds).forEach(([p, d]) => batch.set(db.doc(p), d));
  batch.set(db.doc('users/admin-1'), { organizationId: 'org-1' });
  batch.set(db.doc('orgs/org-1/members/admin-1'), { organizationId: 'org-1', role: 'admin', status: 'active', branchIds: [] });
  await batch.commit();
  bookingId = (await createBookingHoldService(new FirestoreStore(db), 'member-1', command, eligibleCoach, () => now)).bookingId;
});
async function snapshot() {
  return Promise.all(['bookings', 'slotLocks', 'bookingDays', 'commandReceipts', 'jobs'].map(async name =>
    (await db.collection(`orgs/org-1/${name}`).get()).docs.map(d => ({ path: d.ref.path, data: d.data() }))));
}
it('reads the writer’s same persisted ID for Member/Coach/Admin through real SDK queries, without protected writes', async () => {
  const before = await snapshot();
  const pages = await Promise.all([read(), read('coach-1'), read('admin-1', { coachId: 'coach-1' })]);
  expect(pages.map(p => p.records[0].bookingId)).toEqual([bookingId, bookingId, bookingId]);
  expect(pages[0].records[0]).not.toHaveProperty('createdBy');
  expect(await snapshot()).toEqual(before);
});
it('keeps branchless Member and unpublished Coach reads but excludes reassigned/inactive Coach branches', async () => {
  await db.doc('orgs/org-1/members/member-1').update({ branchIds: [] });
  await db.doc('orgs/org-1/coaches/coach-1').update({ status: 'inactive' });
  expect((await read()).records[0].bookingId).toBe(bookingId); expect((await read('coach-1')).records[0].bookingId).toBe(bookingId);
  await db.doc('orgs/org-1/branches/branch-1').update({ status: 'inactive' });
  expect((await read('coach-1')).records).toEqual([]);
  expect((await read('admin-1', { coachId: 'coach-1' })).records[0].bookingId).toBe(bookingId);
});
it('denies stale organization/Staff and discards a real query after Coach assignment changes', async () => {
  await expect(read('staff-1', { coachId: 'coach-1' })).rejects.toMatchObject({ code: 'permission-denied' });
  await db.doc('users/member-1').update({ organizationId: 'elsewhere' });
  await expect(read()).rejects.toMatchObject({ code: 'permission-denied' });
  await expect(read('coach-1', {}, { read: async q => { const rows = await reader.read(q); await db.doc('orgs/org-1/members/coach-1').update({ branchIds: [] }); return rows; } })).rejects.toMatchObject({ code: 'permission-denied' });
});
it('uses exact member/Coach/admin queries and SDK startAfter document-ID ties for 20+1 pages', async () => {
  const original = (await db.doc(`orgs/org-1/bookings/${bookingId}`).get()).data()!;
  await db.doc(`orgs/org-1/bookings/${bookingId}`).delete();
  const batch = db.batch();
  for (let i = 0; i < 22; i++) { const id = `b-${String(i).padStart(2, '0')}`; batch.set(db.doc(`orgs/org-1/bookings/${id}`), { ...original, bookingId: id }); }
  batch.set(db.doc('orgs/org-1/bookings/outside-branch'), { ...original, bookingId: 'outside-branch', branchId: 'branch-2', startAtMillis: start + 1800000, endAtMillis: start + 5400000 });
  batch.set(db.doc('orgs/org-1/bookings/other-member'), { ...original, bookingId: 'other-member', memberId: 'other-member', coachId: 'other-coach' });
  await batch.commit();
  for (const [uid, changes] of [['member-1', {}], ['coach-1', {}], ['admin-1', { coachId: 'coach-1' }]] as const) {
    const first = await read(uid, changes); expect(first.records).toHaveLength(20); expect(first.nextCursor).toEqual({ startAtMillis: start, bookingId: 'b-19' });
    const last = await read(uid, { ...changes, cursor: first.nextCursor });
    expect(last.records.map(r => r.bookingId)).toEqual(uid === 'coach-1' ? ['b-20', 'b-21'] : ['b-20', 'b-21', 'outside-branch']);
    expect(last.nextCursor).toBeUndefined();
  }
});
it('fails closed for malformed persisted data and invalid cursor without protected mutations', async () => {
  await db.doc(`orgs/org-1/bookings/${bookingId}`).update({ status: 'expired' });
  const before = await snapshot(); await expect(read()).rejects.toMatchObject({ code: 'failed-precondition' });
  await expect(read('member-1', { cursor: { startAtMillis: start + 1, bookingId } })).rejects.toThrow(); expect(await snapshot()).toEqual(before);
});
