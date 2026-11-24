import {requireVerifiedEmail} from '../../platform/auth-context';
import {DomainError} from '../../platform/errors';
import {keyOf} from '../../platform/idempotency';
import {InputValidationError, requiredIdentifier} from '../../platform/validation';
import {readAll, type DocumentData, type DocumentStore} from '../../platform/firestore/store';
import {resolveMembershipEntitlement} from '../commerce/membership-entitlement';
import {resolveExerciseExecution} from '../content/exercise-execution';
import type {RewardAuth} from './reward-command-security';

const points = 10;
const policyVersion = 'workout-exercise-points-v1';
const dayOf = (at: number) => new Date(at + 28800000).toISOString().slice(0, 10);
const id = (value: unknown): value is string => typeof value === 'string' && /^[\w-]{1,128}$/.test(value);
const whole = (value: unknown, min = 0): value is number => Number.isSafeInteger(value) && Number(value) >= min;
const record = (data: unknown): DocumentData =>
  data && typeof data === 'object' && !Array.isArray(data) ? data as DocumentData : {};
const fail = () => new DomainError('failed-precondition', 'Workout points could not be confirmed.');

// These are server-saved fitness logs, not physically verified camera evidence.
function savedBackup(row: DocumentData | undefined, kind: string, ref: string, org: string, uid: string) {
  if (row?.schemaVersion !== 1 || row.classification !== 'provisional_member_backup' ||
      row.kind !== kind || row.id !== ref || row.key !== kind+'-'+ref || typeof row.payloadJson !== 'string') return {};
  try {
    const payload = record(JSON.parse(row.payloadJson));
    return payload.organizationId === org && payload.userId === uid ? payload : {};
  } catch {
    return {};
  }
}

export async function claimAiWorkoutPoints(store: DocumentStore, auth: RewardAuth, raw: DocumentData, clock = Date.now) {
  requireVerifiedEmail(auth);
  if (raw.schemaVersion !== 1 || raw.action !== 'claimAiWorkoutPoints' ||
      Object.keys(raw).sort().join(',') !== 'action,attemptId,organizationId,schemaVersion') {
    throw new InputValidationError('Invalid AI workout points request.');
  }
  const organizationId = requiredIdentifier(raw.organizationId, 'organizationId');
  const attemptId = requiredIdentifier(raw.attemptId, 'attemptId'), memberId = auth.uid;
  const root = `orgs/${organizationId}`, backup = `${root}/members/${memberId}/workoutBackups`;
  return store.transact(async tx => {
    const now = clock();
    await resolveMembershipEntitlement(tx, auth, organizationId, now);
    if ((await tx.get(`${root}/members/${memberId}`))?.role !== 'member') {
      throw new DomainError('permission-denied', 'Active member required.');
    }
    const result = (earned: number, confirmed: number) =>
      ({schemaVersion: 1, organizationId, memberId, attemptId, earned, confirmed});
    const receiptPath = `${root}/workoutPointAiAttempts/${keyOf(memberId, attemptId)}`;
    const prior = await tx.get(receiptPath);
    if (prior) {
      if (prior.organizationId !== organizationId || prior.memberId !== memberId || prior.attemptId !== attemptId ||
          !whole(prior.points, 1) || prior.points % points !== 0) throw fail();
      return result(0, prior.points);
    }
    const payload = savedBackup(await tx.get(backup+'/routine-'+attemptId), 'routine', attemptId, organizationId, memberId);
    const attempt = record(payload.attempt), snapshot = record(attempt.routine);
    const start = Math.floor(Number(attempt.startedAtMicros) / 1000), end = Math.floor(Number(attempt.finishedAtMicros) / 1000);
    const today = dayOf(now);
    if (payload.finished !== true || attempt.finished !== true || !id(payload.routineId) ||
        !whole(start, 1) || !whole(end, start+1) || end > now || dayOf(end) !== today ||
        !Array.isArray(snapshot.exercises) || !Array.isArray(attempt.entries) || attempt.entries.length > 50) return result(0, 0);
    const routineId = payload.routineId;
    const routine = await tx.get(`${root}/content/${routineId}`);
    if (routine?.status !== 'published' || routine.archived === true || routine.isActive === false ||
        !['routine', 'routine_v2'].includes(String(routine.kind)) || !Array.isArray(routine.exercises)) return result(0, 0);
    const currentRows = routine.exercises.map(record);
    const entries = attempt.entries.map(record).filter(entry => entry.status === 'completed' &&
      entry.manualSets === 0 && whole(entry.index) && Array.isArray(entry.sessionIds));
    const refs = [...new Set(entries.flatMap(entry => (entry.sessionIds as unknown[]).filter(id)))];
    if (!refs.length || refs.length > 200) return result(0, 0);
    const sessionRows = await readAll(tx, refs.map(ref=>backup+'/session-'+ref));
    if (sessionRows.some(row=>!row)) throw fail();
    const sessions = new Map(refs.map((ref,i)=>[ref,savedBackup(sessionRows[i], 'session', ref, organizationId, memberId)]));
    const qualified = new Map<string, string>();
    for (const entry of entries) {
      const row = record(snapshot.exercises[Number(entry.index)]);
      const exerciseId = row.exerciseId;
      if (!id(exerciseId) || qualified.has(exerciseId) || row.dayNumber !== payload.day ||
          (row.executionMode !== undefined && row.executionMode !== 'aiTracked')) continue;
      const published = currentRows.find(target=>target.exerciseId === exerciseId && target.dayNumber === row.dayNumber &&
        (row.entryId === undefined || row.entryId === target.entryId));
      if (!published || !whole(published.sets,1) || !whole(published.reps,1) ||
          published.sets !== row.sets || published.reps !== row.reps ||
          (published.executionMode !== undefined && published.executionMode !== 'aiTracked')) continue;
      const exercise = await tx.get(`${root}/exerciseVideos/${exerciseId}`);
      if (exercise?.isActive !== true || exercise.archived === true ||
          resolveExerciseExecution(organizationId,exerciseId,exercise) !== 'aiTracked') continue;
      const requiredSets = published.sets, requiredReps = published.reps;
      const sessionId = (entry.sessionIds as unknown[]).filter(id).find(ref=>{
        const session = sessions.get(ref), metrics = record(session?.poseMetrics), curl = record(metrics.curlArms);
        if (session?.sessionId !== ref || session.provenance !== 'realCamera' || session.exerciseId !== exerciseId ||
            metrics.publishedRoutineId !== routineId) return false;
        const s = Date.parse(String(session.startedAt)), e = Date.parse(String(session.endedAt));
        if (!whole(s,start) || !whole(e,s+1) || e > end || dayOf(e) !== today) return false;
        if (metrics.curlArms) return whole(curl.completedSets,requiredSets) && whole(curl.repetitionsPerArm,requiredReps);
        return whole(session.repetitions,requiredSets*requiredReps);
      });
      if (sessionId) qualified.set(exerciseId,sessionId);
    }
    const candidates = [...qualified].map(([exerciseId, sessionId]) => {
      const awardId = 'workout_' + keyOf(memberId,exerciseId,today);
      return {exerciseId, sessionId, awardId, path: `${root}/workoutPointExercises/${awardId}`};
    });
    const existing = await readAll(tx,candidates.map(candidate=>candidate.path));
    const fresh = candidates.filter((_,i)=>!existing[i]);
    if (!fresh.length) return result(0, 0);
    const earned = fresh.length * points;
    const dailyAwardId = 'workout_day_' + keyOf(memberId,today);
    const dailyPath = `${root}/rewardAwards/${dailyAwardId}`, balancePath = `${root}/rewardBalances/${memberId}`;
    const [daily,balance] = await readAll(tx,[dailyPath,balancePath]);
    if (daily && (daily.schemaVersion !== 1 || daily.awardId !== dailyAwardId || daily.date !== today ||
        daily.memberId !== memberId || daily.organizationId !== organizationId ||
        daily.policyVersion !== policyVersion || !whole(daily.points,1) || daily.basePoints !== daily.points ||
        daily.premiumBonus !== false)) throw fail();
    if (balance && (balance.schemaVersion !== 1 || balance.memberId !== memberId ||
        balance.organizationId !== organizationId || !whole(balance.points) || !Array.isArray(balance.recentRedemptionIds))) throw fail();
    const dailyTotal = Number(daily?.points ?? 0)+earned, balanceTotal = Number(balance?.points ?? 0)+earned;
    if (!whole(dailyTotal) || !whole(balanceTotal)) throw fail();
    for (const candidate of fresh) tx.create(candidate.path, {schemaVersion: 1, organizationId, memberId,
      awardId: candidate.awardId, exerciseId: candidate.exerciseId, sessionId: candidate.sessionId, date: today,
      routineId, attemptId, awardedAtMillis: now, points, dailyAwardId});
    tx.create(receiptPath,{schemaVersion: 1, organizationId, memberId, attemptId, points: earned, awardedAtMillis: now});
    tx.set(dailyPath,{schemaVersion: 1, organizationId, memberId, awardId: dailyAwardId, eventId: dailyAwardId,
      date: today, sourceId: 'routine_completion', producerVersion: 'workout-points-v1', policyVersion,
      occurredAtMillis: now, awardedAtMillis: now, points: dailyTotal, basePoints: dailyTotal, premiumBonus: false});
    tx.set(balancePath,{...balance,schemaVersion: 1, organizationId, memberId, points: balanceTotal,
      recentRedemptionIds: balance?.recentRedemptionIds ?? [], updatedAtMillis: now});
    return result(earned, earned);
  });
}
