import { requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import type { DocumentData, DocumentStore } from '../../platform/firestore/store';
import { readAll } from '../../platform/firestore/store';
import { keyOf } from '../../platform/idempotency';
import { InputValidationError, requiredIdentifier } from '../../platform/validation';
import { allowed, bookingPolicy, branchIds, dateGrid, integer, localDate, object, plusDate, type AvailabilityWindow } from './coach-availability-contracts';
import { activeCoachLocks, assertLockCoverage, coverage, maskWindows, resolveRosterDay, rosterExceptions, rosterReview, storedRoster, weeklyAvailability, type CoachRoster, type RosterException } from './coach-roster-contracts';
import { currentBookingMembership, requireBookingOrganization } from './booking-validation';

type Auth = { uid: string; token: Record<string, unknown> } | undefined;
export interface CoachRosterResult extends CoachRoster {
  schemaVersion: 1; coachId: string; serverNowMillis: number; todayLocalDate: string; timeZone: string;
  policyVersion: string; throughLocalDate: string; assignedBranchIds: string[];
  exceptions: (RosterException & { startLabel?: string; endLabel?: string })[];
}
function context(auth: Auth, raw: unknown, keys: readonly string[]) {
  requireVerifiedEmail(auth); const input = object(raw); allowed(input, keys);
  if (input.schemaVersion !== 1) throw new InputValidationError('schemaVersion must be 1.');
  return { input, uid: requiredIdentifier(auth!.uid, 'actorId'), org: requiredIdentifier(input.organizationId, 'organizationId') };
}
function snapshot(coachId: string, roster: CoachRoster, now: number, policy: ReturnType<typeof bookingPolicy>, assignedBranchIds: string[]): CoachRosterResult {
  const todayLocalDate = localDate(now, policy.timeZone);
  const formatter = new Intl.DateTimeFormat('en-GB', { timeZone: policy.timeZone, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hourCycle: 'h23', timeZoneName: 'shortOffset' });
  return { schemaVersion: 1, coachId, ...roster, exceptions: roster.exceptions.map(e => ({ ...e, startLabel: formatter.format(e.startAtMillis), endLabel: formatter.format(e.endAtMillis) })), serverNowMillis: now, todayLocalDate, timeZone: policy.timeZone,
    policyVersion: policy.policyVersion, throughLocalDate: plusDate(todayLocalDate, 30), assignedBranchIds };
}
export async function getCoachRosterService(store: DocumentStore, auth: Auth, raw: unknown, clock = Date.now): Promise<CoachRosterResult> {
  const { input, uid, org } = context(auth, raw, ['schemaVersion', 'organizationId', 'coachId']);
  const coachId = requiredIdentifier(input.coachId, 'coachId'), root = `orgs/${org}`;
  return store.transact(async tx => {
    const actor = await currentBookingMembership(tx, org, uid);
    if (actor.role !== 'admin' && !(actor.role === 'coach' && uid === coachId)) throw new DomainError('permission-denied', 'Only the Coach or organization Admin can read this roster.');
    await requireBookingOrganization(tx, org);
    const coach = await currentBookingMembership(tx, org, coachId);
    if (coach.role !== 'coach') throw new DomainError('failed-precondition', 'Coach roster unavailable.');
    const assigned = branchIds(coach.branchIds), policy = bookingPolicy(await tx.get(`${root}/settings/booking`));
    return snapshot(coachId, storedRoster(await tx.get(`${root}/coachAvailability/${coachId}`), policy.timeZone, assigned), clock(), policy, assigned);
  });
}
function receiptResult(receipt: DocumentData, uid: string, fingerprint: string): CoachRosterResult {
  if (receipt.fingerprint !== fingerprint) throw new DomainError('already-exists', 'The request ID belongs to another roster edit.');
  try {
    if (receipt.schemaVersion !== 1 || receipt.command !== 'saveCoachRoster' || receipt.actorId !== uid) throw Error();
    const r = object(receipt.result);
    allowed(r, ['schemaVersion', 'coachId', 'revision', 'weeklyAvailability', 'exceptions', 'serverNowMillis', 'todayLocalDate', 'timeZone', 'policyVersion', 'throughLocalDate', 'assignedBranchIds']);
    if (r.schemaVersion !== 1 || r.coachId !== uid || typeof r.timeZone !== 'string' || typeof r.policyVersion !== 'string' || !r.policyVersion) throw Error();
    const now = integer(r.serverNowMillis, 1), assigned = branchIds(r.assignedBranchIds);
    if (!Array.isArray(r.exceptions)) throw Error();
    const exceptions = r.exceptions.map(value => {
      const e = object(value); allowed(e, ['id', 'type', 'reason', 'startAtMillis', 'endAtMillis', 'startLabel', 'endLabel']);
      for (const key of ['startLabel', 'endLabel']) if (e[key] !== undefined && (typeof e[key] !== 'string' || String(e[key]).length > 256)) throw Error();
      const { startLabel: _start, endLabel: _end, ...canonical } = e;
      return canonical;
    });
    storedRoster({ schemaVersion: 1, revision: r.revision, weeklyAvailability: r.weeklyAvailability, exceptions, timeZone: r.timeZone, policyVersion: r.policyVersion, createdAtMillis: now, updatedAtMillis: now }, r.timeZone, assigned);
    if (r.todayLocalDate !== localDate(now, r.timeZone) || r.throughLocalDate !== plusDate(String(r.todayLocalDate), 30)) throw Error();
    return structuredClone(r) as unknown as CoachRosterResult;
  } catch { throw rosterReview(); }
}
export async function saveCoachRosterService(store: DocumentStore, auth: Auth, raw: unknown, clock = Date.now): Promise<CoachRosterResult> {
  const { input, uid, org } = context(auth, raw, ['schemaVersion', 'organizationId', 'requestId', 'expectedRevision', 'expectedPolicyVersion', 'expectedTimeZone', 'expectedCoachBranchIds', 'weeklyAvailability', 'exceptions']);
  const requestId = requiredIdentifier(input.requestId, 'requestId'), expected = integer(input.expectedRevision, 0, Number.MAX_SAFE_INTEGER - 2), expectedBranches = branchIds(input.expectedCoachBranchIds);
  if (typeof input.expectedPolicyVersion !== 'string' || typeof input.expectedTimeZone !== 'string') throw new InputValidationError('Original scheduling policy is required.');
  const expectedPolicyVersion = input.expectedPolicyVersion, expectedTimeZone = input.expectedTimeZone;
  const weekly = weeklyAvailability(input.weeklyAvailability, expectedBranches), exceptions = rosterExceptions(input.exceptions);
  if (!weekly) throw new InputValidationError('A complete weekly configuration is required.');
  const fingerprint = keyOf(org, expected, expectedPolicyVersion, expectedTimeZone, expectedBranches, weekly, exceptions);
  const root = `orgs/${org}`, parentPath = `${root}/coachAvailability/${uid}`, receiptPath = `${root}/commandReceipts/${keyOf('saveCoachRoster', uid, requestId)}`;
  return store.transact(async tx => {
    const actor = await currentBookingMembership(tx, org, uid);
    if (actor.role !== 'coach') throw new DomainError('permission-denied', 'Only the current Coach can edit their roster.');
    await requireBookingOrganization(tx, org);
    const assigned = branchIds(actor.branchIds);
    for (const branch of assigned) if ((await tx.get(`${root}/branches/${branch}`))?.status !== 'active') throw new DomainError('failed-precondition', 'Assigned branch unavailable.');
    const receipt = await tx.get(receiptPath);
    if (receipt) return receiptResult(receipt, uid, fingerprint);
    if (JSON.stringify(assigned) !== JSON.stringify(expectedBranches)) throw new DomainError('aborted', 'Coach branches changed. Discard and reload.');
    const policy = bookingPolicy(await tx.get(`${root}/settings/booking`));
    if (policy.policyVersion !== expectedPolicyVersion || policy.timeZone !== expectedTimeZone) throw new DomainError('aborted', 'Scheduling policy changed. Discard and reload.');
    const current = await tx.get(parentPath), old = storedRoster(current, policy.timeZone, assigned), now = clock(), today = localDate(now, policy.timeZone), through = plusDate(today, 30);
    if (old.revision !== expected) throw new DomainError('aborted', 'The roster changed. Discard and reload.');
    const changed = exceptions.filter(e => JSON.stringify(e) !== JSON.stringify(old.exceptions.find(previous => previous.id === e.id)));
    for (const e of changed) if (e.startAtMillis <= now || localDate(e.startAtMillis, policy.timeZone) < today || localDate(e.endAtMillis - 1, policy.timeZone) > through) throw new InputValidationError('New or edited exceptions must be future times within 30 days.');
    const next: CoachRoster = { revision: expected + 1, weeklyAvailability: weekly, exceptions };
    const scheduleChanged = JSON.stringify(old.weeklyAvailability?.schedule) !== JSON.stringify(weekly.schedule);
    const alteredRanges = [...old.exceptions, ...exceptions].filter(e => JSON.stringify(old.exceptions.find(v => v.id === e.id)) !== JSON.stringify(exceptions.find(v => v.id === e.id)));
    const rangeTouches = (date: string) => alteredRanges.some(e => localDate(e.startAtMillis, policy.timeZone) <= date && localDate(e.endAtMillis - 1, policy.timeZone) >= date);
    const dates = Array.from({ length: 31 }, (_, i) => plusDate(today, i)).filter(date => scheduleChanged || rangeTouches(date));
    const days = await readAll(tx, dates.map(date => `${parentPath}/days/${date}`));
    const affected = dates.flatMap((date, i) => {
      const before = resolveRosterDay(days[i], date, policy.timeZone, assigned, old), after = resolveRosterDay(days[i], date, policy.timeZone, assigned, next);
      if (!rangeTouches(date) && JSON.stringify(before.windows) === JSON.stringify(after.windows)) return [];
      return [{ date, data: days[i], before, after, grid: dateGrid(date, policy.timeZone) }];
    });
    // Only coverage edits need lock reads. The parent read still serializes a
    // limits-only update against checkout, without scanning reservation records.
    // Missing affected locks are read too, preventing concurrent allocation gaps.
    const locks = await activeCoachLocks(tx, root, uid, affected.flatMap(day => day.grid.slots), now);
    const pins: { path: string; windows: AvailabilityWindow[]; revision: number; createdAtMillis: unknown }[] = [];
    for (const { date, data, before, after, grid } of affected) {
      const occupied = new Map(grid.slots.filter(slot => locks.has(slot)).map(slot => [slot, locks.get(slot)!]));
      assertLockCoverage(before.windows, occupied);
      if (before.reviewRequired && occupied.size) throw rosterReview();
      for (const [slot] of occupied) if (changed.some(e => e.startAtMillis < slot + 1800000 && e.endAtMillis > slot)) throw new DomainError('aborted', 'An exception overlaps reserved Coach time.');
      if ([...occupied].some(([slot, branch]) => coverage(after.windows, slot) !== branch)) {
        // Retain a genuine dated baseline, never manufacture availability from
        // reservation locks. Existing dated overrides already have priority.
        assertLockCoverage(maskWindows(before.baseWindows, exceptions), occupied);
        pins.push({ path: `${parentPath}/days/${date}`, windows: before.baseWindows, revision: before.revision + 1, createdAtMillis: data?.createdAtMillis ?? now });
      }
    }
    const result = snapshot(uid, next, now, policy, assigned);
    for (const pin of pins) tx.set(pin.path, { schemaVersion: 1, windows: pin.windows, revision: pin.revision, timeZone: policy.timeZone, policyVersion: policy.policyVersion, createdAtMillis: pin.createdAtMillis, updatedAtMillis: now });
    tx.set(parentPath, { schemaVersion: 1, ...next, timeZone: policy.timeZone, policyVersion: policy.policyVersion, createdAtMillis: current?.createdAtMillis ?? now, updatedAtMillis: now });
    tx.create(receiptPath, { schemaVersion: 1, command: 'saveCoachRoster', actorId: uid, fingerprint, createdAtMillis: now, result });
    return result;
  });
}
