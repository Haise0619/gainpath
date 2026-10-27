import {DomainError} from '../../platform/errors';
import {requireVerifiedEmail} from '../../platform/auth-context';
import {InputValidationError, requiredIdentifier} from '../../platform/validation';
import {readAll, type DocumentStore, type DocumentData} from '../../platform/firestore/store';
import {validateBackupPayload, digestOf} from '../workouts/workout-backup-validation';
import {authorizeAdminReport, type ReportRow} from './admin-reporting';

type Auth = {uid: string; token: Record<string, unknown>};
export interface WorkoutReportReader {
  members(after: string | undefined, limit: number): Promise<ReportRow[]>;
  backups(memberId: string, after: string | undefined, limit: number): Promise<ReportRow[]>;
}
export const WORKOUT_REPORT_LIMITS = {members: 2000, eligibleMembers: 200, backups: 2000, bytes: 16 * 1024 * 1024};
const DAY = 86400000, OFFSET = 8 * 3600000;
const integer = (n: unknown): n is number => Number.isSafeInteger(n) && Number(n) >= 0;
const fail = () => new DomainError('failed-precondition', 'Workout backup sources need authorized review. No partial totals were returned.');
const cap = () => new DomainError('resource-exhausted', 'Workout analytics exceeds its bounded scan limit. No partial totals were returned.');
const date = (millis: number) => new Date(millis + OFFSET).toISOString().slice(0, 10);
export const emptyWorkoutTotals = () => ({sessions: 0, fullReps: 0, partialReps: 0, trackedMicros: 0,
  routineAttempts: 0, completedRoutineDays: 0, partialRoutineDays: 0, inProgressRoutineDays: 0, unknownCompletionDays: 0, manualSets: 0});
type Totals = ReturnType<typeof emptyWorkoutTotals>;
type Form = {exerciseId: string; scoringVersion: string; detectorId: string; detectorVersion: string; cameraView: string; armMode: string;
  scoredSessions: number; scoreSum: number; daily: {date: string; scoredSessions: number; scoreSum: number}[]};
type Exercise = {exerciseId: string; name: string; sessions: number; fullReps: number; partialReps: number; trackedMicros: number; manualSets: number};
export interface WorkoutReport {
  schemaVersion: 1; organizationId: string; startAtMillis: number; endAtMillis: number;
  sourceReadStartedAtMillis: number; capturedAtMillis: number; timezone: 'Asia/Kuala_Lumpur'; classification: 'provisional_member_backup';
  coverage: {membersScanned: number; activeMembers: number; membersWithBackups: number; membersWithActivity: number; backupRecords: number; bytesRead: number};
  totals: Totals; daily: ({date: string} & Totals)[]; exercises: Exercise[]; forms: Form[];
}
function checkPage(rows: ReportRow[], after: string | undefined, limit: number, pattern: RegExp) {
  if (!Array.isArray(rows) || rows.length > limit) throw fail();
  let previous = after;
  for (const row of rows) {
    if (!row || typeof row.id !== 'string' || !pattern.test(row.id) || (previous !== undefined && row.id <= previous) ||
        !row.data || typeof row.data !== 'object' || Array.isArray(row.data)) throw fail();
    previous = row.id;
  }
}

export async function adminWorkoutReport(store: DocumentStore, auth: Auth | undefined, raw: unknown, reader: WorkoutReportReader, clock: () => number = Date.now): Promise<WorkoutReport> {
  requireVerifiedEmail(auth);
  const q = raw as DocumentData, now = clock();
  if (!q || typeof q !== 'object' || Array.isArray(q) || Object.keys(q).length !== 4 || q.schemaVersion !== 1 ||
      !integer(now) || now > 8640000000000000 - DAY || !integer(q.startAtMillis) || !integer(q.endAtMillis) ||
      q.startAtMillis >= q.endAtMillis || q.endAtMillis > now + DAY) throw new InputValidationError('Invalid workout report query.');
  const org = requiredIdentifier(q.organizationId, 'organizationId');
  const authorize = () => store.transact(tx => authorizeAdminReport(tx, auth!, org));
  await authorize();
  const result: WorkoutReport = {schemaVersion: 1, organizationId: org, startAtMillis: q.startAtMillis, endAtMillis: q.endAtMillis,
    sourceReadStartedAtMillis: now, capturedAtMillis: now, timezone: 'Asia/Kuala_Lumpur', classification: 'provisional_member_backup',
    coverage: {membersScanned: 0, activeMembers: 0, membersWithBackups: 0, membersWithActivity: 0, backupRecords: 0, bytesRead: 0},
    totals: emptyWorkoutTotals(), daily: [], exercises: [], forms: []};
  const memberRows: ReportRow[] = [];
  let after: string | undefined;
  do {
    const rows = await reader.members(after, 251);
    checkPage(rows, after, 251, /^[A-Za-z0-9_-]{1,128}$/);
    for (const row of rows) {
      if (row.data.organizationId !== org) throw fail();
      memberRows.push(row); if (memberRows.length > WORKOUT_REPORT_LIMITS.members) throw cap();
    }
    if (rows.length < 251) break;
    after = rows.at(-1)!.id;
  } while (true);
  result.coverage.membersScanned = memberRows.length;
  const candidates = memberRows.filter(r => r.data.status === 'active' && r.data.role === 'member');
  const eligible: string[] = [];
  for (let offset = 0; offset < candidates.length; offset += 100) {
    const batch = candidates.slice(offset, offset + 100);
    const users = await store.transact(async tx => {await authorizeAdminReport(tx, auth!, org); return readAll(tx, batch.map(r => `users/${r.id}`));});
    for (let i = 0; i < batch.length; i++) {
      const u = users[i], m = batch[i], lifecycle = u?.accountLifecycle as DocumentData | undefined;
      if (u?.organizationId === org && (u.role === undefined || u.role === 'member') &&
          (m.data.userId === undefined || m.data.userId === m.id) &&
          (lifecycle === undefined || (lifecycle?.state === 'active' && lifecycle.revocationPending === false))) eligible.push(m.id);
    }
  }
  if (eligible.length > WORKOUT_REPORT_LIMITS.eligibleMembers) throw cap();
  result.coverage.activeMembers = eligible.length;
  const days = new Map<string, {date: string} & Totals>(), exercises = new Map<string, Exercise>(), forms = new Map<string, Form>();
  const from = Number(q.startAtMillis), until = Number(q.endAtMillis);
  const inRange = (t: number) => t >= from && t < until && t <= now;
  const bucket = (t: number) => {const d = date(t); if (!days.has(d)) days.set(d, {date: d, ...emptyWorkoutTotals()}); return days.get(d)!;};
  const add = (d: Totals, key: keyof Totals, n = 1) => {
    result.totals[key] += n; d[key] += n;
    if (!integer(result.totals[key]) || !integer(d[key])) throw fail();
  };
  const exercise = (id: string) => {
    if (!exercises.has(id)) exercises.set(id, {exerciseId: id, name: id, sessions: 0, fullReps: 0, partialReps: 0, trackedMicros: 0, manualSets: 0});
    return exercises.get(id)!;
  };
  for (const uid of eligible) {
    let cursor: string | undefined, hasBackups = false, hasActivity = false;
    do {
      const rows = await reader.backups(uid, cursor, 25);
      checkPage(rows, cursor, 25, /^(session|routine)-[A-Za-z0-9_-]{1,128}$/);
      for (const row of rows) {
        const b = row.data;
        result.coverage.backupRecords++;
        if (result.coverage.backupRecords > WORKOUT_REPORT_LIMITS.backups) throw cap();
        if (b.schemaVersion !== 1 || b.classification !== 'provisional_member_backup' || !['session', 'routine'].includes(String(b.kind)) ||
            b.key !== row.id || b.key !== `${b.kind}-${b.id}` || typeof b.payloadJson !== 'string' || !integer(b.updatedAtMillis)) throw fail();
        result.coverage.bytesRead += Buffer.byteLength(b.payloadJson, 'utf8');
        if (result.coverage.bytesRead > WORKOUT_REPORT_LIMITS.bytes) throw cap();
        let p: DocumentData;
        try {
          p = validateBackupPayload(String(b.kind), String(b.id), org, uid, JSON.parse(b.payloadJson));
          if (digestOf(p) !== b.digest) throw fail();
        } catch (_) {throw fail();}
        hasBackups = true;
        if (b.kind === 'session') {
          const ended = Date.parse(String(p.endedAt));
          if (!inRange(ended)) continue;
          hasActivity = true;
          const m = p.poseMetrics as DocumentData, d = bucket(ended), e = exercise(String(p.exerciseId));
          add(d, 'sessions'); e.sessions++;
          for (const [key, value] of [['fullReps', p.repetitions], ['partialReps', m.partialRepetitions], ['trackedMicros', m.trackedDurationMicros]] as const) {
            add(d, key, Number(value)); e[key] += Number(value);
          }
          if (m.formScorePercent !== null) {
            const armMode = m.schemaVersion === 2 ? String((m.curlArms as DocumentData).mode) : 'not_applicable';
            const key = JSON.stringify([p.exerciseId, m.scoringVersion, m.detectorId, m.detectorVersion, m.cameraView, armMode]);
            if (!forms.has(key)) forms.set(key, {exerciseId: String(p.exerciseId), scoringVersion: String(m.scoringVersion), detectorId: String(m.detectorId),
              detectorVersion: String(m.detectorVersion), cameraView: String(m.cameraView), armMode, scoredSessions: 0, scoreSum: 0, daily: []});
            const f = forms.get(key)!, score = Number(m.formScorePercent);
            f.scoredSessions++; f.scoreSum += score;
            let fd = f.daily.find(v => v.date === d.date);
            if (!fd) {fd = {date: d.date, scoredSessions: 0, scoreSum: 0}; f.daily.push(fd);}
            fd.scoredSessions++; fd.scoreSum += score;
          }
        } else {
          const a = p.attempt as DocumentData, entries = a.entries as DocumentData[];
          // Backup compatibility accepts older checkpoints; analytics also requires
          // consistent attribution times before any attempt/manual totals are used.
          const updated = Number(a.updatedAtMicros);
          if ((a.startedAtMicros !== null && Number(a.startedAtMicros) > updated) ||
              (a.finishedAtMicros !== null && Number(a.finishedAtMicros) > updated)) throw fail();
          // Valid future device-clock records remain storage coverage, not activity.
          if (Number(p.updatedAtMicros) / 1000 > now || updated / 1000 > now) continue;
          // Unstarted checkpoints are storage presence, not workout attempts.
          if (a.startedAtMicros === null && !a.finished && entries.every(e => e.status === 'notStarted')) continue;
          const at = Number(a.finishedAtMicros ?? a.updatedAtMicros) / 1000;
          if (!inRange(at)) continue;
          hasActivity = true;
          const d = bucket(at);
          add(d, 'routineAttempts');
          const complete = entries.every(e => ['completed', 'selfReportedCompleted'].includes(String(e.status)));
          const state = !a.finished ? 'inProgressRoutineDays' : complete && a.finishedAtMicros === null ? 'unknownCompletionDays' : complete ? 'completedRoutineDays' : 'partialRoutineDays';
          add(d, state);
          const plan = (a.routine as DocumentData).exercises as DocumentData[];
          for (const entry of entries) {
            const source = plan[Number(entry.index)], e = exercise(String(source.exerciseId));
            if (e.name === e.exerciseId && source.name) e.name = String(source.name).slice(0, 100);
            add(d, 'manualSets', Number(entry.manualSets)); e.manualSets += Number(entry.manualSets);
          }
        }
      }
      if (rows.length < 25) break;
      cursor = rows.at(-1)!.id;
    } while (true);
    if (hasBackups) result.coverage.membersWithBackups++;
    if (hasActivity) result.coverage.membersWithActivity++;
  }
  await authorize();
  result.capturedAtMillis = clock();
  if (!integer(result.capturedAtMillis) || result.capturedAtMillis < now || result.capturedAtMillis > 8640000000000000) throw fail();
  result.daily = [...days.values()].sort((a, b) => a.date.localeCompare(b.date));
  result.exercises = [...exercises.values()].filter(e => e.sessions > 0 || e.manualSets > 0).sort((a, b) => b.sessions - a.sessions || b.manualSets - a.manualSets || a.exerciseId.localeCompare(b.exerciseId));
  result.forms = [...forms.entries()].sort(([a], [b]) => a.localeCompare(b)).map(([, f]) => ({...f, daily: f.daily.sort((a, b) => a.date.localeCompare(b.date))}));
  return result;
}
