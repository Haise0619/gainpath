import { deleteApp, initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { expect, it } from 'vitest';
import { readBranchReport } from '../src/modules/analytics/branch-report';
import { readOperationsCalendar } from '../src/modules/analytics/operations-calendar';
import { command as bookingFixture } from '../test/booking-fixture';

it('projects real indexed Firestore records and reconciles Malaysia Time metric buckets with Branch Reports', async () => {
  if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:18080') {
    throw new Error('Dedicated loopback emulator required.');
  }
  const app = initializeApp({ projectId: 'demo-gainpath' }, 'operations-calendar');
  const db = getFirestore(app);
  const command = { ...bookingFixture, organizationId: 'calendar-emulator', coachId: 'calendar-coach', memberId: 'calendar-member' };
  const org = command.organizationId, root = `orgs/${org}`;
  const actor = { uid: 'calendar-admin', token: { email_verified: true } };
  const startAtMillis = Date.parse('2026-10-01T16:00:00Z');
  const endAtMillis = Date.parse('2026-10-03T16:00:00Z');
  const from = command.startAtMillis, hour = 3_600_000;
  const instant = startAtMillis + 1;
  const clock = () => from + 2 * hour;
  const input = { organizationId: org, startAtMillis, endAtMillis, branchId: command.branchId };
  try {
    const batch = db.batch();
    batch.set(db.doc(root), { status: 'active' });
    batch.set(db.doc(`${root}/branches/${command.branchId}`), { status: 'active', displayName: 'Fixture gym' });
    batch.set(db.doc(`${root}/coaches/${command.coachId}`), {
      status: 'published', branchIds: [command.branchId], displayName: 'Fixture coach',
    });
    batch.set(db.doc('users/calendar-admin'), { organizationId: org, role: 'admin' });
    batch.set(db.doc(`users/${command.coachId}`), { organizationId: org, role: 'coach' });
    batch.set(db.doc(`${root}/members/${command.coachId}`), {
      organizationId: org, role: 'coach', status: 'active', branchIds: [command.branchId],
    });
    batch.set(db.doc(`${root}/settings/booking`), {
      schemaVersion: 1, policyVersion: 'booking-v1', timeZone: 'Asia/Kuala_Lumpur',
      maxActiveBookingsPerMemberPerDay: 1, holdMinutes: 15,
    });
    batch.set(db.doc(`${root}/coachAvailability/${command.coachId}/days/2026-10-02`), {
      schemaVersion: 1, revision: 1, timeZone: 'Asia/Kuala_Lumpur', policyVersion: 'booking-v1',
      createdAtMillis: instant, updatedAtMillis: instant,
      windows: [{ branchId: command.branchId, startAtMillis: from, endAtMillis: from + 4 * hour }],
    });
    batch.set(db.doc(`${root}/members/calendar-admin`), {
      organizationId: org, role: 'admin', status: 'active', branchIds: [],
    });
    batch.set(db.doc(`${root}/bookings/calendar-session`), {
      ...command, bookingId: 'calendar-session', createdBy: command.memberId, startAtMillis: from,
      endAtMillis: from + hour, status: 'confirmed', createdAtMillis: instant,
      holdExpiresAtMillis: instant + 60_000, localDate: '2026-10-02',
      timeZone: 'Asia/Kuala_Lumpur', policyVersion: 'booking-v1',
    });
    batch.set(db.doc(`${root}/transactions/calendar-session`), {
      type: 'CoachingBooking', branchId: command.branchId, schemaVersion: 1, bookingId: 'calendar-session',
      organizationId: org, paymentStatus: 'cleared', fulfilmentStatus: 'confirmed',
      environment: 'sandbox', currency: 'MYR', provider: 'xendit', amountMinor: 4500,
      billId: 'fixture-verification', paymentVerifiedAtMillis: instant + 1000,
    });
    batch.set(db.doc(`${root}/branches/${command.branchId}/gymVisits/calendar-visit`), {
      branchId: command.branchId, checkedInAtMillis: instant, source: 'branch_qr', memberId: command.memberId,
    });
    batch.set(db.doc(`${root}/announcements/calendar-announcement`), {
      status: 'published', title: 'Fixture notice', body: 'Public details', schemaVersion: 1, revision: 1,
      validFrom: Timestamp.fromMillis(startAtMillis - hour), validTo: Timestamp.fromMillis(startAtMillis + 2 * hour),
    });
    await batch.commit();

    const timeline = await readOperationsCalendar(db, actor, { ...input, action: 'calendarEvents' }, clock);
    expect(timeline).toMatchObject({
      unavailable: [],
      events: [
        { type: 'announcement', sourceId: 'calendar-announcement', status: 'expired', allDay: true },
        { type: 'availability', coachId: command.coachId, title: 'Fixture coach' },
        { type: 'booking', sourceId: 'calendar-session', title: 'Fixture coach', paymentStatus: 'cleared' },
      ],
    });
    const insights = await readOperationsCalendar(db, actor, { ...input, action: 'calendarInsights' }, clock);
    const branch = await readBranchReport(db, org, input);
    expect(insights).toMatchObject({
      unavailable: [],
      daily: [
        { date: '2026-10-02', bookings: branch.bookingsCreated, visits: branch.gymVisits, coachingMinor: branch.coachingMinor },
        { date: '2026-10-03', bookings: null, visits: null, coachingMinor: null },
      ],
    });
    expect(branch).toMatchObject({ bookingsCreated: 1, gymVisits: 1, coachingMinor: 4500 });
  } finally {
    await db.terminate();
    await deleteApp(app);
  }
});
