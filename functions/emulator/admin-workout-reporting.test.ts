import {initializeApp, deleteApp, type App} from 'firebase-admin/app';
import {getFirestore, FieldPath, type Firestore} from 'firebase-admin/firestore';
import {beforeAll, afterAll, beforeEach, it, expect} from 'vitest';
import {FirestoreStore} from '../src/platform/firestore/firestore-store';
import {adminWorkoutReport, type WorkoutReportReader} from '../src/modules/analytics/admin-workout-reporting';
import {digestOf} from '../src/modules/workouts/workout-backup-validation';
import {payload} from '../test/workout-backup-fixture';
let app: App, db: Firestore;
const project = 'demo-gainpath-workout-reporting', now = Date.UTC(2026, 9, 26, 6), actor = {uid: 'admin', token: {email_verified: true, auth_time: 100}};
const query = {schemaVersion: 1, organizationId: 'gainpath', startAtMillis: Date.UTC(2026, 9, 24, 16), endAtMillis: Date.UTC(2026, 9, 25, 16)};
beforeAll(() => {if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:18088') throw Error('Dedicated loopback emulator required'); app = initializeApp({projectId: project}, 'workout-reporting'); db = getFirestore(app);});
afterAll(async () => {await db?.terminate(); if (app) await deleteApp(app);});
beforeEach(async () => {
  await fetch(`http://127.0.0.1:18088/emulator/v1/projects/${project}/databases/(default)/documents`, {method: 'DELETE'});
  const b = db.batch(); b.set(db.doc('users/admin'), {organizationId: 'gainpath'}); b.set(db.doc('orgs/gainpath'), {status: 'active'});
  b.set(db.doc('orgs/gainpath/members/admin'), {organizationId: 'gainpath', role: 'admin', status: 'active', branchIds: []});
  b.set(db.doc('orgs/gainpath/members/member'), {organizationId: 'gainpath', role: 'member', status: 'active'});
  b.set(db.doc('users/member'), {organizationId: 'gainpath', role: 'member'}); await b.commit();
});
const page = async (path: string, after: string | undefined, limit: number) => {
  let q = db.collection(path).orderBy(FieldPath.documentId()).limit(limit); if (after) q = q.startAfter(after);
  return (await q.get()).docs.map(d => ({id: d.id, data: d.data()}));
};
const reader: WorkoutReportReader = {members: (after, limit) => page('orgs/gainpath/members', after, limit),
  backups: (uid, after, limit) => page(`orgs/gainpath/members/${uid}/workoutBackups`, after, limit)};
async function seed(id: string) {
  const p = {...payload, sessionId: id}, key = 'session-' + id, ref = db.doc('orgs/gainpath/members/member/workoutBackups/' + key);
  await ref.set({schemaVersion: 1, kind: 'session', id, key, classification: 'provisional_member_backup', payloadJson: JSON.stringify(p), digest: digestOf(p), updatedAtMillis: now});
  return ref;
}
it('reads all latest backups across real pages, ignores revision subcollections and performs no writes', async () => {
  for (let i = 0; i < 26; i++) await seed('s' + String(i).padStart(2, '0'));
  const ref = db.doc('orgs/gainpath/members/member/workoutBackups/session-s00');
  await ref.collection('revisions').doc('old').set({malformed: true});
  const before = await ref.get();
  const r = await adminWorkoutReport(new FirestoreStore(db), actor, query, reader, () => now);
  expect(r.totals.sessions).toBe(26); expect(r.totals.fullReps).toBe(52); expect(r.coverage.backupRecords).toBe(26);
  expect((await ref.get()).updateTime?.isEqual(before.updateTime!)).toBe(true);
  expect((await db.collection('orgs/gainpath/analytics').get()).empty).toBe(true);
});
it('canonical Admin scope drift during actual backup reads denies the result', async () => {
  await seed('s1');
  await expect(adminWorkoutReport(new FirestoreStore(db), actor, query, {...reader, backups: async (uid, after, limit) => {
    const rows = await reader.backups(uid, after, limit); await db.doc('users/admin').update({organizationId: 'other'}); return rows;
  }}, () => now)).rejects.toMatchObject({code: 'permission-denied'});
});
it('a corrupt latest backup prevents partial aggregate output', async () => {
  await seed('s1'); const bad = await seed('s2'); await bad.update({digest: 'invalid'});
  await expect(adminWorkoutReport(new FirestoreStore(db), actor, query, reader, () => now)).rejects.toMatchObject({code: 'failed-precondition'});
});
