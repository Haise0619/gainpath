import { randomUUID } from 'node:crypto';
import { deleteApp, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { expect, it } from 'vitest';
import { groupClasses } from '../src/modules/group-classes/group-classes';
import { firestoreGroupClassStore } from '../src/modules/group-classes/group-classes-callable';
import { keyOf } from '../src/platform/idempotency';
import { createBookingHoldService } from '../src/modules/coaching/booking-service';
import { FirestoreStore } from '../src/platform/firestore/firestore-store';
import { eligibleCoach, now, start, seeds, paidMemberFixture } from './booking-fixture';

it.runIf(process.env.FIRESTORE_EMULATOR_HOST === '127.0.0.1:8189')(
  'runs publication, concurrent signup, cancellation, notices, attendance and calendar against Firestore',
  async () => {
    const org = 'group-test-' + randomUUID();
    const app = initializeApp({ projectId: 'demo-gainpath-classes' }, org);
    const db = getFirestore(app);
    try {
      const root = 'orgs/' + org;
      const batch = db.batch();
      for (const [path, data] of Object.entries(seeds)) {
        batch.set(db.doc(path.replace('orgs/org-1', root)), {
          ...data, ...('organizationId' in data ? { organizationId: org } : {}),
        });
      }
      batch.set(db.doc(root + '/branches/branch-1'), { status: 'active', displayName: 'Main Studio' });
      batch.set(db.doc(root + '/branches/branch-2'), { status: 'active', displayName: 'West Studio' });
      batch.set(db.doc(root + '/coaches/coach-1'), { status: 'published', displayName: 'Coach Fox', branchIds: ['branch-1'] });
      for (const [uid, role] of [['admin', 'admin'], ['member-2', 'member'], ['free-member', 'member']]) {
        batch.set(db.doc('users/' + uid), { organizationId: org });
        batch.set(db.doc(root + '/members/' + uid), {
          organizationId: org, status: 'active', role, displayName: uid, branchIds: ['branch-2'],
        });
      }
      for (const [path, data] of Object.entries(paidMemberFixture(root, org, 'member-2', now))) {
        batch.set(db.doc(path), data);
      }
      await batch.commit();
      let time = now;
      const call = (uid: string, action: string, id: string, extra = {}) =>
        groupClasses(firestoreGroupClassStore(db), { uid, token: { email_verified: true } }, {
          schemaVersion: 1, organizationId: org, action, id, requestId: randomUUID(), ...extra,
        }, () => time);
      const item = {
        title: 'Strength Lab', description: 'Fixture class', category: 'Strength',
        branchId: 'branch-1', venue: 'Studio A', coachId: 'coach-1', difficulty: 'All levels',
        eligibility: 'All Members', capacity: 1, startAtMillis: start,
        endAtMillis: start + 3600000, openAtMillis: now - 1000, closeAtMillis: start,
      };
      await call('admin', 'save', 'a', { item });
      expect(await call('member-2', 'list', 'a')).toMatchObject({ classes: [] });
      const lock = db.doc(root + '/slotLocks/' + keyOf('coach-1', start));
      await lock.set({ schemaVersion: 1, status: 'confirmed', bookingId: 'personal-1', coachId: 'coach-1', branchId: 'branch-1' });
      await expect(call('admin', 'publish', 'a')).rejects.toMatchObject({
        code: 'failed-precondition', message: 'The selected coach already has a reservation during this class.',
      });
      await lock.delete();
      await call('admin', 'save', 'outside-availability', {
        item: { ...item, startAtMillis: start + 4 * 3600000, endAtMillis: start + 5 * 3600000 },
      });
      await expect(call('admin', 'publish', 'outside-availability')).rejects.toMatchObject({
        code: 'failed-precondition', message: 'The coach has no availability at this branch for the full class time.',
      });
      expect((await db.doc(root + '/groupClasses/outside-availability').get()).get('state')).toBe('Draft');
      await call('admin', 'publish', 'a');
      expect(await call('free-member', 'detail', 'a')).toMatchObject({
        item: { eligibility: 'Paid Members', eligible: false },
      });
      await expect(call('free-member', 'join', 'a')).rejects.toMatchObject({ code: 'failed-precondition' });
      await db.doc(root + '/groupClasses/a').update({ eligibility: 'All Members' });
      expect(await call('free-member', 'detail', 'a')).toMatchObject({
        item: { eligibility: 'Paid Members', eligible: false },
      });
      await expect(call('free-member', 'join', 'a')).rejects.toMatchObject({ code: 'failed-precondition' });
      expect(await call('member-1', 'detail', 'a')).toMatchObject({ item: { eligible: true } });
      expect((await lock.get()).get('bookingId')).toBe('class-a');
      await expect(createBookingHoldService(new FirestoreStore(db), 'member-1', {
        schemaVersion: 1, requestId: 'original-hold', organizationId: org,
        branchId: 'branch-1', coachId: 'coach-1', memberId: 'member-1',
        startAtMillis: start, durationMinutes: 60,
      }, eligibleCoach, () => now)).rejects.toMatchObject({ code: expect.stringMatching(/failed-precondition|already-exists|aborted/) });
      expect(await call('member-2', 'list', 'a')).toMatchObject({
        classes: [{ id: 'a', branchName: 'Main Studio', status: 'Open' }],
      });
      const results = await Promise.allSettled([call('member-1', 'join', 'a'), call('member-2', 'join', 'a')]);
      expect(results.filter(r => r.status === 'fulfilled')).toHaveLength(1);
      const winner = results[0].status === 'fulfilled' ? 'member-1' : 'member-2';
      const loser = winner === 'member-1' ? 'member-2' : 'member-1';
      await expect(call(winner, 'join', 'a')).rejects.toMatchObject({ code: 'failed-precondition' });
      expect(await call(winner, 'list', 'a')).toMatchObject({ classes: [{ id: 'a', registration: 'Registered', status: 'Full' }] });
      await call('admin', 'save', 'overlap', { item: { ...item, coachId: null, instructor: 'Guest' } });
      await call('admin', 'publish', 'overlap');
      await expect(call(winner, 'join', 'overlap')).rejects.toMatchObject({ code: 'failed-precondition' });
      await call('admin', 'save', 'premium', { item: { ...item, coachId: null, instructor: 'Guest', eligibility: 'Premium Only' } });
      await call('admin', 'publish', 'premium');
      await expect(call(loser, 'join', 'premium')).rejects.toMatchObject({ code: 'failed-precondition' });
      await call(winner, 'leave', 'a');
      await call(loser, 'join', 'a');
      expect(await call('admin', 'calendar', 'a', {
        branchId: 'branch-1', startAtMillis: start - 60000, endAtMillis: start + 7200000,
      })).toMatchObject({ classes: expect.arrayContaining([expect.objectContaining({ id: 'a', activeCount: 1 })]) });
      await expect(call('admin', 'save', 'a', { item: { ...item, venue: 'Studio B' } }))
        .rejects.toMatchObject({ code: 'failed-precondition' });
      await call('admin', 'save', 'a', { item: { ...item, venue: 'Studio B' }, confirmChanges: true });
      const notices = await db.collection(root + '/notifications').where('recipientId', '==', loser).get();
      expect(notices.docs.map(doc => doc.get('title'))).toContain('Group class updated');
      time = start + 3600000;
      await call('admin', 'attendance', 'a', { memberId: loser, status: 'Attended' });
      expect(await call('admin', 'analytics', 'a')).toMatchObject({
        classes: expect.arrayContaining([expect.objectContaining({ id: 'a', status: 'Completed',
          attendedCount: 1, absentCount: 0, totalRegistrations: 2, cancellationCount: 1 })]),
      });
      expect(await call('admin', 'detail', 'a')).toMatchObject({
        participants: expect.arrayContaining([expect.objectContaining({ memberId: winner, status: 'Cancelled' })]),
      });
    } finally {
      await deleteApp(app);
    }
  }, 45000);
