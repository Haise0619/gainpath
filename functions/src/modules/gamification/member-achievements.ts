import { requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import type { DocumentData, DocumentStore } from '../../platform/firestore/store';
import { InputValidationError, requiredIdentifier } from '../../platform/validation';
import { digestOf, object, validateBackupPayload } from '../workouts/workout-backup-validation';
import { FLOOR_PUSH_UP_ID } from '../workouts/floor-push-up-validation';
import {
  APP_CHECK_IN_POLICY, parseAppCheckInProfile, parseAppCheckInReceipt, requireCheckInMember,
} from './app-check-in-service';

const checkIn = (id: string, title: string, description: string, target: number) =>
  ({ id, title, description, target, category: 'check-in' as const });
const workout = (id: string, title: string, description: string, target: number) =>
  ({ id, title, description, target, category: 'workout' as const });

export const achievementCatalog = [
  checkIn('first-check-in', 'First Check-in', 'Claim your first daily check-in.', 1),
  checkIn('check-in-streak-3', 'Three-day Streak', 'Check in on 3 consecutive days.', 3),
  checkIn('check-in-streak-7', 'Seven-day Streak', 'Check in on 7 consecutive days.', 7),
  checkIn('check-in-streak-14', 'Two-week Champion', 'Check in on 14 consecutive days.', 14),
  workout('first-workout', 'First Workout', 'Complete 1 eligible workout.', 1),
  workout('workout-regular', 'Workout Regular', 'Complete 5 eligible workouts.', 5),
  workout('century-club', 'Century Club', 'Record 100 full AI-tracked repetitions.', 100),
  workout('routine-finisher', 'Routine Finisher', 'Finish every target in a routine workout.', 1),
] as const;

interface Row { id: string; data: DocumentData }
export interface AchievementStore extends DocumentStore {
  page(path: string, after: string | null, limit: number): Promise<Row[]>;
}
type Auth = Parameters<typeof requireCheckInMember>[1];
type Unlocks = Record<string, number>;
const dayMillis = 86_400_000;
const offsetMillis = 8 * 3_600_000;
const pageSize = 100;

async function scan(store: AchievementStore, path: string, consume: (row: Row) => boolean | void) {
  let after: string | null = null;
  while (true) {
    const page = await store.page(path, after, pageSize);
    for (const row of page) if (consume(row) === true) return;
    if (page.length < pageSize) return;
    after = page[page.length - 1].id;
  }
}

function backup(row: Row, org: string, uid: string) {
  const { classification, kind, id, key, digest, payloadJson } = row.data;
  if (row.data.schemaVersion !== 1 || classification !== 'provisional_member_backup' ||
      (kind !== 'routine' && kind !== 'session') || typeof id !== 'string' ||
      key !== row.id || row.id !== kind + '-' + id || typeof payloadJson !== 'string') return null;
  try {
    requiredIdentifier(id, 'backup ID');
    const payload = validateBackupPayload(kind, id, org, uid, JSON.parse(payloadJson));
    return digestOf(payload) === digest ? { kind, id, payload } : null;
  } catch (error) {
    if (error instanceof InputValidationError || error instanceof SyntaxError) return null;
    throw error;
  }
}

interface Session {
  id: string;
  startedAt: number;
  at: number;
  full: number;
  exercise: unknown;
  metrics: DocumentData;
}
interface Routine { at: number; sessions: string[]; timedRuns: string[] }

function completedRoutine(payload: DocumentData, sessions: Map<string, Session>): Routine | null {
  const attempt = object(payload.attempt);
  const start = Number(attempt.startedAtMicros), end = Number(attempt.finishedAtMicros);
  if (attempt.finished !== true || start <= 0 || end <= start) return null;
  const at = Math.floor(end / 1000);
  const rows = object(attempt.routine).exercises as DocumentData[];
  const entries = attempt.entries as DocumentData[];
  const used: string[] = [];
  const timedRuns: string[] = [];
  for (const entry of entries) {
    const index = Number(entry.index);
    const row = rows[index], sets = Number(row.sets), reps = Number(row.reps);
    if (sets <= 0 || (payload.skipped as unknown[]).includes(index)) return null;
    if (entry.status === 'timerCompleted' && row.executionMode === 'videoGuidedTimed') {
      timedRuns.push(String(object(entry.guided).runId));
      continue;
    }
    if (!(reps > 0)) return null;
    if (entry.status === 'selfReportedCompleted' && row.executionMode !== 'videoGuidedTimed' &&
        entry.manualSets === sets && object(payload.manualSets)[index] === sets) continue;
    if (entry.status !== 'completed' || row.executionMode === 'videoGuidedTimed') return null;
    const qualifying = (entry.sessionIds as string[]).find(id => {
      const session = sessions.get(id);
      if (!session || session.exercise !== row.exerciseId || session.at > at ||
          session.startedAt < Math.floor(start / 1000) ||
          session.metrics.publishedRoutineId !== payload.routineId) return false;
      const curl = session.metrics.curlArms as DocumentData | undefined;
      return curl
        ? Number(curl.completedSets) >= sets && Number(curl.repetitionsPerArm) >= reps
        : session.full >= sets * reps && session.full > 0;
    });
    if (!qualifying) return null;
    used.push(qualifying);
  }
  return { at, sessions: used, timedRuns };
}

function completedStandalone(session: Session) {
  const curl = session.metrics.curlArms as DocumentData | undefined;
  if (curl) return Number(curl.targetSets) > 0 && Number(curl.repetitionsPerArm) > 0 &&
    curl.targetSets === curl.completedSets;
  // The standalone floor practice has a fixed 3 × 8 prescription in the app.
  return session.exercise === FLOOR_PUSH_UP_ID && session.full >= 24;
}

async function workoutProgress(store: AchievementStore, path: string, org: string, uid: string, now: number) {
  const sessions = new Map<string, Session>();
  const routinePayloads: DocumentData[] = [];
  await scan(store, path, row => {
    const record = backup(row, org, uid);
    if (!record) return;
    if (record.kind === 'routine') routinePayloads.push(record.payload);
    else {
      const at = Date.parse(String(record.payload.endedAt)), full = Number(record.payload.repetitions);
      if (full > 0 && at > 0 && at <= now) sessions.set(record.id, {
        id: record.id, startedAt: Date.parse(String(record.payload.startedAt)),
        at, full, exercise: record.payload.exerciseId, metrics: object(record.payload.poseMetrics),
      });
    }
  });
  const associated = new Set<string>();
  const evidenceUsed = new Set<string>();
  const workoutDates: number[] = [];
  const routineDates: number[] = [];
  const routines: Routine[] = [];
  for (const payload of routinePayloads) {
    for (const entry of object(payload.attempt).entries as DocumentData[]) {
      for (const id of (entry.sessionIds ?? []) as string[]) associated.add(id);
    }
    const routine = completedRoutine(payload, sessions);
    if (routine && routine.at <= now) routines.push(routine);
  }
  for (const routine of routines.sort((a, b) => a.at - b.at)) {
    const evidence = [...routine.sessions.map(id => 'session:' + id), ...routine.timedRuns.map(id => 'run:' + id)];
    if (evidence.some(id => evidenceUsed.has(id))) continue;
    for (const id of evidence) evidenceUsed.add(id);
    workoutDates.push(routine.at);
    routineDates.push(routine.at);
  }
  let fullReps = 0, hundredAt: number | undefined;
  for (const session of [...sessions.values()].sort((a, b) => a.at - b.at)) {
    fullReps += session.full;
    if (fullReps >= 100) hundredAt ??= session.at;
    if (session.metrics.publishedRoutineId === null && !associated.has(session.id) &&
        completedStandalone(session)) workoutDates.push(session.at);
  }
  workoutDates.sort((a, b) => a - b);
  return { workoutDates, fullReps, hundredAt, routineDates };
}

export async function memberAchievements(store: AchievementStore, auth: Auth | undefined, raw: unknown, clock = Date.now) {
  requireVerifiedEmail(auth);
  const data = object(raw);
  if (Object.keys(data).length !== 3 || data.schemaVersion !== 1 || data.action !== 'achievements') {
    throw new InputValidationError('Invalid achievement fields.');
  }
  const org = requiredIdentifier(data.organizationId, 'organizationId'), uid = auth!.uid;
  if (org !== APP_CHECK_IN_POLICY.organizationId) throw new DomainError('permission-denied', 'Achievements are unavailable for this organization.');
  const root = 'orgs/' + org;
  const checkInPath = root + '/appCheckInProfiles/' + uid;
  const memberPath = root + '/members/' + uid;
  const progressPath = memberPath + '/achievementProgress/v1';
  const now = clock();
  const today = Math.floor((now + offsetMillis) / dayMillis);
  const initial = await store.transact(async tx => {
    await requireCheckInMember(tx, auth!, org);
    const profile = parseAppCheckInProfile(await tx.get(checkInPath), org, uid, today);
    const saved = await tx.get(progressPath);
    return { profile, unlocked: (saved?.unlocked ?? {}) as Unlocks };
  });
  const { profile } = initial;
  const currentStreak = profile.lastOrdinal !== null && today - profile.lastOrdinal <= 1 ? profile.streak : 0;
  const earned: Unlocks = {};
  let complete = true;
  if (!initial.unlocked['check-in-streak-14'] && profile.longest >= 14) {
    let last = -2, streak = 0;
    await scan(store, checkInPath + '/claims', row => {
      const claim = parseAppCheckInReceipt(row.data, org, uid, row.id);
      if (claim.claimedAtMillis > now) return;
      const day = Math.floor((claim.claimedAtMillis + offsetMillis) / dayMillis);
      streak = day === last + 1 ? streak + 1 : 1;
      last = day;
      if (streak !== 14) return;
      earned['check-in-streak-14'] = claim.claimedAtMillis;
      return true;
    });
    complete = earned['check-in-streak-14'] !== undefined;
  }
  const workoutBadges = achievementCatalog.filter(badge => badge.category === 'workout');
  const progress: Record<string, number> = {};
  if (workoutBadges.some(badge => !initial.unlocked[badge.id])) {
    const value = await workoutProgress(store, memberPath + '/workoutBackups', org, uid, now);
    progress['first-workout'] = progress['workout-regular'] = value.workoutDates.length;
    progress['century-club'] = value.fullReps;
    progress['routine-finisher'] = value.routineDates.length;
    const dates = {
      'first-workout': value.workoutDates[0],
      'workout-regular': value.workoutDates[4],
      'century-club': value.hundredAt,
      'routine-finisher': value.routineDates[0],
    };
    for (const [id, at] of Object.entries(dates)) if (at !== undefined) earned[id] = at;
  }
  const confirmed = Object.keys(earned).some(id => !initial.unlocked[id])
    ? await store.transact(async tx => {
        await requireCheckInMember(tx, auth!, org);
        const saved = await tx.get(progressPath);
        const existing = (saved?.unlocked ?? {}) as Unlocks;
        const merged = { ...earned, ...existing };
        if (Object.keys(merged).length !== Object.keys(existing).length) {
          tx.set(progressPath, { schemaVersion: 1, organizationId: org, memberId: uid, unlocked: merged });
        }
        return merged;
      })
    : initial.unlocked;
  const unlocks = { ...profile.badges, ...confirmed };
  return {
    schemaVersion: 1, currentStreak, complete,
    badges: achievementCatalog.map(badge => ({
      ...badge,
      progress: unlocks[badge.id] ? badge.target : Math.min(badge.target, badge.category === 'check-in'
        ? Math.min(currentStreak, badge.target - 1) : progress[badge.id] ?? 0),
      unlockedAtMillis: unlocks[badge.id] ?? null,
    })),
  };
}
