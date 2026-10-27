import {isDeepStrictEqual} from 'node:util';
import {DomainError} from '../../platform/errors';
import {requireVerifiedEmail} from '../../platform/auth-context';
import {InputValidationError, requiredIdentifier} from '../../platform/validation';
import {readAll, type DocumentStore, type DocumentData} from '../../platform/firestore/store';
import {APP_CHECK_IN_POLICY, parseAppCheckInProfile, parseAppCheckInReceipt} from '../gamification/app-check-in-service';
import {authorizeAdminReport, type ReportRow} from './admin-reporting';

type Auth = {uid: string; token: Record<string, unknown>};
export interface CheckInReportReader {
  members(after: string | undefined, limit: number): Promise<ReportRow[]>;
  claims(uid: string, after: string | undefined, limit: number): Promise<ReportRow[]>;
}
export const CHECK_IN_REPORT_LIMITS = {members: 2000, eligibleMembers: 200, claims: 2000};
const DAY = 86400000, OFFSET = 8 * 3600000;
const integer = (v: unknown): v is number => Number.isSafeInteger(v) && Number(v) >= 0;
const fail = () => new DomainError('failed-precondition', 'Check-in analytics sources changed or need authorized review. Retry; no partial totals were returned.');
const cap = () => new DomainError('resource-exhausted', 'Check-in analytics exceeds its bounded scan limit. No partial totals were returned.');
const buckets = () => ({zero: 0, oneTwo: 0, threeSix: 0, sevenPlus: 0});
const bucketKey = (n: number) => n === 0 ? 'zero' : n < 3 ? 'oneTwo' : n < 7 ? 'threeSix' : 'sevenPlus';
type Count = {claims: number; claimingMembers: number; pointsAwarded: number};
export interface CheckInReport {
  schemaVersion: 1; organizationId: string; startAtMillis: number; endAtMillis: number;
  sourceReadStartedAtMillis: number; capturedAtMillis: number; timezone: string; policyVersion: string; pointsPerClaim: number;
  coverage: {membersScanned: number; activeMembers: number; profiles: number; claimsScanned: number};
  totals: Count; daily: ({date: string} & Count)[]; weekly: ({date: string} & Count)[];
  streaks: {asOfDate: string; current: ReturnType<typeof buckets>; longest: ReturnType<typeof buckets>};
}
function checkPage(rows: ReportRow[], after: string | undefined, limit: number, pattern: RegExp) {
  if (!Array.isArray(rows) || rows.length > limit) throw fail();
  let previous = after;
  for (const r of rows) {
    if (!r || typeof r.id !== 'string' || !pattern.test(r.id) || (previous !== undefined && r.id <= previous) ||
        !r.data || typeof r.data !== 'object' || Array.isArray(r.data)) throw fail();
    previous = r.id;
  }
}
export async function adminCheckInReport(store: DocumentStore, auth: Auth | undefined, raw: unknown, reader: CheckInReportReader, clock: () => number = Date.now): Promise<CheckInReport> {
  requireVerifiedEmail(auth);
  const q = raw as DocumentData, now = clock();
  if (!q || typeof q !== 'object' || Array.isArray(q) || Object.keys(q).length !== 4 || q.schemaVersion !== 1 || !integer(now) || now > 8639999996400000 ||
      !integer(q.startAtMillis) || !integer(q.endAtMillis) || q.startAtMillis >= q.endAtMillis || q.endAtMillis > now + DAY) throw new InputValidationError('Invalid check-in report query.');
  const org = requiredIdentifier(q.organizationId, 'organizationId');
  if (org !== APP_CHECK_IN_POLICY.organizationId) throw new DomainError('permission-denied', 'Check-in analytics is unavailable for this organization.');
  const authorize = () => store.transact(tx => authorizeAdminReport(tx, auth!, org));
  await authorize();
  const today = Math.floor((now + OFFSET) / DAY), todayDate = new Date(today * DAY).toISOString().slice(0, 10);
  const result: CheckInReport = {schemaVersion: 1, organizationId: org, startAtMillis: Number(q.startAtMillis), endAtMillis: Number(q.endAtMillis),
    sourceReadStartedAtMillis: now, capturedAtMillis: now, timezone: APP_CHECK_IN_POLICY.timezone, policyVersion: APP_CHECK_IN_POLICY.version, pointsPerClaim: APP_CHECK_IN_POLICY.points,
    coverage: {membersScanned: 0, activeMembers: 0, profiles: 0, claimsScanned: 0}, totals: {claims: 0, claimingMembers: 0, pointsAwarded: 0}, daily: [], weekly: [],
    streaks: {asOfDate: todayDate, current: buckets(), longest: buckets()}};
  const rows: ReportRow[] = [];
  let after: string | undefined;
  do {
    const page = await reader.members(after, 251); checkPage(page, after, 251, /^[A-Za-z0-9_-]{1,128}$/);
    for (const row of page) {if (row.data.organizationId !== org) throw fail(); rows.push(row); if (rows.length > CHECK_IN_REPORT_LIMITS.members) throw cap();}
    if (page.length < 251) break; after = page.at(-1)!.id;
  } while (true);
  result.coverage.membersScanned = rows.length;
  const eligible: string[] = [], candidates = rows.filter(r => r.data.status === 'active' && r.data.role === 'member');
  for (let offset = 0; offset < candidates.length; offset += 100) {
    const batch = candidates.slice(offset, offset + 100);
    const users = await store.transact(async tx => {await authorizeAdminReport(tx, auth!, org); return readAll(tx, batch.map(r => 'users/' + r.id));});
    for (let i = 0; i < batch.length; i++) {
      const user = users[i], row = batch[i], lifecycle = user?.accountLifecycle as DocumentData | undefined;
      if (user?.organizationId === org && (user.role === undefined || user.role === 'member') && (row.data.userId === undefined || row.data.userId === row.id) &&
          (lifecycle === undefined || (lifecycle?.state === 'active' && lifecycle.revocationPending === false))) eligible.push(row.id);
    }
  }
  if (eligible.length > CHECK_IN_REPORT_LIMITS.eligibleMembers) throw cap();
  result.coverage.activeMembers = eligible.length;
  const daily = new Map<string, Set<string>>(), weekly = new Map<string, {claims: number; members: Set<string>}>(), claimants = new Set<string>();
  for (const uid of eligible) {
    const profilePath = `orgs/${org}/appCheckInProfiles/${uid}`;
    const rawProfile = await store.transact(async tx => {await authorizeAdminReport(tx, auth!, org); return tx.get(profilePath);});
    let cursor: string | undefined, running = 0, longest = 0, last: number | null = null, lastClaimAt: number | null = null;
    const allDays: string[] = [];
    do {
      const claims = await reader.claims(uid, cursor, 100); checkPage(claims, cursor, 100, /^\d{4}-\d{2}-\d{2}$/);
      for (const row of claims) {
        result.coverage.claimsScanned++; if (result.coverage.claimsScanned > CHECK_IN_REPORT_LIMITS.claims) throw cap();
        let receipt: ReturnType<typeof parseAppCheckInReceipt>;
        try {receipt = parseAppCheckInReceipt(row.data, org, uid, row.id);} catch (_) {throw fail();}
        if (receipt.claimedAtMillis > now) throw fail();
        lastClaimAt = receipt.claimedAtMillis;
        const ordinal = Date.parse(row.id + 'T00:00:00Z') / DAY;
        running = last !== null && ordinal === last + 1 ? running + 1 : 1; longest = Math.max(longest, running); last = ordinal; allDays.push(row.id);
        if (receipt.claimedAtMillis >= result.startAtMillis && receipt.claimedAtMillis < result.endAtMillis) {
          result.totals.claims++; claimants.add(uid);
          if (!daily.has(row.id)) daily.set(row.id, new Set()); daily.get(row.id)!.add(uid);
          const day = new Date(ordinal * DAY), monday = new Date((ordinal - (day.getUTCDay() + 6) % 7) * DAY).toISOString().slice(0, 10);
          if (!weekly.has(monday)) weekly.set(monday, {claims: 0, members: new Set()});
          const week = weekly.get(monday)!; week.claims++; week.members.add(uid);
        }
      }
      if (claims.length < 100) break; cursor = claims.at(-1)!.id;
    } while (true);
    let profile: ReturnType<typeof parseAppCheckInProfile>;
    try {profile = parseAppCheckInProfile(rawProfile, org, uid, today);} catch (_) {throw fail();}
    if (profile.totalClaims !== allDays.length || profile.lastOrdinal !== last || profile.streak !== running || profile.longest !== longest ||
        !isDeepStrictEqual(profile.recentDays, allDays.slice(-50).reverse()) || (rawProfile && (!integer(rawProfile.updatedAtMillis) || rawProfile.updatedAtMillis !== lastClaimAt || rawProfile.updatedAtMillis > now))) throw fail();
    // Prevent a valid concurrent claim from mixing a profile revision with another ledger scan.
    const afterProfile = await store.transact(async tx => {await authorizeAdminReport(tx, auth!, org); return tx.get(profilePath);});
    if (!isDeepStrictEqual(rawProfile, afterProfile)) throw fail();
    if (rawProfile) result.coverage.profiles++;
    const current = last !== null && today - last <= 1 ? running : 0;
    result.streaks.current[bucketKey(current)]++; result.streaks.longest[bucketKey(longest)]++;
  }
  result.totals.claimingMembers = claimants.size; result.totals.pointsAwarded = result.totals.claims * APP_CHECK_IN_POLICY.points;
  result.daily = [...daily].sort(([a], [b]) => a.localeCompare(b)).map(([date, members]) => ({date, claims: members.size, claimingMembers: members.size, pointsAwarded: members.size * APP_CHECK_IN_POLICY.points}));
  result.weekly = [...weekly].sort(([a], [b]) => a.localeCompare(b)).map(([date, week]) => ({date, claims: week.claims, claimingMembers: week.members.size, pointsAwarded: week.claims * APP_CHECK_IN_POLICY.points}));
  await authorize(); result.capturedAtMillis = clock();
  if (!integer(result.capturedAtMillis) || result.capturedAtMillis < now || result.capturedAtMillis > 8640000000000000) throw fail();
  return result;
}
