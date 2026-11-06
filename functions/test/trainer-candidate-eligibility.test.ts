import { expect, it } from 'vitest';
import { evaluateTrainerCandidates } from '../src/modules/recommendation/trainer-candidate-eligibility';
import { trainerFixture, trainerQuery, certificationId, now, start, expertise } from './trainer-candidate.fixture';
import { keyOf } from '../src/platform/idempotency';
import { SLOT } from '../src/modules/coaching/coach-availability-contracts';

it('returns supported experience and only explicitly curated instructional context', async () => {
  const { dependencies } = trainerFixture();
  dependencies.trustedExpertise = [{ ...expertise, teachingFocus: 'Beginner squat stance and controlled depth instruction.' }];
  const c = (await evaluateTrainerCandidates(trainerQuery, dependencies)).candidates[0];
  expect(c.evidence.yearsExperience).toBe(3);
  expect(c.evidence.teachingFocus).toBe('Beginner squat stance and controlled depth instruction.');
  dependencies.trustedExpertise = [{ ...expertise }];
  expect((await evaluateTrainerCandidates(trainerQuery, dependencies)).candidates[0].evidence.teachingFocus).toBeNull();
});

it('returns stable eligible Coach identity and validated facts from real-shaped records without writes or private text', async () => {
  const { store, dependencies } = trainerFixture(), before = structuredClone([...store.documents]);
  const result = await evaluateTrainerCandidates(trainerQuery, dependencies);
  expect(result.candidates).toHaveLength(1);
  expect(result.candidates[0]).toMatchObject({ candidateId: 'coach-1', coachId: 'coach-1', relevance: 'exact_exercise',
    exerciseId: trainerQuery.exerciseId, learningObjective: 'technique_foundations', level: 'beginner',
    evidence: { publishedProfileRevision: 2, approvedCertificationCount: 1, expertiseMappingId: 'squat-foundations', expertiseMappingRevision: 1, bookingPolicyVersion: 'booking-v1' } });
  expect(result.candidates[0].availableOptions).toHaveLength(7);
  expect(result.candidates[0].availableOptions[0]).toEqual({ branchId: 'branch-1', startAtMillis: start, endAtMillis: start + 3600000 });
  expect(result.rejected).toEqual([]);
  expect(JSON.stringify(result)).not.toMatch(/IGNORE|Synthetic|issuer|member-1|storagePath|bio|specializationTags/);
  expect([...store.documents]).toEqual(before);
});

it.each([
  ['users/coach-1', { organizationId: 'foreign' }, 'coach_unavailable'],
  ['orgs/org-1/members/coach-1', { status: 'suspended' }, 'coach_unavailable'],
  ['orgs/org-1/members/coach-1', { role: 'member' }, 'coach_unavailable'],
  ['orgs/org-1/coaches/coach-1', { status: 'inactive' }, 'profile_unavailable'],
  ['orgs/org-1/coaches/coach-1', { schemaVersion: 2 }, 'profile_invalid'],
  ['orgs/org-1/coaches/coach-1', { certificationVerified: false }, 'credentials_unavailable'],
  ['orgs/org-1/branches/branch-1', { status: 'inactive' }, 'no_shared_active_branch'],
  ['orgs/org-1/coachProfiles/coach-1/certificationState/current', { approvedCount: 0, certificationVerified: false }, 'credentials_unavailable'],
  [`orgs/org-1/coachProfiles/coach-1/certifications/${certificationId}`, { status: 'archived' }, 'credentials_invalid'],
  [`orgs/org-1/coachProfiles/coach-1/certifications/${certificationId}`, { coachId: 'foreign' }, 'credentials_invalid'],
  [`orgs/org-1/coachProfiles/coach-1/certifications/${certificationId}`, { updatedAtMillis: now + 1 }, 'credentials_invalid'],
] as const)('rejects current invalid authority/profile/credentials %s %j', async (path, patch, reason) => {
  const { store, dependencies } = trainerFixture();
  Object.assign(store.documents.get(path)!, patch);
  expect(await evaluateTrainerCandidates(trainerQuery, dependencies)).toMatchObject({ candidates: [], rejected: [{ candidateId: 'coach-1', reason }] });
});

it.each([
  { exists: false, disabled: false, emailVerified: true },
  { exists: true, disabled: true, emailVerified: true },
  { exists: true, disabled: false, emailVerified: false },
])('rejects Coach Auth independently of published profile %j', async identity => {
  const { dependencies } = trainerFixture();
  dependencies.readIdentity = async id => id === 'coach-1' ? identity : { exists: true, disabled: false, emailVerified: true };
  expect(await evaluateTrainerCandidates(trainerQuery, dependencies)).toMatchObject({ candidates: [], rejected: [{ reason: 'coach_auth_unavailable' }] });
});

it('sanitizes provider errors and fails closed when current Member identity is unavailable', async () => {
  const { dependencies } = trainerFixture();
  dependencies.readIdentity = async id => { if (id === 'coach-1') throw Error('SECRET provider details'); return { exists: true, disabled: false, emailVerified: true }; };
  expect(await evaluateTrainerCandidates(trainerQuery, dependencies)).toMatchObject({ candidates: [], rejected: [{ reason: 'coach_auth_unavailable' }] });
  dependencies.readIdentity = async () => { throw Error('SECRET provider details'); };
  await expect(evaluateTrainerCandidates(trainerQuery, dependencies)).rejects.toMatchObject({ code: 'permission-denied', message: 'Current Member access is required.' });
});

it.each([
  { mappings: [] },
  { mappings: [{ ...expertise, exerciseIds: ['unknown-exercise'] }] },
  { mappings: [{ ...expertise, learningObjectives: ['endurance'] }] },
  { mappings: [{ ...expertise, levels: ['advanced'] }] },
  { mappings: [{ ...expertise, organizationId: 'foreign' }] },
])('does not infer relevance from bio or free-text specialty tags: %j', async ({ mappings }) => {
  const { dependencies } = trainerFixture();
  dependencies.trustedExpertise = mappings as typeof dependencies.trustedExpertise;
  expect(await evaluateTrainerCandidates(trainerQuery, dependencies)).toMatchObject({ candidates: [], rejected: [{ reason: 'unsupported_relevance' }] });
});

it('supports explicitly trusted curated expertise and retains its reviewed mapping evidence', async () => {
  const { dependencies } = trainerFixture();
  dependencies.trustedExpertise = [{ ...expertise, basis: 'curated_expertise' }];
  expect((await evaluateTrainerCandidates(trainerQuery, dependencies)).candidates[0].relevance).toBe('curated_expertise');
});

it('checks both 30-minute locks for a 60-minute option and releases only a known expired hold', async () => {
  const { store, dependencies } = trainerFixture();
  store.documents.set(`orgs/org-1/slotLocks/${keyOf('coach-1', start + SLOT)}`, { schemaVersion: 1, coachId: 'coach-1', branchId: 'branch-1', bookingId: 'other', status: 'pending_hold', expiresAtMillis: now + 1 });
  expect((await evaluateTrainerCandidates(trainerQuery, dependencies)).candidates[0].availableOptions[0].startAtMillis).toBe(start + 2 * SLOT);
  dependencies.clock = () => now + 1;
  expect((await evaluateTrainerCandidates(trainerQuery, dependencies)).candidates[0].availableOptions[0].startAtMillis).toBe(start);
});

it('rejects malformed locks rather than reporting them as open availability', async () => {
  const { store, dependencies } = trainerFixture();
  store.documents.set(`orgs/org-1/slotLocks/${keyOf('coach-1', start)}`, { schemaVersion: 1, coachId: 'coach-1', branchId: 'branch-1', bookingId: 'other', status: ['confirmed'] });
  expect(await evaluateTrainerCandidates(trainerQuery, dependencies)).toMatchObject({ candidates: [], rejected: [{ reason: 'availability_invalid' }] });
});

it('enforces actual Member daily cap without writing a hold', async () => {
  const { store, dependencies } = trainerFixture();
  store.documents.set(`orgs/org-1/bookingDays/${keyOf('member-1', trainerQuery.localDate)}`, { schemaVersion: 1, memberId: 'member-1', localDate: trainerQuery.localDate, timeZone: 'Asia/Kuala_Lumpur', reservations: [{ bookingId: 'other', status: 'confirmed', expiresAtMillis: now }] });
  expect(await evaluateTrainerCandidates(trainerQuery, dependencies)).toMatchObject({ candidates: [], rejected: [{ reason: 'member_daily_cap' }] });
});

it('filters actual cross-Coach Member conflicts while retaining later options', async () => {
  const { store, dependencies } = trainerFixture();
  store.documents.get('orgs/org-1/settings/booking')!.maxActiveBookingsPerMemberPerDay = 3;
  store.documents.set(`orgs/org-1/bookingDays/${keyOf('member-1', trainerQuery.localDate)}`, { schemaVersion: 1, memberId: 'member-1', localDate: trainerQuery.localDate, timeZone: 'Asia/Kuala_Lumpur', reservations: [{ bookingId: 'other', status: 'confirmed', expiresAtMillis: now }] });
  store.documents.set('orgs/org-1/bookings/other', { schemaVersion: 1, bookingId: 'other', organizationId: 'org-1', memberId: 'member-1', coachId: 'other-coach', status: 'confirmed', localDate: trainerQuery.localDate, timeZone: 'Asia/Kuala_Lumpur', startAtMillis: start, endAtMillis: start + 3600000, durationMinutes: 60 });
  expect((await evaluateTrainerCandidates(trainerQuery, dependencies)).candidates[0].availableOptions[0].startAtMillis).toBe(start + 3600000);
});

it('uses actual weekly roster daily capacity and masks leave/break exceptions', async () => {
  const { store, dependencies } = trainerFixture();
  store.documents.delete('orgs/org-1/coachAvailability/coach-1/days/2026-10-02');
  const roster = { schemaVersion: 1, revision: 1, timeZone: 'Asia/Kuala_Lumpur', policyVersion: 'booking-v1', createdAtMillis: now, updatedAtMillis: now,
    weeklyAvailability: { dailyCapacityHours: 1, advanceBookingWindowDays: 30, schedule: Array.from({ length: 7 }, (_, i) => ({ dayOfWeek: i + 1, isActive: true, startMinute: 600, endMinute: 840, branchId: 'branch-1' })) },
    exceptions: [{ id: 'break-1', type: 'breakTime', reason: 'private reason', startAtMillis: start, endAtMillis: start + SLOT }] };
  store.documents.set('orgs/org-1/coachAvailability/coach-1', roster);
  expect((await evaluateTrainerCandidates(trainerQuery, dependencies)).candidates[0].availableOptions[0].startAtMillis).toBe(start + SLOT);
  store.documents.set(`orgs/org-1/slotLocks/${keyOf('coach-1', start + SLOT)}`, { schemaVersion: 1, coachId: 'coach-1', branchId: 'branch-1', bookingId: 'other', status: 'confirmed' });
  expect(await evaluateTrainerCandidates(trainerQuery, dependencies)).toMatchObject({ candidates: [], rejected: [{ reason: 'coach_daily_capacity' }] });
});

it('rejects a legacy day, unknown schedule schema, no open times and a date outside the actual booking horizon', async () => {
  const { store, dependencies } = trainerFixture();
  const path = 'orgs/org-1/coachAvailability/coach-1/days/2026-10-02';
  store.documents.set(path, { schemaVersion: 1, windows: [] });
  expect((await evaluateTrainerCandidates(trainerQuery, dependencies)).rejected[0].reason).toBe('availability_invalid');
  store.documents.delete(path);
  expect((await evaluateTrainerCandidates(trainerQuery, dependencies)).rejected[0].reason).toBe('no_bookable_slot');
  expect((await evaluateTrainerCandidates({ ...trainerQuery, localDate: '2026-11-01' }, dependencies)).rejected[0].reason).toBe('outside_booking_window');
});

it('rechecks authority after the external identity read and refuses partial results on source drift', async () => {
  const { store, dependencies } = trainerFixture();
  let coachReads = 0;
  dependencies.readIdentity = async id => {
    if (id === 'coach-1' && ++coachReads === 2) store.documents.get('orgs/org-1/coaches/coach-1')!.revision = 3;
    return { exists: true, disabled: false, emailVerified: true };
  };
  await expect(evaluateTrainerCandidates(trainerQuery, dependencies)).rejects.toMatchObject({ code: 'aborted' });
});

it('bounds authoritative IDs, validates their order/uniqueness and sanitizes repository errors', async () => {
  const { dependencies } = trainerFixture();
  for (const ids of [Array.from({ length: 21 }, (_, i) => `coach-${i}`), ['coach-1', 'coach-1'], ['z', 'a'], ['../private']]) {
    dependencies.repository.listCoachIds = async () => ids;
    await expect(evaluateTrainerCandidates(trainerQuery, dependencies)).rejects.toThrow();
  }
  dependencies.repository.listCoachIds = async () => { throw Error('SECRET'); };
  await expect(evaluateTrainerCandidates(trainerQuery, dependencies)).rejects.toMatchObject({ message: 'Trainer sources are unavailable.' });
});

it.each([{ learningObjective: 'fat_loss' }, { level: 'elite' }, { durationMinutes: 45 }, { localDate: '2026-02-30' }, { memberNotes: 'private' }, { schemaVersion: 2 }])('rejects unsupported context before any source access %j', async patch => {
  const { dependencies } = trainerFixture();
  let reads = 0;
  dependencies.repository.listCoachIds = async () => { reads++; return []; };
  await expect(evaluateTrainerCandidates({ ...trainerQuery, ...patch } as typeof trainerQuery, dependencies)).rejects.toThrow();
  expect(reads).toBe(0);
});

it('rejects a malformed curated mapping enum instead of coercing it into trusted evidence', async () => {
  const { dependencies } = trainerFixture();
  dependencies.trustedExpertise = [{ ...expertise, basis: ['exact_exercise'] }] as unknown as typeof dependencies.trustedExpertise;
  await expect(evaluateTrainerCandidates(trainerQuery, dependencies)).rejects.toMatchObject({ code: 'failed-precondition' });
});

it('rejects array-valued credential states even when another genuine approval satisfies the summary count', async () => {
  const { store, dependencies } = trainerFixture(), secondId = 'b'.repeat(32);
  store.documents.get('orgs/org-1/coachProfiles/coach-1/certificationState/current')!.certificationIds = [certificationId, secondId];
  store.documents.set(`orgs/org-1/coachProfiles/coach-1/certifications/${secondId}`, {
    ...store.documents.get(`orgs/org-1/coachProfiles/coach-1/certifications/${certificationId}`), id: secondId,
    storagePath: `orgs/org-1/coachCertifications/coach-1/${secondId}`, status: ['approved'],
  });
  expect(await evaluateTrainerCandidates(trainerQuery, dependencies)).toMatchObject({ candidates: [], rejected: [{ reason: 'credentials_invalid' }] });
});

it('rejects a malformed published photo path under the existing profile schema', async () => {
  const { store, dependencies } = trainerFixture();
  store.documents.get('orgs/org-1/coaches/coach-1')!.photoPath = '../foreign-private-file';
  expect(await evaluateTrainerCandidates(trainerQuery, dependencies)).toMatchObject({ candidates: [], rejected: [{ reason: 'profile_invalid' }] });
});

it('denies canonical Member scope before directory enumeration or external Auth lookup', async () => {
  const { store, dependencies } = trainerFixture();
  store.documents.get('users/member-1')!.organizationId = 'foreign';
  let sourceCalls = 0;
  dependencies.readIdentity = async () => { sourceCalls++; return { exists: true, disabled: false, emailVerified: true }; };
  dependencies.repository.listCoachIds = async () => { sourceCalls++; return []; };
  await expect(evaluateTrainerCandidates(trainerQuery, dependencies)).rejects.toMatchObject({ code: 'permission-denied' });
  expect(sourceCalls).toBe(0);
});

it('refuses Member branch drift during the external Coach Auth read', async () => {
  const { store, dependencies } = trainerFixture();
  dependencies.readIdentity = async id => {
    if (id === 'coach-1') store.documents.get('orgs/org-1/members/member-1')!.branchIds = [];
    return { exists: true, disabled: false, emailVerified: true };
  };
  await expect(evaluateTrainerCandidates(trainerQuery, dependencies)).rejects.toMatchObject({ code: 'aborted' });
});

it('ignores only structurally valid expired Member holds in current daily accounting', async () => {
  const { store, dependencies } = trainerFixture();
  store.documents.set(`orgs/org-1/bookingDays/${keyOf('member-1', trainerQuery.localDate)}`, { schemaVersion: 1, memberId: 'member-1', localDate: trainerQuery.localDate, timeZone: 'Asia/Kuala_Lumpur', reservations: [{ bookingId: 'expired', status: 'pending_hold', expiresAtMillis: now }] });
  expect((await evaluateTrainerCandidates(trainerQuery, dependencies)).candidates).toHaveLength(1);
  store.documents.get(`orgs/org-1/bookingDays/${keyOf('member-1', trainerQuery.localDate)}`)!.memberId = 'foreign';
  expect(await evaluateTrainerCandidates(trainerQuery, dependencies)).toMatchObject({ candidates: [], rejected: [{ reason: 'availability_invalid' }] });
});

it('never treats stale public credential flags as current approval evidence', async () => {
  const { store, dependencies } = trainerFixture();
  store.documents.delete(`orgs/org-1/coachProfiles/coach-1/certifications/${certificationId}`);
  expect(await evaluateTrainerCandidates(trainerQuery, dependencies)).toMatchObject({ candidates: [], rejected: [{ reason: 'credentials_invalid' }] });
});

it('fails without partial candidates when bounded source bytes are exceeded', async () => {
  const { store, dependencies } = trainerFixture();
  store.documents.get('orgs/org-1/coaches/coach-1')!.bio = 'x'.repeat(8 * 1024 * 1024);
  await expect(evaluateTrainerCandidates(trainerQuery, dependencies)).rejects.toMatchObject({ code: 'resource-exhausted' });
});
