import { describe, expect, it } from 'vitest';
import { MemoryStore } from './memory-store';
import { getClientPostureHistory } from '../src/modules/coaching/client-posture-service';
import { WORKOUT_CONSENT_VERSION } from '../src/modules/workouts/workout-validation';

describe('client posture history service', () => {
  const org = 'org-1';
  const coachUid = 'coach-1';
  const memberUid = 'member-1';

  function setupStore() {
    const store = new MemoryStore();
    store.documents.set(`orgs/${org}`, { schemaVersion: 1, status: 'active' });
    store.documents.set(`orgs/${org}/branches/branch-1`, { schemaVersion: 1, status: 'active' });
    store.documents.set(`users/${coachUid}`, { schemaVersion: 1, organizationId: org });
    store.documents.set(`orgs/${org}/members/${coachUid}`, {
      schemaVersion: 1,
      organizationId: org,
      role: 'coach',
      status: 'active',
      branchIds: ['branch-1'],
    });
    store.documents.set(`orgs/${org}/bookings/booking-1`, {
      schemaVersion: 1,
      organizationId: org,
      coachId: coachUid,
      memberId: memberUid,
      status: 'confirmed',
    });
    return store;
  }

  const coachAuth = { uid: coachUid, token: { email_verified: true } };

  it('rejects caller without verified email', async () => {
    const store = setupStore();
    await expect(
      getClientPostureHistory(store, { uid: coachUid, token: { email_verified: false } }, {
        schemaVersion: 1,
        organizationId: org,
        memberId: memberUid,
        bookingId: 'booking-1',
      })
    ).rejects.toThrow('Verify the account email before continuing.');
  });

  it('rejects caller who is not an active coach in organization', async () => {
    const store = new MemoryStore();
    store.documents.set(`orgs/${org}`, { schemaVersion: 1, status: 'active' });
    store.documents.set(`users/${coachUid}`, { schemaVersion: 1, organizationId: org });
    store.documents.set(`orgs/${org}/members/${coachUid}`, {
      schemaVersion: 1,
      organizationId: org,
      role: 'member',
      status: 'active',
      branchIds: ['branch-1'],
    });

    await expect(
      getClientPostureHistory(store, coachAuth, {
        schemaVersion: 1,
        organizationId: org,
        memberId: memberUid,
        bookingId: 'booking-1',
      })
    ).rejects.toThrow('Only coaches may query client posture history.');
  });

  it('returns unauthorized_relationship when bookingId is missing or unverified', async () => {
    const store = setupStore();
    const result = await getClientPostureHistory(store, coachAuth, {
      schemaVersion: 1,
      organizationId: org,
      memberId: memberUid,
    });

    expect(result.authorized).toBe(false);
    expect(result.sharingStatus).toBe('unauthorized_relationship');
    expect(result.sessions).toEqual([]);
  });

  it('returns unauthorized_relationship when booking belongs to a different coach', async () => {
    const store = setupStore();
    store.documents.set(`orgs/${org}/bookings/booking-other`, {
      schemaVersion: 1,
      organizationId: org,
      coachId: 'coach-2',
      memberId: memberUid,
      status: 'confirmed',
    });

    const result = await getClientPostureHistory(store, coachAuth, {
      schemaVersion: 1,
      organizationId: org,
      memberId: memberUid,
      bookingId: 'booking-other',
    });

    expect(result.authorized).toBe(false);
    expect(result.sharingStatus).toBe('unauthorized_relationship');
    expect(result.sessions).toEqual([]);
  });

  it('returns consent_not_granted when relationship is verified but member has no consent record', async () => {
    const store = setupStore();
    const result = await getClientPostureHistory(store, coachAuth, {
      schemaVersion: 1,
      organizationId: org,
      memberId: memberUid,
      bookingId: 'booking-1',
    });

    expect(result.authorized).toBe(false);
    expect(result.sharingStatus).toBe('consent_not_granted');
    expect(result.sessions).toEqual([]);
  });

  it('returns consent_revoked when member consent was revoked', async () => {
    const store = setupStore();
    store.documents.set(`orgs/${org}/workoutConsents/${memberUid}`, {
      schemaVersion: 1,
      organizationId: org,
      memberId: memberUid,
      consentVersion: WORKOUT_CONSENT_VERSION,
      acknowledgementId: 'ack-1',
      acknowledgedAtMillis: 1000,
      revokedAtMillis: 2000,
    });

    const result = await getClientPostureHistory(store, coachAuth, {
      schemaVersion: 1,
      organizationId: org,
      memberId: memberUid,
      bookingId: 'booking-1',
    });

    expect(result.authorized).toBe(false);
    expect(result.sharingStatus).toBe('consent_revoked');
    expect(result.sessions).toEqual([]);
  });

  it('returns granted with measurements_pending_validation when active consent exists', async () => {
    const store = setupStore();
    store.documents.set(`orgs/${org}/workoutConsents/${memberUid}`, {
      schemaVersion: 1,
      organizationId: org,
      memberId: memberUid,
      consentVersion: WORKOUT_CONSENT_VERSION,
      acknowledgementId: 'ack-1',
      acknowledgedAtMillis: 1000,
      revokedAtMillis: null,
    });

    const result = await getClientPostureHistory(store, coachAuth, {
      schemaVersion: 1,
      organizationId: org,
      memberId: memberUid,
      bookingId: 'booking-1',
    });

    expect(result.authorized).toBe(true);
    expect(result.sharingStatus).toBe('granted');
    expect(result.measurementsStatus).toBe('measurements_pending_validation');
    expect(result.sessions).toEqual([]);
  });
});
