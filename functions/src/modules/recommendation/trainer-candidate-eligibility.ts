import { DomainError } from '../../platform/errors';
import type { DocumentData, TransactionPort } from '../../platform/firestore/store';
import { keyOf } from '../../platform/idempotency';
import { InputValidationError, requiredIdentifier } from '../../platform/validation';
import { allowed, branchIds, dateEpoch, integer, object, SLOT } from '../coaching/coach-availability-contracts';
import { bookingCoachScope, bookingDaySnapshot, currentBookingMembership, currentBookingPolicy, requireBookingOrganization } from '../coaching/booking-validation';
import type { CoachIdentityReader } from '../coaching/coach-profile-service';
import { memberBusySlots } from '../coaching/member-booking-conflicts';

export const TRAINER_LEARNING_OBJECTIVES = ['technique_foundations', 'movement_control', 'progression', 'endurance'] as const;
export const TRAINER_LEVELS = ['beginner', 'intermediate', 'advanced'] as const;
export type TrainerLearningObjective = typeof TRAINER_LEARNING_OBJECTIVES[number];
export type TrainerLevel = typeof TRAINER_LEVELS[number];
/** Internal already-authorized input. Consent, purpose/history authorization and
 * compatible learning context belong to the caller. No endpoint is registered. */
export interface TrainerCandidateQuery {
  schemaVersion: 1; organizationId: string; memberId: string; exerciseId: string;
  learningObjective: TrainerLearningObjective; level: TrainerLevel;
  localDate: string; durationMinutes: 30 | 60;
}
export type TrainerReadSnapshot = Pick<TransactionPort, 'get' | 'getAll'>;
export interface TrainerCandidateRepository {
  transact<T>(work: (snapshot: TrainerReadSnapshot) => Promise<T>): Promise<T>;
  /** Trusted organization-bound directory query, unique IDs ascending, limit 21.
   * Return the sentinel too; excess fails closed. IDs are canonically re-read. */
  listCoachIds(query: { organizationId: string; limit: 21 }): Promise<readonly string[]>;
}
/** Inject ONLY a reviewed server-owned map, never bio/tag/model/Member text.
 * Both bases bind exact exercise IDs; curated_expertise records an explicitly
 * reviewed expertise-to-exercise mapping, never a similarity inference. */
export interface TrustedTrainerExpertise {
  schemaVersion: 1; mappingId: string; revision: number; organizationId: string; coachId: string;
  basis: 'exact_exercise' | 'curated_expertise'; exerciseIds: readonly string[];
  learningObjectives: readonly TrainerLearningObjective[]; levels: readonly TrainerLevel[];
  teachingFocus?: string;
}
export interface TrainerCandidateDependencies {
  repository: TrainerCandidateRepository; readIdentity: CoachIdentityReader;
  trustedExpertise: readonly TrustedTrainerExpertise[]; clock?: () => number;
}
export type TrainerRejectionReason = 'coach_unavailable' | 'coach_auth_unavailable' | 'profile_unavailable' | 'profile_invalid'
  | 'credentials_unavailable' | 'credentials_invalid' | 'no_shared_active_branch' | 'unsupported_relevance'
  | 'availability_invalid' | 'outside_booking_window' | 'member_daily_cap' | 'coach_daily_capacity' | 'no_bookable_slot';
export interface ValidatedTrainerCandidate {
  candidateId: string; coachId: string; exerciseId: string; learningObjective: TrainerLearningObjective; level: TrainerLevel;
  relevance: TrustedTrainerExpertise['basis'];
  availableOptions: { branchId: string; startAtMillis: number; endAtMillis: number }[];
  evidence: {
    publishedProfileRevision: number; approvedCertificationCount: number;
    credentialSemantics: 'current_approved_records_no_expiry_schema';
    expertiseMappingId: string; expertiseMappingRevision: number; bookingPolicyVersion: string;
    timeZone: string; localDate: string; durationMinutes: 30 | 60;
    coachAuthActiveVerified: true; memberAuthActiveVerified: true;
    sharedActiveBranchIds: string[]; memberDailyReservations: number; memberDailyCap: number;
    coachDailyCapacityMinutes: number | null; coachReservedMinutes: number;
    yearsExperience: number | null; teachingFocus: string | null;
  };
}
export interface TrainerCandidateResult {
  schemaVersion: 1; evaluatedAtMillis: number;
  source: 'bounded_read_only_authoritative_snapshot_rechecked';
  candidates: ValidatedTrainerCandidate[];
  rejected: { candidateId: string; reason: TrainerRejectionReason }[];
}
const MAX_COACHES = 20, MAX_READS = 8000, MAX_SOURCE_BYTES = 8 * 1024 * 1024;
const unavailable = () => new DomainError('unavailable', 'Trainer sources are unavailable.');
const invalid = () => new DomainError('failed-precondition', 'Trainer sources require authorized review.');
const memberDenied = () => new DomainError('permission-denied', 'Current Member access is required.');
const drift = () => new DomainError('aborted', 'Trainer eligibility changed. Refresh before continuing.');
const validIdentity = (d: Awaited<ReturnType<CoachIdentityReader>>) => d?.exists === true && d.disabled === false && d.emailVerified === true;
const validText = (v: unknown, max: number, empty = false) => typeof v === 'string' && (empty || !!v.trim()) && v.length <= max;
const validTime = (v: unknown, now: number) => Number.isSafeInteger(v) && Number(v) >= 0 && Number(v) <= now;
const positive = (v: unknown) => Number.isSafeInteger(v) && Number(v) >= 1;

function queryInput(raw: TrainerCandidateQuery): TrainerCandidateQuery {
  const d = object(raw);
  allowed(d, ['schemaVersion', 'organizationId', 'memberId', 'exerciseId', 'learningObjective', 'level', 'localDate', 'durationMinutes']);
  if (d.schemaVersion !== 1 || !TRAINER_LEARNING_OBJECTIVES.includes(d.learningObjective as TrainerLearningObjective)
    || !TRAINER_LEVELS.includes(d.level as TrainerLevel) || (d.durationMinutes !== 30 && d.durationMinutes !== 60)) throw new InputValidationError('Unsupported Trainer learning context.');
  dateEpoch(d.localDate);
  return { schemaVersion: 1, organizationId: requiredIdentifier(d.organizationId, 'organizationId'), memberId: requiredIdentifier(d.memberId, 'memberId'),
    exerciseId: requiredIdentifier(d.exerciseId, 'exerciseId'), learningObjective: d.learningObjective as TrainerLearningObjective,
    level: d.level as TrainerLevel, localDate: d.localDate as string, durationMinutes: d.durationMinutes };
}
function mappingsInput(raw: readonly TrustedTrainerExpertise[]): TrustedTrainerExpertise[] {
  try {
    if (!Array.isArray(raw) || raw.length > 200) throw invalid();
    const mappingIds = new Set<string>();
    return raw.map(value => {
      const d = object(value);
      allowed(d, ['schemaVersion', 'mappingId', 'revision', 'organizationId', 'coachId', 'basis', 'exerciseIds', 'learningObjectives', 'levels', 'teachingFocus']);
      const mappingId = requiredIdentifier(d.mappingId, 'mappingId');
      if (d.schemaVersion !== 1 || !positive(d.revision) || mappingIds.has(mappingId) || typeof d.basis !== 'string' || !['exact_exercise', 'curated_expertise'].includes(d.basis)
        || (d.teachingFocus !== undefined && (!validText(d.teachingFocus, 480) || /[\x00-\x1f\x7f]/.test(String(d.teachingFocus))))) throw invalid();
      mappingIds.add(mappingId);
      const list = (value: unknown, allowedValues?: readonly string[]) => {
        if (!Array.isArray(value) || !value.length || value.length > 32) throw invalid();
        const result = value.map(v => requiredIdentifier(v, 'expertiseValue'));
        if (new Set(result).size !== result.length || (allowedValues && result.some(v => !allowedValues.includes(v)))) throw invalid();
        return result;
      };
      return { schemaVersion: 1, mappingId, revision: Number(d.revision), organizationId: requiredIdentifier(d.organizationId, 'organizationId'),
        coachId: requiredIdentifier(d.coachId, 'coachId'), basis: d.basis as TrustedTrainerExpertise['basis'], exerciseIds: list(d.exerciseIds),
        learningObjectives: list(d.learningObjectives, TRAINER_LEARNING_OBJECTIVES) as TrainerLearningObjective[], levels: list(d.levels, TRAINER_LEVELS) as TrainerLevel[],
        ...(d.teachingFocus === undefined ? {} : { teachingFocus: d.teachingFocus as string }) };
    });
  } catch { throw invalid(); }
}
function profileValid(d: DocumentData, now: number, org: string, coachId: string) {
  try {
    allowed(d, ['displayName', 'specialty', 'bio', 'specializationTags', 'yearsExperience', 'consultationFeeMinor', 'photoPath', 'schemaVersion', 'revision', 'sourceRevision', 'status', 'branchIds', 'createdAtMillis', 'updatedAtMillis', 'publishedAtMillis', 'certificationVerified', 'approvedCertificationCount']);
    if (d.schemaVersion !== 1 || !positive(d.revision) || !positive(d.sourceRevision)
      || !validTime(d.createdAtMillis, now) || !validTime(d.updatedAtMillis, now) || !validTime(d.publishedAtMillis, now)
      || Number(d.updatedAtMillis) < Number(d.createdAtMillis) || Number(d.publishedAtMillis) < Number(d.createdAtMillis)
      || !validText(d.displayName, 80) || !validText(d.specialty, 80) || !validText(d.bio, 1000, true)
      || !Array.isArray(d.specializationTags) || d.specializationTags.length < 1 || d.specializationTags.length > 8
      || d.specializationTags.some(t => !validText(t, 40)) || new Set(d.specializationTags).size !== d.specializationTags.length
      || (d.yearsExperience !== null && (!Number.isSafeInteger(d.yearsExperience) || Number(d.yearsExperience) < 0 || Number(d.yearsExperience) > 60))
      || (d.consultationFeeMinor !== undefined && d.consultationFeeMinor !== null && (!Number.isSafeInteger(d.consultationFeeMinor) || Number(d.consultationFeeMinor) < 0 || Number(d.consultationFeeMinor) > 1000000))) return false;
    if (d.photoPath !== undefined && d.photoPath !== null && (typeof d.photoPath !== 'string' || !d.photoPath.startsWith(`orgs/${org}/coachProfilePhotos/${coachId}/`) || !/^[a-f0-9]{32}$/.test(d.photoPath.slice(`orgs/${org}/coachProfilePhotos/${coachId}/`.length)))) return false;
    branchIds(d.branchIds);
    return true;
  } catch { return false; }
}
async function credentialFailure(tx: TransactionPort, root: string, coachId: string, profile: DocumentData, now: number): Promise<TrainerRejectionReason | number> {
  const base = `${root}/coachProfiles/${coachId}`, state = await tx.get(`${base}/certificationState/current`);
  if (profile.certificationVerified !== true || state?.certificationVerified !== true || !positive(state.approvedCount)) return 'credentials_unavailable';
  if (state.schemaVersion !== 1 || !validTime(state.updatedAtMillis, now) || !Array.isArray(state.certificationIds) || !state.certificationIds.length || state.certificationIds.length > 100
    || state.certificationIds.some(id => typeof id !== 'string' || !/^[a-f0-9]{32}$/.test(id)) || new Set(state.certificationIds).size !== state.certificationIds.length
    || Number(state.approvedCount) > state.certificationIds.length || profile.approvedCertificationCount !== state.approvedCount) return 'credentials_invalid';
  let approved = 0;
  for (const id of [...state.certificationIds].sort()) {
    const d = await tx.get(`${base}/certifications/${id}`);
    if (!d || d.schemaVersion !== 1 || d.id !== id || d.coachId !== coachId || typeof d.status !== 'string' || !['pending', 'approved', 'rejected', 'archived'].includes(d.status)
      || !positive(d.revision) || Number(d.revision) > 100 || !validTime(d.createdAtMillis, now) || !validTime(d.updatedAtMillis, now)
      || Number(d.updatedAtMillis) < Number(d.createdAtMillis) || !validText(d.title, 120) || !validText(d.issuer, 120)
      || d.storagePath !== `${root}/coachCertifications/${coachId}/${id}`) return 'credentials_invalid';
    if (d.status === 'approved') approved++;
  }
  return approved === state.approvedCount ? approved : 'credentials_invalid';
}

/** Local-only. No booking, lead or model request is written. Availability is
 * evidence, never a reservation. Auth is external to Firestore and rechecked
 * around two consistent read snapshots; cross-service atomicity is not claimed. */
export async function evaluateTrainerCandidates(raw: TrainerCandidateQuery, dependencies: TrainerCandidateDependencies): Promise<TrainerCandidateResult> {
  const q = queryInput(raw), mappings = mappingsInput(dependencies.trustedExpertise), now = integer((dependencies.clock ?? Date.now)(), 1);
  const root = `orgs/${q.organizationId}`;
  let reads = 0, bytes = 0;
  const snapshot = async <T>(work: (tx: TransactionPort, fingerprint: () => string) => Promise<T>) => {
    try {
      return await dependencies.repository.transact(async source => {
        const seen = new Map<string, DocumentData | undefined>();
        const tx: TransactionPort = {
          get: async path => {
            if (seen.has(path)) return seen.get(path);
            if (++reads > MAX_READS) throw new DomainError('resource-exhausted', 'Trainer source read limit exceeded.');
            const d = await source.get(path);
            bytes += Buffer.byteLength(JSON.stringify(d ?? null), 'utf8');
            if (bytes > MAX_SOURCE_BYTES) throw new DomainError('resource-exhausted', 'Trainer source size limit exceeded.');
            seen.set(path, d); return d;
          },
          create: () => { throw invalid(); }, set: () => { throw invalid(); },
        };
        return work(tx, () => keyOf([...seen].sort(([a], [b]) => a.localeCompare(b))));
      });
    } catch (error) {
      if (error instanceof DomainError) throw error;
      throw unavailable();
    }
  };
  const memberScope = async (tx: TransactionPort) => {
    try {
      const member = await currentBookingMembership(tx, q.organizationId, q.memberId);
      await requireBookingOrganization(tx, q.organizationId);
      if (member.role !== 'member') throw memberDenied();
      return member;
    } catch (error) {
      if (error instanceof DomainError && ['unavailable', 'resource-exhausted'].includes(error.code)) throw error;
      throw memberDenied();
    }
  };
  const authorizedFingerprint = await snapshot(async (tx, fingerprint) => { await memberScope(tx); return fingerprint(); });
  const identity = async (id: string) => { try { return validIdentity(await dependencies.readIdentity(id)); } catch { return false; } };
  if (!await identity(q.memberId)) throw memberDenied();
  let coachIds: readonly string[];
  try { coachIds = await dependencies.repository.listCoachIds({ organizationId: q.organizationId, limit: 21 }); }
  catch { throw unavailable(); }
  if (!Array.isArray(coachIds) || coachIds.length > MAX_COACHES) throw new DomainError('resource-exhausted', 'Trainer candidate limit exceeded.');
  coachIds = [...coachIds];
  try {
    for (let i = 0; i < coachIds.length; i++) if (requiredIdentifier(coachIds[i], 'coachId') !== coachIds[i] || (i > 0 && coachIds[i] <= coachIds[i - 1])) throw invalid();
  } catch { throw invalid(); }
  const auth = new Map<string, boolean>();
  for (const id of coachIds) auth.set(id, await identity(id));
  const evaluate = async () => snapshot(async (tx, fingerprint) => {
    const member = await memberScope(tx);
    if (fingerprint() !== authorizedFingerprint) throw drift();
    const policy = currentBookingPolicy(await tx.get(`${root}/settings/booking`));
    const candidates: ValidatedTrainerCandidate[] = [], rejected: TrainerCandidateResult['rejected'] = [];
    const reject = (candidateId: string, reason: TrainerRejectionReason) => rejected.push({ candidateId, reason });
    for (const coachId of coachIds) {
      if (!auth.get(coachId)) { reject(coachId, 'coach_auth_unavailable'); continue; }
      try {
        const coach = await currentBookingMembership(tx, q.organizationId, coachId);
        if (coach.role !== 'coach') { reject(coachId, 'coach_unavailable'); continue; }
      } catch (error) {
        if (!(error instanceof DomainError) || ['unavailable', 'resource-exhausted'].includes(error.code)) throw error;
        reject(coachId, 'coach_unavailable'); continue;
      }
      const profile = await tx.get(`${root}/coaches/${coachId}`);
      if (profile?.status !== 'published') { reject(coachId, 'profile_unavailable'); continue; }
      if (!profileValid(profile, now, q.organizationId, coachId)) { reject(coachId, 'profile_invalid'); continue; }
      const count = await credentialFailure(tx, root, coachId, profile, now);
      if (typeof count !== 'number') { reject(coachId, count); continue; }
      let scope: Awaited<ReturnType<typeof bookingCoachScope>>;
      try { scope = await bookingCoachScope(tx, q.organizationId, coachId, member.branchIds); }
      catch (error) {
        if (!(error instanceof DomainError) || ['unavailable', 'resource-exhausted'].includes(error.code)) throw error;
        reject(coachId, 'no_shared_active_branch'); continue;
      }
      const mapping = mappings.filter(m => m.organizationId === q.organizationId && m.coachId === coachId && m.exerciseIds.includes(q.exerciseId)
        && m.learningObjectives.includes(q.learningObjective) && m.levels.includes(q.level))
        .sort((a, b) => (a.basis === 'exact_exercise' ? 0 : 1) - (b.basis === 'exact_exercise' ? 0 : 1) || a.mappingId.localeCompare(b.mappingId))[0];
      if (!mapping) { reject(coachId, 'unsupported_relevance'); continue; }
      try {
        const day = await bookingDaySnapshot(tx, q.organizationId, coachId, q.memberId, q.localDate, policy, scope.assigned, now);
        if (day.reservations.length >= policy.cap) { reject(coachId, 'member_daily_cap'); continue; }
        if (day.dailyCapacityMinutes !== undefined && day.blocked.size * 30 + q.durationMinutes > day.dailyCapacityMinutes) { reject(coachId, 'coach_daily_capacity'); continue; }
        const memberBlocked = await memberBusySlots(tx, q.organizationId, q.memberId, q.localDate, policy.timeZone, day.reservations);
        const availableOptions: ValidatedTrainerCandidate['availableOptions'] = [];
        for (const startAtMillis of day.grid.slots) {
          const endAtMillis = startAtMillis + q.durationMinutes * 60000;
          const window = day.windows.find(w => scope.permitted.includes(w.branchId) && w.startAtMillis <= startAtMillis && w.endAtMillis >= endAtMillis);
          if (!window || startAtMillis <= now || day.blocked.has(startAtMillis) || memberBlocked.has(startAtMillis)
            || (q.durationMinutes === 60 && (day.blocked.has(startAtMillis + SLOT) || memberBlocked.has(startAtMillis + SLOT)))) continue;
          availableOptions.push({ branchId: window.branchId, startAtMillis, endAtMillis });
        }
        if (!availableOptions.length) { reject(coachId, 'no_bookable_slot'); continue; }
        candidates.push({ candidateId: coachId, coachId, exerciseId: q.exerciseId, learningObjective: q.learningObjective, level: q.level, relevance: mapping.basis, availableOptions,
          evidence: { publishedProfileRevision: Number(profile.revision), approvedCertificationCount: count, credentialSemantics: 'current_approved_records_no_expiry_schema',
            expertiseMappingId: mapping.mappingId, expertiseMappingRevision: mapping.revision, bookingPolicyVersion: policy.policyVersion,
            timeZone: policy.timeZone, localDate: q.localDate, durationMinutes: q.durationMinutes, coachAuthActiveVerified: true, memberAuthActiveVerified: true,
            sharedActiveBranchIds: scope.permitted, memberDailyReservations: day.reservations.length, memberDailyCap: policy.cap,
            coachDailyCapacityMinutes: day.dailyCapacityMinutes ?? null, coachReservedMinutes: day.blocked.size * 30,
            yearsExperience: profile.yearsExperience as number | null, teachingFocus: mapping.teachingFocus ?? null } });
      } catch (error) {
        if (!(error instanceof DomainError) || ['unavailable', 'resource-exhausted'].includes(error.code)) throw error;
        reject(coachId, error.code === 'invalid-argument' ? 'outside_booking_window' : 'availability_invalid');
      }
    }
    const result: TrainerCandidateResult = { schemaVersion: 1, evaluatedAtMillis: now, source: 'bounded_read_only_authoritative_snapshot_rechecked', candidates, rejected };
    return { result, fingerprint: fingerprint() };
  });
  const before = await evaluate();
  if (!await identity(q.memberId)) throw memberDenied();
  for (const id of coachIds) if (auth.get(id) !== await identity(id)) throw drift();
  const after = await evaluate();
  if (before.fingerprint !== after.fingerprint || JSON.stringify(before.result) !== JSON.stringify(after.result)) throw drift();
  return after.result;
}
