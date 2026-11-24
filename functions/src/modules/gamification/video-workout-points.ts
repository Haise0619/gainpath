import {requireVerifiedEmail} from '../../platform/auth-context';
import {DomainError} from '../../platform/errors';
import {keyOf} from '../../platform/idempotency';
import {InputValidationError, requiredIdentifier} from '../../platform/validation';
import type {DocumentData, DocumentStore} from '../../platform/firestore/store';
import {resolveMembershipEntitlement} from '../commerce/membership-entitlement';
import {parseExercisePrescription, resolveExerciseExecution} from '../content/exercise-execution';
import type {RewardAuth} from './reward-command-security';

const points = 5;
const policyVersion = 'workout-exercise-points-v1';
const maximumIdleMillis = 30 * 60 * 1000;
const dayOf = (millis: number) => new Date(millis + 8 * 3600000).toISOString().slice(0, 10);
const whole = (value: unknown, min = 0): value is number =>
  typeof value === 'number' && Number.isSafeInteger(value) && value >= min;
const missing = () => new DomainError('failed-precondition', 'This exercise is not eligible for workout points.');

export async function videoWorkoutPoints(store: DocumentStore, auth: RewardAuth, raw: DocumentData, clock = Date.now) {
  requireVerifiedEmail(auth);
  const action = raw.action;
  if (raw.schemaVersion !== 1 || (action !== 'beginVideoWorkoutSet' && action !== 'finishVideoWorkoutSet') ||
      Object.keys(raw).sort().join(',') !== 'action,entryId,organizationId,routineId,runId,schemaVersion,set' ||
      !whole(raw.set, 1) || raw.set > 50) throw new InputValidationError('Invalid workout points request.');
  const organizationId = requiredIdentifier(raw.organizationId, 'organizationId');
  const routineId = requiredIdentifier(raw.routineId, 'routineId');
  const entryId = requiredIdentifier(raw.entryId, 'entryId');
  const runId = requiredIdentifier(raw.runId, 'runId');
  const memberId = requiredIdentifier(auth.uid, 'memberId');
  const set = raw.set;
  const root = `orgs/${organizationId}`;
  const timerPath = `${root}/workoutPointTimers/${memberId}`;
  return store.transact(async tx => {
    const now = clock();
    if (!whole(now, 1) || now >= 8639999913600000) throw missing();
    await resolveMembershipEntitlement(tx, auth, organizationId, now);
    const member = await tx.get(`${root}/members/${memberId}`);
    if (member?.role !== 'member') throw new DomainError('permission-denied', 'Active member required.');
    const routine = await tx.get(`${root}/content/${routineId}`);
    if (routine?.status !== 'published' || routine.archived === true || routine.isActive === false || routine.schemaVersion !== 2 ||
        routine.kind !== 'routine_v2' || !Array.isArray(routine.exercises)) throw missing();
    const matching = routine.exercises.filter(row => row && typeof row === 'object' && row.entryId === entryId);
    if (matching.length !== 1) throw missing();
    const entry = matching[0] as DocumentData;
    const exerciseId = requiredIdentifier(entry.exerciseId, 'exerciseId');
    const prescription = parseExercisePrescription(entry);
    const exercise = await tx.get(`${root}/exerciseVideos/${exerciseId}`);
    if (prescription.executionMode !== 'videoGuidedTimed' || set > prescription.sets ||
        exercise?.isActive !== true || exercise.archived === true ||
        resolveExerciseExecution(organizationId, exerciseId, exercise) !== 'videoGuidedTimed') throw missing();
    const media = entry.mediaValidation as DocumentData | undefined;
    const sourceMedia = exercise.mediaValidation as DocumentData | undefined;
    if (media?.schemaVersion !== 1 || sourceMedia?.schemaVersion !== 1 ||
        typeof media.videoUrl !== 'string' || !media.videoUrl.startsWith('https://') ||
        media.videoUrl !== entry.videoUrl || media.videoUrl !== exercise.videoUrl ||
        media.videoUrl !== sourceMedia.videoUrl || typeof media.generation !== 'string' ||
        media.generation !== sourceMedia.generation || media.objectPath !== sourceMedia.objectPath ||
        media.bucket !== sourceMedia.bucket) throw missing();
    const durationMillis = prescription.durationSeconds * 1000;
    const fingerprint = keyOf(routineId, entryId, exerciseId, JSON.stringify(prescription),
      JSON.stringify(entry.mediaValidation ?? null), String(routine.publishedAtMillis ?? ''));
    const today = dayOf(now);
    const awardId = 'workout_' + keyOf(memberId, exerciseId, today);
    const awardPath = `${root}/workoutPointExercises/${awardId}`;
    const runPath = `${root}/workoutPointRuns/${keyOf(memberId, runId)}`;
    const [timer, award, redeemedRun] = await Promise.all([tx.get(timerPath), tx.get(awardPath), tx.get(runPath)]);
    const result = (status: 'started' | 'set_completed' | 'awarded' | 'already_awarded' | 'too_early', waitMillis = 0) =>
      ({schemaVersion: 1, organizationId, memberId, status, waitMillis, points: status === 'awarded' || status === 'already_awarded' ? points : 0});
    if (redeemedRun) {
      if (redeemedRun.fingerprint !== fingerprint) throw missing();
      return result('already_awarded');
    }
    if (award) {
      if (award.schemaVersion !== 1 || award.awardId !== awardId || award.memberId !== memberId ||
          award.organizationId !== organizationId || award.exerciseId !== exerciseId || award.points !== points) throw missing();
      return result('already_awarded');
    }
    const matches = timer?.runId === runId && timer.fingerprint === fingerprint;
    const completed = matches && whole(timer.completed) ? timer.completed : 0;
    const running = matches && whole(timer.startedAtMillis, 1) ? timer.startedAtMillis : null;
    const open = timer && whole(timer.expiresAtMillis, 1) && timer.expiresAtMillis >= now;
    if (action === 'beginVideoWorkoutSet') {
      if (matches && open && completed >= set) return result('set_completed');
      if (matches && open && running !== null && completed + 1 === set) return result('started');
      if (completed + 1 !== set || (set > 1 && !open)) throw missing();
      tx.set(timerPath, {runId, fingerprint, date: today, completed, startedAtMillis: now,
        expiresAtMillis: now + durationMillis + maximumIdleMillis});
      return result('started');
    }
    if (!matches || !open) throw missing();
    if (completed >= set) return result('set_completed');
    if (running === null || completed + 1 !== set) throw missing();
    const remaining = running + durationMillis - now;
    if (remaining > 0) return result('too_early', remaining);
    if (set < prescription.sets) {
      tx.set(timerPath, {...timer, completed: set, startedAtMillis: null, expiresAtMillis: now + maximumIdleMillis});
      return result('set_completed');
    }
    const balancePath = `${root}/rewardBalances/${memberId}`;
    const dailyAwardId = 'workout_day_' + keyOf(memberId, today);
    const dailyPath = `${root}/rewardAwards/${dailyAwardId}`;
    const [balance, daily] = await Promise.all([tx.get(balancePath), tx.get(dailyPath)]);
    if (balance && (balance.schemaVersion !== 1 || balance.organizationId !== organizationId ||
        balance.memberId !== memberId || !whole(balance.points) || !Array.isArray(balance.recentRedemptionIds))) throw missing();
    const total = Number(balance?.points ?? 0) + points;
    const dailyTotal = Number(daily?.points ?? 0) + points;
    if (!whole(total) || !whole(dailyTotal) || (daily && (daily.memberId !== memberId ||
        daily.organizationId !== organizationId || daily.date !== today || daily.awardId !== dailyAwardId ||
        daily.schemaVersion !== 1 || daily.policyVersion !== policyVersion || !whole(daily.points, 1) ||
        daily.basePoints !== daily.points || daily.premiumBonus !== false))) throw missing();
    tx.create(awardPath, {schemaVersion: 1, organizationId, memberId, awardId, runId, exerciseId,
      routineId, entryId, date: today, awardedAtMillis: now, points, dailyAwardId});
    tx.set(dailyPath, {schemaVersion: 1, organizationId, memberId, awardId: dailyAwardId, eventId: dailyAwardId,
      date: today, sourceId: 'routine_completion', producerVersion: 'video-workout-timer-v1',
      policyVersion, occurredAtMillis: now, awardedAtMillis: now, points: dailyTotal, basePoints: dailyTotal, premiumBonus: false});
    tx.set(balancePath, {...balance, schemaVersion: 1, organizationId, memberId, points: total,
      recentRedemptionIds: balance?.recentRedemptionIds ?? [], updatedAtMillis: now});
    tx.create(runPath, {fingerprint, awardId});
    tx.set(timerPath, {runId, fingerprint, date: today, completed: set, startedAtMillis: null, expiresAtMillis: 0});
    return result('awarded');
  });
}
