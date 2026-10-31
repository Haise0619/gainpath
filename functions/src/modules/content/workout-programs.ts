import {createHash} from 'node:crypto';
import {requireActiveMembership, requireVerifiedEmail} from '../../platform/auth-context';
import {DomainError} from '../../platform/errors';
import {readAll, type DocumentData, type DocumentStore, type TransactionPort} from '../../platform/firestore/store';
import {InputValidationError, requiredIdentifier} from '../../platform/validation';

export type ProgramAuth = {uid: string; token: Record<string, unknown>};
export interface WorkoutProgramDependencies {freshAuth(auth: ProgramAuth): Promise<void>; clock?: () => number;}
type Day = {week: number; weekday: number; kind: string; category: string; routineId: string | null; routineDay: number;
  muscleGroups: string[]; restSeconds: number; routineSnapshot?: DocumentData};
export interface WorkoutProgram {schemaVersion: 1; id: string; version: number; title: string; level: string; weeks: 4; days: Day[];}
type IndexEntry = {id: string; revision: number; version: number};
const groups: Record<string, string[]> = {'Full Body': ['upperPush', 'upperPull', 'lower'], 'Upper Body': ['upperPush', 'upperPull'],
  'Lower Body': ['lower'], Push: ['upperPush'], Pull: ['upperPull'], Legs: ['lower'], 'Active Recovery': [], Rest: []};
const integer = (v: unknown, min = 0, max = Number.MAX_SAFE_INTEGER): v is number => Number.isSafeInteger(v) && Number(v) >= min && Number(v) <= max;
const record = (v: unknown): v is DocumentData => !!v && typeof v === 'object' && !Array.isArray(v);
const text = (v: unknown, max: number): v is string => typeof v === 'string' && v.trim().length > 0 && v.length <= max && !/[\x00-\x1f\x7f]/.test(v);
const unavailable = () => new DomainError('failed-precondition', 'Program content is unavailable. Reload before continuing.');
const deny = () => new DomainError('permission-denied', 'Current verified organization authority is required.');
const invalid = () => new InputValidationError('Invalid Program schedule. Check all four weeks, routine assignments and recovery days.');
function fields(d: DocumentData, allowed: string[]) {if (Object.keys(d).some(k => !allowed.includes(k))) throw invalid();}
function canonical(v: unknown): unknown {
  if (Array.isArray(v)) return v.map(canonical);
  if (record(v)) return Object.fromEntries(Object.keys(v).sort().map(k => [k, canonical(v[k])]));
  return v;
}
const digest = (v: unknown) => createHash('sha256').update(JSON.stringify(canonical(v))).digest('hex');
const clone = <T>(v: T): T => JSON.parse(JSON.stringify(v)) as T;

/** Only existing published exercise metadata and targets enter a Program snapshot. */
function routineSnapshot(source: DocumentData | undefined, day: Day): DocumentData {
  if (!source || source.schemaVersion !== 1 || source.kind !== 'routine' || source.status !== 'published'
      || !text(source.sourceBlueprintId, 128) || !text(source.title, 200) || !integer(source.estimatedMinutes, 1, 240)
      || !Array.isArray(source.exercises) || source.exercises.length < 1 || source.exercises.length > 50) throw unavailable();
  const rows = source.exercises.filter(raw => record(raw) && (raw.dayNumber ?? 1) === day.routineDay);
  if (!rows.length || rows.length > 20) throw unavailable();
  const exercises = rows.map(raw => {
    if (!record(raw)) throw unavailable();
    try {requiredIdentifier(raw.exerciseId, 'exerciseId');} catch {throw unavailable();}
    if (!text(raw.name, 200) || !integer(raw.sets, 1, 50) || !integer(raw.reps, 1, 100)) throw unavailable();
    // Catalog categories are descriptive, not recognition algorithms. Reject
    // clear upper/lower mismatches while leaving broad upper Push/Pull choices
    // with the author. Full Body may intentionally combine either region.
    const metadata = `${String(raw.category ?? '')} ${String(raw.muscleGroup ?? '')}`;
    const lower = /lower[\s-]*body|\blegs?\b|\bquads?\b|quadriceps|glutes?|calf|calves|hamstrings?/i.test(metadata);
    const upper = /upper[\s-]*body|chest|shoulder|triceps?|biceps?|\bback\b|\barms?\b/i.test(metadata);
    if ((['Push', 'Pull', 'Upper Body'].includes(day.category) && lower)
        || (['Lower Body', 'Legs'].includes(day.category) && upper && !lower)) throw unavailable();
    const result: DocumentData = {exerciseId: raw.exerciseId, name: raw.name, sets: raw.sets, reps: raw.reps,
      dayNumber: day.routineDay, restSeconds: day.restSeconds};
    for (const key of ['category', 'muscleGroup', 'cue', 'imageUrl', 'videoUrl', 'description', 'equipment', 'difficulty', 'coverImageUrl', 'tutorialSteps']) {
      const value = raw[key];
      if (value === undefined) continue;
      if (key === 'tutorialSteps') {
        if (!Array.isArray(value) || value.length > 12 || value.some(step => !record(step)
            || Object.keys(step).some(k => !['title', 'description', 'imageUrl'].includes(k))
            || !text(step.title, 80) || typeof step.description !== 'string' || !step.description.trim()
            || step.description.length > 1200 || typeof step.imageUrl !== 'string' || step.imageUrl.length > 2048)) throw unavailable();
      } else if (typeof value !== 'string' || value.length > (['category', 'muscleGroup', 'difficulty'].includes(key) ? 100 : key === 'equipment' ? 300 : 2048)) throw unavailable();
      if (key === 'difficulty' && !['Beginner', 'Intermediate', 'Advanced'].includes(String(value))) throw unavailable();
      result[key] = clone(value);
    }
    return result;
  });
  return {schemaVersion: 1, kind: 'routine', status: 'published', sourceBlueprintId: source.sourceBlueprintId,
    title: source.title, estimatedMinutes: source.estimatedMinutes, ...(source.difficulty !== undefined ? {difficulty: source.difficulty} : {}), exercises};
}

function parseProgram(value: unknown, published = false): WorkoutProgram {
  if (!record(value)) throw invalid();
  fields(value, ['schemaVersion', 'id', 'version', 'title', 'level', 'weeks', 'days']);
  requiredIdentifier(value.id, 'program.id');
  if (value.schemaVersion !== 1 || !integer(value.version, published ? 1 : 0) || (!published && value.version !== 0)
      || !text(value.title, 120) || !['Beginner', 'Intermediate', 'Advanced'].includes(String(value.level))
      || value.weeks !== 4 || !Array.isArray(value.days) || value.days.length !== 28) throw invalid();
  const keys = new Set<string>();
  const days = value.days.map(raw => {
    if (!record(raw)) throw invalid();
    fields(raw, ['week', 'weekday', 'kind', 'category', 'routineId', 'routineDay', 'muscleGroups', 'restSeconds', 'routineSnapshot']);
    if (!integer(raw.week, 1, 4) || !integer(raw.weekday, 1, 7) || !['workout', 'activeRecovery', 'rest'].includes(String(raw.kind))
        || typeof raw.category !== 'string' || !Object.hasOwn(groups, raw.category) || !integer(raw.routineDay ?? 1, 1, 14)
        || !integer(raw.restSeconds ?? 60, 0, 600) || !Array.isArray(raw.muscleGroups)
        || raw.muscleGroups.some(g => !['upperPush', 'upperPull', 'lower'].includes(String(g)))
        || new Set(raw.muscleGroups).size !== raw.muscleGroups.length) throw invalid();
    const key = `${raw.week}-${raw.weekday}`; if (keys.has(key)) throw invalid(); keys.add(key);
    if (raw.kind === 'workout' ? ['Active Recovery', 'Rest'].includes(raw.category)
      : raw.category !== (raw.kind === 'rest' ? 'Rest' : 'Active Recovery')) throw invalid();
    if (groups[raw.category].length !== raw.muscleGroups.length || groups[raw.category].some(g => !(raw.muscleGroups as unknown[]).includes(g))
        || (raw.kind !== 'workout' && raw.muscleGroups.length)) throw invalid();
    const routineId = raw.routineId ?? null;
    if (routineId !== null) requiredIdentifier(routineId, 'routineId');
    if (raw.kind !== 'workout' && routineId !== null) throw invalid();
    if (!published && raw.routineSnapshot !== undefined && raw.routineSnapshot !== null) throw invalid();
    const day: Day = {week: raw.week, weekday: raw.weekday, kind: raw.kind as string, category: raw.category,
      routineId: routineId as string | null, routineDay: Number(raw.routineDay ?? 1), muscleGroups: [...raw.muscleGroups as string[]], restSeconds: Number(raw.restSeconds ?? 60)};
    if (published) {
      if (day.kind === 'workout' && !day.routineId) throw invalid();
      if (day.routineId) day.routineSnapshot = routineSnapshot(record(raw.routineSnapshot) ? raw.routineSnapshot : undefined, day);
      else if (raw.routineSnapshot !== undefined && raw.routineSnapshot !== null) throw invalid();
    }
    return day;
  }).sort((a, b) => a.week - b.week || a.weekday - b.weekday);
  for (let i = 1; i < days.length; i++) {
    const previous = days[i - 1], next = days[i];
    if (previous.kind === 'workout' && next.kind === 'workout' && previous.muscleGroups.some(g => next.muscleGroups.includes(g))) throw invalid();
    if (published && previous.kind === 'workout' && next.kind === 'workout') {
      const previousIds = new Set((previous.routineSnapshot!.exercises as DocumentData[]).map(e => e.exerciseId));
      if ((next.routineSnapshot!.exercises as DocumentData[]).some(e => previousIds.has(e.exerciseId))) throw invalid();
    }
  }
  if (published) {
    const counts = [1, 2, 3, 4].map(week => days.filter(day => day.week === week && day.kind === 'workout').length);
    if (!counts[0] || counts.some(count => count !== counts[0])) throw invalid();
  }
  const program: WorkoutProgram = {schemaVersion: 1, id: value.id as string, version: value.version, title: value.title, level: value.level as string, weeks: 4, days};
  // Includes repeated per-day snapshots and leaves room for Firestore map overhead.
  if (Buffer.byteLength(JSON.stringify(program), 'utf8') > 700_000) throw invalid();
  return program;
}
function storedProgram(value: unknown, published: boolean): WorkoutProgram {
  try {return parseProgram(value, published);} catch {throw unavailable();}
}
function parseIndex(value: DocumentData | undefined, org: string): IndexEntry[] {
  if (!value) return [];
  if (value.schemaVersion !== 1 || value.organizationId !== org || !Array.isArray(value.entries) || value.entries.length > 40) throw unavailable();
  const ids = new Set<string>();
  return value.entries.map(raw => {
    if (!record(raw) || !integer(raw.revision, 1) || !integer(raw.version)) throw unavailable();
    try {requiredIdentifier(raw.id, 'programId');} catch {throw unavailable();}
    if (ids.has(raw.id as string)) throw unavailable(); ids.add(raw.id as string);
    return {id: raw.id as string, revision: raw.revision, version: raw.version};
  });
}
async function authorize(tx: TransactionPort, auth: ProgramAuth, org: string, admin: boolean) {
  const [user, membership, organization] = await readAll(tx, [`users/${auth.uid}`, `orgs/${org}/members/${auth.uid}`, `orgs/${org}`]);
  const role = requireActiveMembership(membership).role;
  if (!(admin ? ['admin', 'staff'].includes(role) : ['member', 'admin', 'staff'].includes(role)) || organization?.status !== 'active'
      || user?.organizationId !== org || (user.role !== undefined && user.role !== role) || membership?.organizationId !== org
      || (membership.userId !== undefined && membership.userId !== auth.uid)) throw deny();
  const life = user.accountLifecycle;
  if (life !== undefined && (!record(life) || life.schemaVersion !== 1 || life.state !== 'active' || life.revocationPending !== false
      || !integer(life.sessionNotBeforeSeconds) || (life.sessionNotBeforeSeconds > 0 && (!integer(auth.token.auth_time)
        || auth.token.auth_time < life.sessionNotBeforeSeconds)))) throw deny();
}
function request(raw: unknown): DocumentData {
  if (!record(raw) || raw.schemaVersion !== 1 || typeof raw.action !== 'string') throw invalid();
  const actions: Record<string, string[]> = {list: [], adminList: [], saveDraft: ['requestId', 'expectedRevision', 'program'], publish: ['requestId', 'expectedRevision', 'programId']};
  if (!Object.hasOwn(actions, raw.action)) throw invalid();
  const allowed = ['schemaVersion', 'organizationId', 'action', ...actions[raw.action]];
  fields(raw, allowed); if (Object.keys(raw).length !== allowed.length) throw invalid();
  requiredIdentifier(raw.organizationId, 'organizationId');
  if (raw.action === 'saveDraft' || raw.action === 'publish') {
    requiredIdentifier(raw.requestId, 'requestId');
    if (!integer(raw.expectedRevision, 0, Number.MAX_SAFE_INTEGER - 1)) throw invalid();
  }
  if (raw.action === 'publish') requiredIdentifier(raw.programId, 'programId');
  if (raw.action === 'saveDraft') parseProgram(raw.program);
  return raw;
}

/** Programs prescribe routines only. This service never issues workout acceptance or rewards. */
export async function workoutPrograms(store: DocumentStore, auth: ProgramAuth | undefined, raw: unknown, deps: WorkoutProgramDependencies): Promise<Record<string, any>> {
  requireVerifiedEmail(auth);
  const input = request(raw), org = input.organizationId as string, uid = requiredIdentifier(auth!.uid, 'uid');
  const admin = input.action !== 'list', base = `orgs/${org}`, indexPath = `${base}/workoutProgramCatalog/index`;
  await deps.freshAuth(auth!);
  const result = await store.transact(async tx => {
    await authorize(tx, auth!, org, admin);
    const entries = parseIndex(await tx.get(indexPath), org);
    const mutation = ['saveDraft', 'publish'].includes(String(input.action));
    if (!mutation) {
      const programs: WorkoutProgram[] = [], drafts: {program: WorkoutProgram; revision: number}[] = [];
      for (const entry of entries) {
        if (entry.version > 0) {
          const doc = await tx.get(`${base}/workoutProgramVersions/${entry.id}_v${entry.version}`);
          if (!doc || doc.organizationId !== org) throw unavailable();
          const program = storedProgram(doc.program, true);
          if (program.id !== entry.id || program.version !== entry.version) throw unavailable();
          programs.push(program);
        }
        if (admin) {
          const doc = await tx.get(`${base}/workoutProgramDrafts/${entry.id}`);
          if (!doc || doc.organizationId !== org || doc.revision !== entry.revision) throw unavailable();
          const program = storedProgram(doc.program, false); if (program.id !== entry.id) throw unavailable();
          drafts.push({program, revision: entry.revision});
        }
      }
      if (Buffer.byteLength(JSON.stringify({programs, drafts}), 'utf8') > 4_000_000) throw unavailable();
      return {programs, drafts};
    }
    const fingerprint = digest(input), receiptPath = `${base}/workoutProgramRequests/${digest([uid, input.requestId])}`;
    const receipt = await tx.get(receiptPath);
    if (receipt) {
      if (receipt.schemaVersion !== 1 || receipt.organizationId !== org || receipt.uid !== uid || receipt.requestId !== input.requestId || !record(receipt.result)) throw unavailable();
      if (receipt.fingerprint !== fingerprint) throw new DomainError('already-exists', 'Request reference already used. Retry the original request.');
      if (!integer(receipt.result.revision, 1) || receipt.result.revision !== Number(input.expectedRevision) + 1) throw unavailable();
      if (input.action === 'publish') storedProgram(receipt.result.program, true);
      return clone(receipt.result);
    }
    const supplied = input.action === 'saveDraft' ? parseProgram(input.program) : null;
    const id = supplied?.id ?? input.programId as string, entry = entries.find(e => e.id === id);
    const draftPath = `${base}/workoutProgramDrafts/${id}`, draft = await tx.get(draftPath);
    if ((entry?.revision ?? 0) !== input.expectedRevision) throw new DomainError('aborted', 'Program changed. Reload and review the latest revision.');
    if (entry && (!draft || draft.organizationId !== org || draft.revision !== entry.revision)) throw unavailable();
    if (!entry && draft) throw unavailable();
    if (!entry && entries.length >= 40) throw new DomainError('resource-exhausted', 'Program catalog limit reached.');
    const revision = Number(input.expectedRevision) + 1;
    const at = (deps.clock ?? Date.now)(); if (!integer(at, 1, 8640000000000000)) throw unavailable();
    let response: Record<string, any>, nextEntry: IndexEntry;
    if (supplied) {
      response = {revision}; nextEntry = {id, revision, version: entry?.version ?? 0};
      tx.set(draftPath, {schemaVersion: 1, organizationId: org, revision, program: supplied, updatedBy: uid, updatedAtMillis: at});
    } else {
      if (!entry || !draft) throw new DomainError('not-found', 'Save a Program draft before publishing.');
      const program = storedProgram(draft.program, false);
      if (program.id !== id || program.days.some(d => d.kind === 'workout' && !d.routineId)) throw unavailable();
      const ids = [...new Set(program.days.flatMap(d => d.routineId ? [d.routineId] : []))];
      const sources = await readAll(tx, ids.map(routineId => `${base}/content/${routineId}`));
      const sourceById = new Map(ids.map((routineId, i) => [routineId, sources[i]]));
      program.version = entry.version + 1;
      for (const day of program.days) if (day.routineId) day.routineSnapshot = routineSnapshot(sourceById.get(day.routineId), day);
      let published: WorkoutProgram;
      try {published = parseProgram(program, true);} catch {throw unavailable();}
      response = {program: published, revision}; nextEntry = {id, revision, version: published.version};
      tx.create(`${base}/workoutProgramVersions/${id}_v${published.version}`, {schemaVersion: 1, organizationId: org, program: published, publishedBy: uid, publishedAtMillis: at});
      tx.set(draftPath, {...draft, revision, updatedBy: uid, updatedAtMillis: at});
    }
    const nextEntries = [...entries.filter(e => e.id !== id), nextEntry].sort((a, b) => a.id.localeCompare(b.id));
    tx.set(indexPath, {schemaVersion: 1, organizationId: org, entries: nextEntries});
    tx.create(receiptPath, {schemaVersion: 1, organizationId: org, uid, requestId: input.requestId, fingerprint, result: response, createdAtMillis: at});
    return response;
  });
  await deps.freshAuth(auth!);
  await store.transact(tx => authorize(tx, auth!, org, admin));
  return result;
}
