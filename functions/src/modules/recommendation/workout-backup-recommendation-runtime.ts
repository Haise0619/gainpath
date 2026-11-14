import {fypDigest} from '../dataset/fyp-integrity';
import { credentialFailure } from './trainer-candidate-eligibility';
import { FieldPath, getFirestore, type Firestore } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';
import type { TransactionPort } from '../../platform/firestore/store';
import { DomainError } from '../../platform/errors';
import { digestOf, object, validateBackupPayload, validateFictionalSessionPayload } from '../workouts/workout-backup-validation';
import { exerciseTutorialProjection } from '../content/exercise-tutorial';
import { tutorialMediaUrl } from '../content/tutorial-media';
import { bookingCoachScope, bookingDaySnapshot, currentBookingMembership, currentBookingPolicy } from '../coaching/booking-validation';
import { localDate, plusDate, SLOT } from '../coaching/coach-availability-contracts';
import { memberBusySlots } from '../coaching/member-booking-conflicts';
import { recommendationPreferences } from './recommendation-personalization';
import { parseQueueTarget, queueText, type QueueTarget } from './recommendation-queue-contracts';
import type { CanonicalSuggestion, ReviewedCanonicalRuntime } from './canonical-recommendation-lifecycle';
import type { CurrentRecommendationTarget } from './recommendation-member-contracts';

const DAY = 86400000;
const MAX_AGE = 30 * DAY;
const POLICY = 'workout-backup-guidance-v1';
const EXERCISE_RULES: Readonly<Record<string, string>> = {
  F3b8xIr8ynBDd3gEICKX: 'bodyweight-squat-side-v1',
  'standing-single-arm-curl-side-v1': 'single-arm-curl-side-v1',
  'standing-calf-raise-side-v1': 'standing-calf-raise-side-v1',
  'wall-push-up-side-v1': 'wall-push-up-side-v1',
};
const identifier = (s: unknown): s is string => typeof s === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(s);

function backupSession(raw: Record<string, unknown> | undefined, org: string, member: string, key: string, now: number, boundary: number) {
  if (!raw || raw.schemaVersion !== 1 || raw.classification !== 'provisional_member_backup' ||
    raw.kind !== 'session' || raw.key !== key || !identifier(raw.id) || key !== 'session-' + raw.id ||
    typeof raw.payloadJson !== 'string' || raw.payloadJson.length > 32768) return null;
  try {
    const p = validateBackupPayload('session', raw.id, org, member, JSON.parse(raw.payloadJson));
    const ended = Date.parse(String(p.endedAt));
    if (digestOf(p) !== raw.digest || ended > now || ended < now - MAX_AGE ||
      Date.parse(String(p.startedAt)) < boundary || Number(p.repetitions) < 1) return null;
    const metrics = object(p.poseMetrics);
    const tracked = Number(metrics.trackedDurationMicros);
    const total = tracked + Number(metrics.rejectedDurationMicros);
    const exercise = String(p.exerciseId);
    const rule = EXERCISE_RULES[exercise];
    const armMode = exercise === 'standing-single-arm-curl-side-v1' && metrics.schemaVersion === 2
      ? object(metrics.curlArms).mode : null;
    const scored = rule && metrics.scoringVersion === rule && metrics.cameraView === 'side' &&
      metrics.schemaVersion === (exercise === 'standing-single-arm-curl-side-v1' ? 2 : 1) &&
      identifier(metrics.detectorId) && identifier(metrics.detectorVersion) &&
      total > 0 && tracked / total >= .6 && Number(p.repetitions) >= 3 &&
      typeof metrics.formScorePercent === 'number';
    return { exercise, ended, digest: String(raw.digest), origin: 'synced_summary' as const,
      score: scored ? metrics.formScorePercent as number : null,
      compatibility: digestOf({exercise, scoringVersion: metrics.scoringVersion, cameraView: metrics.cameraView,
        armMode, schema: metrics.schemaVersion, detector: metrics.detectorId, version: metrics.detectorVersion}) };
  } catch { return null; }
}

async function readWorkoutSource(tx: TransactionPort, org: string, member: string, key: string,
  now: number, boundary: number, cohortRoot?: string) {
  const backup = await tx.get(`orgs/${org}/members/${member}/workoutBackups/${key}`);
  if (backup || !cohortRoot) return backupSession(backup, org, member, key, now, boundary);
  const id = key.slice('session-'.length);
  if (!identifier(id)) return null;
  const logical = `orgs/${org}/members/${member}/syntheticObservations/${id}`;
  const data = await tx.get(logical);
  const physical = `${cohortRoot}/members/${member}/syntheticObservations/${id}`;
  const ownership = await tx.get(`orgs/${org}/seedOwnership/${fypDigest(physical)}`);
  if (!data || data.schemaVersion !== 1 || data.organizationId !== org || data.memberId !== member ||
    data.observationId !== id || data.seedId !== 'gainpath-fyp-v1' || data.provenance !== 'fictional_synthetic' ||
    ownership?.path !== physical || ownership.digest !== fypDigest(data)) return null;
  try {
    const payload = validateFictionalSessionPayload(id, org, member, data.payload);
    const ended = Date.parse(String(payload.endedAt));
    if (payload.provenance !== 'recordedFixture' || digestOf(payload) !== data.digest ||
      ended !== data.observedAtMillis || ended > now || ended < now - MAX_AGE ||
      Date.parse(String(payload.startedAt)) < boundary || Number(payload.repetitions) < 1) return null;
    // Recorded sample histories supply exercise context only. They never
    // contribute a measured Form Score or become camera/backup records.
    return {exercise: String(payload.exerciseId), ended, digest: String(data.digest), score: null, origin: 'recorded_history' as const,
      compatibility: digestOf({exercise:payload.exerciseId,source:'recorded_history'})};
  } catch { return null; }
}

async function tutorial(tx: TransactionPort, org: string, target: Extract<QueueTarget, {kind: 'content'}>) {
  const d = target.destination;
  const [publication, catalog] = await Promise.all([
    tx.get(`orgs/${org}/content/${d.routineId}`), tx.get(`orgs/${org}/exerciseVideos/${d.exerciseId}`),
  ]);
  if (publication?.status !== 'published' || publication.kind !== 'routine' ||
    publication.archived === true || publication.isActive === false ||
    catalog?.isActive !== true || catalog.archived === true || !Array.isArray(publication.exercises)) return null;
  const entry = publication.exercises[d.exerciseIndex];
  if (!entry || entry.exerciseId !== d.exerciseId || (entry.dayNumber ?? 1) !== d.dayNumber || !queueText(entry.name, 120)) return null;
  try {
    const media = exerciseTutorialProjection(entry);
    if (!(Array.isArray(media.tutorialSteps) && media.tutorialSteps.length) && !tutorialMediaUrl(entry.videoUrl)) return null;
    return {target, label: entry.name, imageUrl: typeof media.imageUrl === 'string' ? media.imageUrl : null,
      specialization: null, photoPath: null, difficulty: media.difficulty ?? publication.difficulty};
  } catch { return null; }
}

const GOAL_SPECIALTIES: Readonly<Record<string, readonly string[]>> = {
  buildMuscle: ['strength training', 'strength', 'hypertrophy', 'muscle building'],
  improveEndurance: ['endurance', 'cardio', 'conditioning'],
  increaseFlexibility: ['mobility', 'flexibility'],
  generalFitness: ['general fitness', 'functional training', 'beginner strength', 'strength and conditioning'],
  loseWeight: ['weight management', 'weight loss'],
  reduceStress: ['stress management'],
};
const normalized = (value: string) => value.trim().toLowerCase();

async function coachTarget(tx: TransactionPort, org: string, coachId: string, now: number,
  member: string, expectedBranch?: string): Promise<CurrentRecommendationTarget | null> {
  try {
    const root = `orgs/${org}`;
    const profile = await tx.get(`${root}/coaches/${coachId}`);
    const credential = await tx.get(`${root}/coachProfiles/${coachId}/certificationState/current`);
    if (!profile || profile.status !== 'published' || profile.certificationVerified !== true ||
      credential?.certificationVerified !== true || !Number.isSafeInteger(credential.approvedCount) ||
      Number(credential.approvedCount) < 1 || profile.approvedCertificationCount !== credential.approvedCount ||
      !queueText(profile.displayName, 80) || !queueText(profile.specialty, 80)) return null;
    if (typeof await credentialFailure(tx, root, coachId, profile, now) !== 'number') return null;
    const membership = await currentBookingMembership(tx, org, member);
    const scope = await bookingCoachScope(tx, org, coachId, membership.branchIds);
    if (expectedBranch && !scope.permitted.includes(expectedBranch)) return null;
    const policy = currentBookingPolicy(await tx.get(`${root}/settings/booking`));
    const today = localDate(now, policy.timeZone);
    for (const date of [today, plusDate(today, 1), plusDate(today, 2)]) {
      const day = await bookingDaySnapshot(tx, org, coachId, member, date, policy, scope.assigned, now);
      if (day.reservations.length >= policy.cap ||
        (day.dailyCapacityMinutes !== undefined && day.blocked.size * 30 + 30 > day.dailyCapacityMinutes)) continue;
      const busy = await memberBusySlots(tx, org, member, date, policy.timeZone, day.reservations);
      for (const slot of day.grid.slots) {
        if (slot <= now || day.blocked.has(slot) || busy.has(slot)) continue;
        const window = day.windows.find(w => scope.permitted.includes(w.branchId) &&
          (!expectedBranch || w.branchId === expectedBranch) && w.startAtMillis <= slot && w.endAtMillis >= slot + SLOT);
        if (!window) continue;
        const target: QueueTarget = {kind: 'trainer', coachId, branchId: window.branchId,
          observedStartAtMillis: slot, observedEndAtMillis: slot + SLOT};
        const prefix = `${root}/coachProfilePhotos/${coachId}/`;
        const photoPath = typeof profile.photoPath === 'string' && profile.photoPath.startsWith(prefix) &&
          /^[a-f0-9]{32}$/.test(profile.photoPath.slice(prefix.length)) ? profile.photoPath : null;
        return {target, label: profile.displayName, specialization: profile.specialty, photoPath, imageUrl: null};
      }
    }
    return null;
  } catch (error) {
    if (error instanceof DomainError && ['failed-precondition', 'permission-denied', 'invalid-argument'].includes(error.code)) return null;
    throw error;
  }
}

export function createWorkoutBackupRuntime(db: Firestore, coachIsVerified: (uid: string) => Promise<boolean>, cohortRoot?: string): ReviewedCanonicalRuntime {
  if (cohortRoot !== undefined && cohortRoot !== 'orgs/gainpath/cohorts/fyp-v1') throw new Error('Unsupported workout scope.');
  const physical = (logical: string) => cohortRoot ? cohortRoot + logical.slice('orgs/gainpath'.length) : logical;
  const logical = (physicalPath: string) => cohortRoot ? 'orgs/gainpath' + physicalPath.slice(cohortRoot.length) : physicalPath;
  return {
    ...(cohortRoot ? {scopedDataset: true as const} : {}),
    reviewId: POLICY,
    enabledTuples: [],
    notices: [{policyId: POLICY, noticeVersion: 'workout-backup-v1', contentVersion: 'workout-backup-v1',
      history: {mode: 'retained', earliestAtMillis: 0}}],
    maximumAgeMillis: MAX_AGE, expiresAfterMillis: 14 * DAY, cooldownMillis: 7 * DAY,
    listAcceptedIds: async () => [],
    derive: () => null,
    async listIds(_tx, org, member, afterId) {
      const collection = db.collection(physical(`orgs/${org}/canonicalRecommendations`));
      // Query by owner first to avoid a composite index requirement.
      let query = (member ? collection.where('memberId', '==', member) : collection).orderBy(FieldPath.documentId());
      if (afterId) query = query.startAfter(afterId);
      return (await query.limit(25).get()).docs.map(d => d.id);
    },
    async resolveTarget(tx, org, suggestion, now, member, reading) {
      if (suggestion.target.kind === 'content') return tutorial(tx, org, suggestion.target);
      if (!member) return null;
      const target = suggestion.target;
      if (!await coachIsVerified(target.coachId)) return null;
      const current = await coachTarget(tx, org, target.coachId, now, member, target.branchId);
      if (!current) return null;
      if (reading) return {...current, target};
      return digestOf(current.target) === digestOf(target) ? current : null;
    },
    async backupSuggestions(tx, org, member, key, now, boundary) {
      const root = `orgs/${org}`;
      const backups = `${root}/members/${member}/workoutBackups`;
      const source = await readWorkoutSource(tx, org, member, key, now, boundary, cohortRoot);
      if (!source) return [];
      const history = await db.collection(physical(backups)).orderBy('updatedAtMillis', 'desc').limit(32).get();
      const observed = cohortRoot ? (await db.collection(`${cohortRoot}/members/${member}/syntheticObservations`)
        .orderBy('observedAtMillis', 'desc').limit(32).get()).docs : [];
      const historyKeys = new Set([...history.docs.map(row => row.id), ...observed.map(row => 'session-' + row.id)]);
      const recent = [source];
      for (const historyKey of historyKeys) {
        if (historyKey === key) continue;
        const other = await readWorkoutSource(tx, org, member, historyKey, now, boundary, cohortRoot);
        if (other?.exercise === source.exercise && other.ended <= source.ended) recent.push(other);
      }
      const scored = recent.filter(s => s.compatibility === source.compatibility && s.score !== null).sort((a, b) => b.ended - a.ended).slice(0, 5);
      const mean = scored.length >= 2 ? scored.reduce((sum, s) => sum + s.score!, 0) / scored.length : null;
      const objective = mean !== null && mean < 65 ? 'movement_control' :
        mean !== null && mean >= 85 ? 'progression' : 'technique_foundations';
      const catalog = await tx.get(`${root}/exerciseVideos/${source.exercise}`);
      const label = catalog?.exerciseName ?? catalog?.name ?? catalog?.title;
      if (!queueText(label, 80) || catalog?.isActive !== true || catalog.archived === true) return [];
      const preferences = recommendationPreferences(await tx.get(`${root}/profiles/${member}`));
      const publications = await db.collection(physical(`${root}/content`)).where('status', '==', 'published').limit(100).get();
      const tutorials: Awaited<ReturnType<typeof tutorial>>[] = [];
      for (const row of publications.docs) {
        const entries = row.data().exercises;
        if (!identifier(row.id) || !Array.isArray(entries) || row.data().kind !== 'routine') continue;
        if (tutorials.length >= 20) break;
        for (const [index, entry] of entries.slice(0, 50).entries()) {
          if (tutorials.length >= 20) break;
          if (entry?.exerciseId !== source.exercise) continue;
          const dayNumber = entry.dayNumber ?? 1;
          if (!Number.isInteger(dayNumber) || dayNumber < 1 || dayNumber > 50) continue;
          tutorials.push(await tutorial(tx, org, {kind: 'content', destination: {
            kind: 'published_routine_exercise_tutorial', organizationId: org, routineId: row.id,
            exerciseIndex: index, exerciseId: source.exercise, dayNumber,
          }}));
        }
      }
      const wantedDifficulty = objective === 'movement_control' ? 'beginner' :
        objective === 'progression' && preferences.experience !== 'beginner' ? 'advanced' : preferences.experience ?? 'beginner';
      const difficulty = (value: unknown) => typeof value === 'string' && normalized(value) === wantedDifficulty ? 1 : 0;
      const selected = tutorials.filter(t => t !== null).sort((a, b) => difficulty(b.difficulty) - difficulty(a.difficulty))[0];
      const output: CanonicalSuggestion[] = [];
      const make = (candidate: CurrentRecommendationTarget, title: string, summary: string, explanations: string[]): CanonicalSuggestion => ({
        needKey: digestOf({exercise: source.exercise, kind: candidate.target.kind}), policyVersion: POLICY,
        source: {kind: source.origin, recordKey: key},
        evidenceFingerprint: digestOf({source: source.digest, qualified: scored.map(s => s.digest).sort()}),
        exerciseLabel: label, objective, title, summary, explanations,
        target: parseQueueTarget(candidate.target, org), targetLabel: candidate.label,
      });
      if (selected) output.push(make(selected, `Practise ${label} with a tutorial`,
        'Explore step-by-step guidance for the exercise you completed.',
        ['Matches your recent workout exercise.']));
      // Coaching requires an explicit goal match and repeat practice. One low score cannot trigger an upsell.
      if (recent.length > 1 && preferences.goals.length) {
        const tags = preferences.goals.flatMap(goal => GOAL_SPECIALTIES[goal] ?? []);
        const candidates = await db.collection(physical(`${root}/coaches`)).where('status', '==', 'published').limit(25).get();
        for (const row of candidates.docs) {
          const data = await tx.get(logical(row.ref.path));
          if (!data || data.certificationVerified !== true || !identifier(row.id)) continue;
          const specialties = [data.specialty, ...(Array.isArray(data.specializationTags) ? data.specializationTags : [])];
          if (!specialties.some(v => typeof v === 'string' && tags.includes(normalized(v))) || !await coachIsVerified(row.id)) continue;
          const coach = await coachTarget(tx, org, row.id, now, member);
          if (!coach) continue;
          output.push(make(coach, `Explore coaching for ${label}`,
            'Meet a coach whose published specialty matches one of your fitness goals.',
            ['Matches a stated fitness goal.', 'A booking time was available when checked.']));
          break;
        }
      }
      return output;
    },
  };
}

export function getWorkoutBackupRuntime() {
  const db = getFirestore();
  if (db.databaseId !== '(default)') throw new Error('Default workout database required.');
  return createWorkoutBackupRuntime(db, async uid => {
    try {
      const user = await getAuth().getUser(uid);
      return user.emailVerified && !user.disabled;
    } catch (error) {
      if ((error as {code?: string}).code === 'auth/user-not-found') return false;
      throw error;
    }
  });
}
