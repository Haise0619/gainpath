import { requireActiveMembership, requireVerifiedEmail } from '../../platform/auth-context';
import type { DocumentStore, TransactionPort } from '../../platform/firestore/store';
import { readAll } from '../../platform/firestore/store';
import { prefetchReads } from '../../platform/firestore/prefetch-reads';
import { DomainError } from '../../platform/errors';
import { keyOf } from '../../platform/idempotency';
import { InputValidationError, requiredIdentifier } from '../../platform/validation';
import { allowed, branchIds, bookingPolicy, dateEpoch, dateGrid, integer, localDate, normalizeWindows, object, plusDate, SLOT, type AvailabilityWindow, type TimeBoundary } from './coach-availability-contracts';
import { maskWindows, resolveRosterDay, storedRoster } from './coach-roster-contracts';
export { getCoachRosterService, saveCoachRosterService } from './coach-roster-service';

type Auth = { uid: string; token: Record<string, unknown> } | undefined;
export interface AvailabilityDayResult { localDate: string; windows: AvailabilityWindow[]; revision?: number; editable?: boolean; reviewRequired?: boolean; boundaries?: TimeBoundary[]; displayTimes?: TimeBoundary[] }
export interface AvailabilityContextResult { schemaVersion: 1; coachId: string; serverNowMillis: number; todayLocalDate: string; timeZone: string; policyVersion?: string; rosterRevision?: number; writableFromLocalDate?: string; writableThroughLocalDate?: string; assignedBranchIds: string[]; days: AvailabilityDayResult[] }
export interface AvailabilitySaveResult { schemaVersion: 1; requestId: string; coachId: string; localDate: string; revision: number; outcome: 'saved' | 'removed' }
function context(auth: Auth, raw: unknown, keys: string[]) {
  requireVerifiedEmail(auth); const input = object(raw); allowed(input, keys);
  if (input.schemaVersion !== 1) throw new InputValidationError('schemaVersion must be 1.');
  return { input, uid: requiredIdentifier(auth!.uid, 'actorId'), org: requiredIdentifier(input.organizationId, 'organizationId') };
}
async function membership(tx: TransactionPort, org: string, uid: string) {
  const user = await tx.get(`users/${uid}`), data = await tx.get(`orgs/${org}/members/${uid}`);
  const member = requireActiveMembership(data);
  if (user?.organizationId !== org || data?.organizationId !== org) throw new DomainError('permission-denied', 'Current organization access is required.');
  return { ...member, branchIds: member.role === 'admin' && member.branchIds.length === 0 ? [] : branchIds(member.branchIds) };
}
async function activeBranches(tx: TransactionPort, root: string, ids: readonly string[], required: boolean) {
  const active: string[] = [];
  const records = await readAll(tx, ids.map(id => `${root}/branches/${id}`));
  for (const [i, id] of ids.entries()) {
    if (records[i]?.status === 'active') active.push(id);
    else if (required) throw new DomainError('failed-precondition', 'Assigned branch unavailable.');
  }
  return active;
}
export async function getCoachAvailabilityService(store: DocumentStore, auth: Auth, raw: unknown, clock = Date.now): Promise<AvailabilityContextResult> {
  const { input, uid, org } = context(auth, raw, ['schemaVersion', 'organizationId', 'coachId', 'firstLocalDate', 'dayCount']);
  const coachId = requiredIdentifier(input.coachId, 'coachId'), count = integer(input.dayCount, 1, 7), root = `orgs/${org}`;
  return store.transact(async tx => {
    const facts = await prefetchReads(tx, [
      `users/${uid}`, `${root}/members/${uid}`, root, `${root}/settings/booking`,
      `users/${coachId}`, `${root}/members/${coachId}`,
    ]);
    const actor = await membership(facts, org, uid);
    if (!['member', 'coach', 'admin'].includes(actor.role) || (actor.role === 'coach' && uid !== coachId)) throw new DomainError('permission-denied', 'Schedule access is unavailable for this account.');
    if ((await facts.get(root))?.status !== 'active') throw new DomainError('failed-precondition', 'Organization unavailable.');
    const policy = bookingPolicy(await facts.get(`${root}/settings/booking`)), now = clock(), today = localDate(now, policy.timeZone);
    const first = input.firstLocalDate === undefined ? today : String(input.firstLocalDate); dateEpoch(first);
    const through = plusDate(today, 30);
    if (first < today || first > through) throw new InputValidationError('Read a date within the scheduling horizon.');
    let coach;
    // A self-reading Coach already passed these exact checks in this snapshot.
    try { coach = actor.role === 'coach' ? actor : await membership(facts, org, coachId); }
    catch { throw new DomainError('failed-precondition', 'Coach schedule unavailable.'); }
    if (coach.role !== 'coach') throw new DomainError('failed-precondition', 'Coach schedule unavailable.');
    const dates = Array.from({ length: count }, (_, i) => plusDate(first, i)).filter(date => date <= through);
    const details = await prefetchReads(tx, [
      ...coach.branchIds.map(id => `${root}/branches/${id}`),
      ...(actor.role === 'member' ? [`${root}/coaches/${coachId}`] : []),
      `${root}/coachAvailability/${coachId}`,
      ...dates.map(date => `${root}/coachAvailability/${coachId}/days/${date}`),
    ]);
    const active = await activeBranches(details, root, coach.branchIds, actor.role === 'coach');
    let visible = active;
    if (actor.role === 'member') {
      const publication = await details.get(`${root}/coaches/${coachId}`);
      if (publication?.status !== 'published' || !Array.isArray(publication.branchIds)) throw new DomainError('failed-precondition', 'Coach schedule is not published.');
      const publishedBranches = publication.branchIds;
      visible = active.filter(id => actor.branchIds.includes(id) && publishedBranches.includes(id));
    }
    if (!visible.length) throw new DomainError('permission-denied', 'No permitted Coach branches are available.');
    const days: AvailabilityDayResult[] = [];
    const [rosterData, ...records] = await readAll(details, [
      `${root}/coachAvailability/${coachId}`,
      ...dates.map(date => `${root}/coachAvailability/${coachId}/days/${date}`),
    ]);
    const roster = storedRoster(rosterData, policy.timeZone, coach.branchIds);
    for (const [i, date] of dates.entries()) {
      const stored = resolveRosterDay(records[i], date, policy.timeZone, coach.branchIds, roster);
      const beyondAdvanceWindow = actor.role === 'member' && date > plusDate(today, roster.weeklyAvailability?.advanceBookingWindowDays ?? 30);
      const day: AvailabilityDayResult = { localDate: date, windows: (beyondAdvanceWindow ? [] : actor.role === 'member' ? stored.windows : stored.baseWindows).filter(w => visible.includes(w.branchId)) };
      const grid = dateGrid(date, policy.timeZone), visibleEndpoints = new Set(day.windows.flatMap(w => [w.startAtMillis, w.endAtMillis]));
      day.displayTimes = grid.boundaries.filter(b => visibleEndpoints.has(b.atMillis));
      if (actor.role !== 'member') Object.assign(day, { revision: stored.revision, reviewRequired: stored.reviewRequired, editable: actor.role === 'coach' && date > today && !stored.reviewRequired, boundaries: actor.role === 'coach' ? grid.boundaries : [] });
      days.push(day);
    }
    return { schemaVersion: 1, coachId, serverNowMillis: now, todayLocalDate: today, timeZone: policy.timeZone, assignedBranchIds: visible, days,
      ...(actor.role === 'member' ? {} : { policyVersion: policy.policyVersion, ...(rosterData ? { rosterRevision: roster.revision } : {}), writableFromLocalDate: plusDate(today, 1), writableThroughLocalDate: through }) };
  });
}
export async function saveCoachAvailabilityDayService(store: DocumentStore, auth: Auth, raw: unknown, clock = Date.now): Promise<AvailabilitySaveResult> {
  const { input, uid, org } = context(auth, raw, ['schemaVersion', 'organizationId', 'requestId', 'localDate', 'expectedRevision', 'expectedRosterRevision', 'expectedPolicyVersion', 'expectedTimeZone', 'expectedCoachBranchIds', 'windows']);
  const requestId = requiredIdentifier(input.requestId, 'requestId'), date = String(input.localDate); dateEpoch(date);
  const expected = integer(input.expectedRevision, 0, Number.MAX_SAFE_INTEGER - 1), expectedBranches = branchIds(input.expectedCoachBranchIds);
  if (typeof input.expectedPolicyVersion !== 'string' || typeof input.expectedTimeZone !== 'string') throw new InputValidationError('Original scheduling policy is required.');
  const expectedPolicyVersion = input.expectedPolicyVersion, expectedTimeZone = input.expectedTimeZone;
  const expectedRosterRevision = input.expectedRosterRevision === undefined ? 0 : integer(input.expectedRosterRevision, 0, Number.MAX_SAFE_INTEGER - 1);
  const root = `orgs/${org}`, path = `${root}/coachAvailability/${uid}/days/${date}`;
  // Canonical inputs and expectations live outside the retryable callback.
  const submitted = normalizeWindows(input.windows, date, expectedTimeZone, expectedBranches);
  // Preserve fingerprints of pre-roster commands when their revision is zero.
  const fingerprintParts = [org, date, expected, expectedPolicyVersion, expectedTimeZone, expectedBranches, submitted];
  const fingerprint = keyOf(...fingerprintParts, ...(expectedRosterRevision ? [expectedRosterRevision] : []));
  const receiptPath = `${root}/commandReceipts/${keyOf('saveCoachAvailabilityDay', uid, requestId)}`;
  return store.transact(async tx => {
    const actor = await membership(tx, org, uid);
    if (actor.role !== 'coach') throw new DomainError('permission-denied', 'Only the current Coach can edit their schedule.');
    if ((await tx.get(root))?.status !== 'active') throw new DomainError('failed-precondition', 'Organization unavailable.');
    await activeBranches(tx, root, actor.branchIds, true);
    if (JSON.stringify(actor.branchIds) !== JSON.stringify(expectedBranches)) throw new DomainError('aborted', 'Coach branches changed. Discard and reload.');
    const receipt = await tx.get(receiptPath);
    if (receipt) {
      if (receipt.fingerprint !== fingerprint) throw new DomainError('already-exists', 'The request ID belongs to another schedule edit.');
      if (receipt.schemaVersion !== 1 || !receipt.result) throw new DomainError('failed-precondition', 'Schedule receipt requires review.');
      return receipt.result as AvailabilitySaveResult;
    }
    const policy = bookingPolicy(await tx.get(`${root}/settings/booking`)), now = clock(), today = localDate(now, policy.timeZone);
    if (policy.policyVersion !== expectedPolicyVersion || policy.timeZone !== expectedTimeZone) throw new DomainError('aborted', 'Scheduling policy changed. Discard and reload.');
    if (date <= today || date > plusDate(today, 30)) throw new InputValidationError('Only tomorrow through 30 days ahead can be edited.');
    const roster = storedRoster(await tx.get(`${root}/coachAvailability/${uid}`), policy.timeZone, actor.branchIds);
    if (roster.revision !== expectedRosterRevision) throw new DomainError('aborted', 'The roster changed. Discard and reload.');
    const current = await tx.get(path), baseline = resolveRosterDay(current, date, policy.timeZone, actor.branchIds, roster);
    if (baseline.reviewRequired) throw new DomainError('failed-precondition', 'Legacy schedule requires authorized review.');
    if (baseline.revision !== expected) throw new DomainError('aborted', 'The schedule changed. Discard and reload.');
    if (JSON.stringify(baseline.baseWindows) === JSON.stringify(submitted)) throw new InputValidationError('Change at least one scheduling window.');
    const coverage = (list: AvailabilityWindow[], slot: number) => list.find(w => w.startAtMillis <= slot && w.endAtMillis >= slot + SLOT)?.branchId;
    const slots = dateGrid(date, policy.timeZone).slots;
    const locks = await readAll(tx, slots.map(slot => `${root}/slotLocks/${keyOf(uid, slot)}`));
    for (const [i, slot] of slots.entries()) {
      const lock = locks[i]; if (!lock) continue;
      const validId = (value: unknown) => typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(value);
      if (lock.schemaVersion !== 1 || lock.coachId !== uid || !validId(lock.branchId) || !validId(lock.bookingId) || (lock.status !== 'confirmed' && lock.status !== 'pending_hold')
        || (lock.status === 'pending_hold' && (!Number.isSafeInteger(lock.expiresAtMillis) || Number(lock.expiresAtMillis) < 1 || Number(lock.expiresAtMillis) > slot))) throw new DomainError('failed-precondition', 'A reservation lock requires authorized review.');
      if (lock.status === 'confirmed' || Number(lock.expiresAtMillis) > now) {
        if (coverage(baseline.windows, slot) !== lock.branchId) throw new DomainError('failed-precondition', 'Stored schedule and reservation disagree.');
        if (coverage(maskWindows(submitted, roster.exceptions), slot) !== lock.branchId) throw new DomainError('aborted', 'Reserved time must remain on its original branch.');
      }
    }
    const result: AvailabilitySaveResult = { schemaVersion: 1, requestId, coachId: uid, localDate: date, revision: expected + 1, outcome: submitted.length ? 'saved' : 'removed' };
    tx.set(path, { schemaVersion: 1, windows: submitted, revision: result.revision, timeZone: policy.timeZone, policyVersion: policy.policyVersion, createdAtMillis: current?.createdAtMillis ?? now, updatedAtMillis: now });
    tx.create(receiptPath, { schemaVersion: 1, command: 'saveCoachAvailabilityDay', actorId: uid, fingerprint, createdAtMillis: now, result });
    return result;
  });
}
