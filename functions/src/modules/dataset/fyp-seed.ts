/** Bounded dedicated-emulator source seeder. No cloud initialization or deletion API. */
import {Firestore} from 'firebase-admin/firestore';
import {randomBytes} from 'node:crypto';
import type {Auth, UserRecord} from 'firebase-admin/auth';
import type {DocumentData} from '../../platform/firestore/store';
import {FYP_ROOT, FYP_SEED_ID, FYP_DATASET_ID, FYP_EMULATOR_PROJECT, fypDigest, validateFypDataset, type FypDataset, type FypIdentity} from './fyp-dataset';

export interface FypSeedClients {firestore: Firestore; auth: Auth}
export interface FypSeedOptions extends FypSeedClients {dataset: FypDataset; emulatorPassword?: string}
const fail = (message: string): never => {throw new Error(`FYP emulator seed refused: ${message}`);};
const runPath = `${FYP_ROOT}/seedRuns/${FYP_SEED_ID}`;
const owner = (path: string) => `${FYP_ROOT}/seedOwnership/${fypDigest(path)}`;
const authOwner = (uid: string) => `${FYP_ROOT}/seedAuthOwnership/${uid}`;
const canonicalPaths = (uid: string) => [`users/${uid}`, `orgs/gainpath/members/${uid}`];
function endpoint(value: string | undefined): {host: string; port: number} {
  const match = /^(127\.0\.0\.1|localhost):([1-9][0-9]{0,4})$/.exec(value ?? '');
  if (!match || Number(match[2]) > 65535) return fail('explicit loopback emulator endpoints required');
  return {host: match[1], port: Number(match[2])};
}
export function guardFypSeed(clients: FypSeedClients): void {
  const expected = endpoint(process.env.FIRESTORE_EMULATOR_HOST); endpoint(process.env.FIREBASE_AUTH_EMULATOR_HOST);
  const db = clients.firestore as Firestore & {projectId: string; _settings?: {servicePath?: string; port?: number; ssl?: boolean}};
  if (!(db instanceof Firestore) || process.env.GCLOUD_PROJECT !== FYP_EMULATOR_PROJECT || process.env.GOOGLE_CLOUD_PROJECT !== FYP_EMULATOR_PROJECT
      || db.projectId !== FYP_EMULATOR_PROJECT || db.databaseId !== '(default)' || clients.auth.app.options.projectId !== FYP_EMULATOR_PROJECT
      || db._settings?.servicePath !== expected.host || db._settings.port !== expected.port || db._settings.ssl !== false) fail('dedicated demo-gainpath-fyp default-database SDK clients required');
}
export function assignmentForIdentity(identity: FypIdentity, authCreatedAtMillis: number): DocumentData {
  if (!Number.isSafeInteger(authCreatedAtMillis) || authCreatedAtMillis <= 0 || !['admin', 'coach', 'member'].includes(identity.role)) fail('valid actual Auth creation binding required');
  return {schemaVersion: 1, datasetId: FYP_DATASET_ID, organizationId: 'gainpath', seedId: FYP_SEED_ID, role: identity.role, enabled: true, revision: 1, authCreatedAtMillis};
}
export function describeFypSeed(d: FypDataset) {
  validateFypDataset(d);
  const sourcePaths = Object.keys(d.documents).sort(), assignmentPaths = d.identities.map(u => `datasetAssignments/${u.uid}`).sort();
  return {schemaVersion: 1, seedId: d.seedId, projectId: FYP_EMULATOR_PROJECT, databaseId: '(default)', anchorMillis: d.anchorMillis, planDigest: d.digest,
    liveApplyEnabled: false, authAccounts: d.identities.length, sourcePaths, assignmentPaths,
    ownershipPaths: [...sourcePaths, ...assignmentPaths].map(owner).sort(), authOwnershipPaths: d.identities.map(u => authOwner(u.uid)).sort(), runPath,
    counts: d.counts, createOnly: true, assignmentsBoundAfterSourceValidation: true, storageWrites: 0};
}
function isMissing(error: unknown) {return !!error && typeof error === 'object' && 'code' in error && error.code === 'auth/user-not-found';}
async function user(auth: Auth, uid: string): Promise<UserRecord | undefined> {try {return await auth.getUser(uid);} catch (e) {if (isMissing(e)) return undefined; throw e;}}
function matches(actual: UserRecord, spec: FypIdentity, pending: boolean) {
  return actual.uid === spec.uid && actual.email === spec.email && actual.emailVerified === spec.emailVerified && actual.displayName === spec.displayName
    && (actual.disabled === spec.disabled || pending && actual.disabled === true);
}
function creation(actual: UserRecord) {const at = Date.parse(actual.metadata.creationTime); if (!Number.isSafeInteger(at)) return fail('Auth creation time unavailable'); return at;}
function proof(path: string, data: DocumentData) {return {schemaVersion: 1, seedId: FYP_SEED_ID, path, digest: fypDigest(data)};}
async function exactSources(clients: FypSeedClients, entries: [string, DocumentData][], write: boolean) {
  const db = clients.firestore;
  for (let n = 0; n < entries.length; n += 40) {
    guardFypSeed(clients); const batch = entries.slice(n, n + 40);
    await db.runTransaction(async tx => {
      const snapshots = await tx.getAll(...batch.flatMap(([p]) => [db.doc(p), db.doc(owner(p))]));
      const assignmentUids = batch.map(([p]) => /^datasetAssignments\/([A-Za-z0-9_-]{1,128})$/.exec(p)?.[1]).filter((uid): uid is string => uid !== undefined);
      if (assignmentUids.length) {
        const canonical = await tx.getAll(...assignmentUids.flatMap(uid => canonicalPaths(uid).map(p => db.doc(p))));
        if (canonical.some(s => s.exists)) fail('canonical identity metadata occupies a fictional UID; no assignment grant is permitted');
      }
      for (const [i, [p, d]] of batch.entries()) {
        const existing = snapshots[2 * i], ownership = snapshots[2 * i + 1], expectedProof = proof(p, d);
        if (existing.exists) {
          if (!ownership.exists || fypDigest(ownership.data()) !== fypDigest(expectedProof) || fypDigest(existing.data()) !== expectedProof.digest) fail('record collision or exact ownership/content changed');
        } else if (ownership.exists) fail('owned record missing; automatic replacement prohibited');
      }
      if (write) for (const [i, [p, d]] of batch.entries()) if (!snapshots[2 * i].exists) {tx.create(db.doc(p), d); tx.create(db.doc(owner(p)), proof(p, d));}
    });
  }
}
async function preflight(options: FypSeedOptions) {
  guardFypSeed(options); const plan = describeFypSeed(options.dataset), d = options.dataset, db = options.firestore;
  const canonical = await db.getAll(...d.identities.flatMap(u => canonicalPaths(u.uid).map(p => db.doc(p))));
  if (canonical.some(s => s.exists)) fail('canonical identity metadata occupies a fictional UID; existing records are preserved');
  const run = (await db.doc(runPath).get()).data();
  if (run && (run.seedId !== d.seedId || run.anchorMillis !== d.anchorMillis || run.planDigest !== d.digest || !['preparing', 'complete'].includes(String(run.status)))) fail('anchor or manifest collision');
  if (!run) {
    const control = await db.getAll(...d.identities.map(u => db.doc(authOwner(u.uid))), ...plan.assignmentPaths.map(p => db.doc(p)));
    if (control.some(s => s.exists)) fail('unowned identity control records already exist');
  }
  await exactSources(options, Object.entries(d.documents), false);
  for (const spec of d.identities) {
    const actual = await user(options.auth, spec.uid), owned = (await db.doc(authOwner(spec.uid)).get()).data();
    if (actual) {
      if (!run || !owned || owned.seedId !== d.seedId || owned.uid !== spec.uid || owned.authCreatedAtMillis !== creation(actual)
          || !matches(actual, spec, run.status === 'preparing')) fail('Auth identity collision or binding drift');
      const claims = actual.customClaims ?? {};
      if (Object.keys(claims).some(k => k !== 'fypAuthCreatedAtMillis') || claims.fypAuthCreatedAtMillis !== undefined && claims.fypAuthCreatedAtMillis !== creation(actual)
          || run?.status === 'complete' && claims.fypAuthCreatedAtMillis !== creation(actual)) fail('Auth server binding claim changed');
      const assignment = (await db.doc(`datasetAssignments/${spec.uid}`).get()).data();
      if (assignment && fypDigest(assignment) !== fypDigest(assignmentForIdentity(spec, creation(actual)))) fail('assignment collision');
      if (assignment) await exactSources(options, [[`datasetAssignments/${spec.uid}`, assignmentForIdentity(spec, creation(actual))]], false);
    } else if (owned) fail('owned Auth identity missing; replacement prohibited');
    try {const emailOwner = await options.auth.getUserByEmail(spec.email); if (emailOwner.uid !== spec.uid) fail('fictional email already occupied');} catch (e) {if (!isMissing(e)) throw e;}
  }
  return {plan, run};
}
/** Read-only preflight against dedicated emulators. Does not create Auth or Firestore records. */
export async function dryRunFypSeed(options: FypSeedOptions) {const {plan, run} = await preflight(options); return {...plan, dryRun: true, existingRunStatus: run?.status ?? null, willWrite: false};}

export async function applyFypSeed(options: FypSeedOptions) {
  const {plan, run} = await preflight(options), d = options.dataset, db = options.firestore;
  if (run?.status === 'complete') return {createdAuthThisRun: 0, validation: await validateFypSeed(options), plan};
  if (!run) await db.doc(runPath).create({schemaVersion: 1, seedId: d.seedId, anchorMillis: d.anchorMillis, planDigest: d.digest, status: 'preparing', sourceDigests: Object.fromEntries(Object.entries(d.documents).map(([p, v]) => [p, fypDigest(v)])), sourcePaths: plan.sourcePaths, assignmentPaths: plan.assignmentPaths});
  let createdAuthThisRun = 0;
  for (const spec of d.identities) {
    guardFypSeed(options); let actual = await user(options.auth, spec.uid);
    if (!actual) {
      // Accounts remain disabled until the complete source graph and assignments exist.
      const {role: _role, ...authSpec} = spec;
      actual = await options.auth.createUser({...authSpec, password: options.emulatorPassword ?? randomBytes(24).toString('base64url'), disabled: true});
      await db.doc(authOwner(spec.uid)).create({schemaVersion: 1, seedId: d.seedId, uid: spec.uid, email: spec.email, authCreatedAtMillis: creation(actual)});
      createdAuthThisRun++;
    }
    guardFypSeed(options);
    await options.auth.setCustomUserClaims(spec.uid, {fypAuthCreatedAtMillis: creation(actual)});
  }
  await exactSources(options, Object.entries(d.documents), true);
  // Confirm persisted graph, including Date -> Timestamp normalization, before access grants.
  await exactSources(options, Object.entries(d.documents), false);
  const assignments: [string, DocumentData][] = [];
  for (const spec of d.identities) {
    const actual = (await user(options.auth, spec.uid))!, owned = (await db.doc(authOwner(spec.uid)).get()).data();
    if (!owned || owned.authCreatedAtMillis !== creation(actual) || !matches(actual, spec, true)) fail('Auth changed before assignment');
    assignments.push([`datasetAssignments/${spec.uid}`, assignmentForIdentity(spec, creation(actual))]);
  }
  // One 54-write bounded transaction creates all grants and exact ownership together, last.
  await exactSources(options, assignments, true);
  for (const spec of d.identities) {guardFypSeed(options); await options.auth.updateUser(spec.uid, {disabled: spec.disabled});}
  await db.doc(runPath).update({status: 'complete'});
  return {createdAuthThisRun, validation: await validateFypSeed(options), plan};
}

export async function validateFypSeed(options: FypSeedOptions) {
  const {plan, run} = await preflight(options), d = options.dataset;
  if (run?.status !== 'complete') fail('seed is not complete');
  for (const spec of d.identities) {
    const actual = (await user(options.auth, spec.uid))!;
    if (!actual || !matches(actual, spec, false) || actual.customClaims?.fypAuthCreatedAtMillis !== creation(actual)
        || Object.keys(actual.customClaims ?? {}).some(k => k !== 'fypAuthCreatedAtMillis')) fail('Auth validation failed');
    const p = `datasetAssignments/${spec.uid}`, expected = assignmentForIdentity(spec, creation(actual));
    if (fypDigest((await options.firestore.doc(p).get()).data()) !== fypDigest(expected)) fail('assignment validation failed');
    await exactSources(options, [[p, expected]], false);
  }
  return {valid: true as const, environment: 'dedicated_default_auth_firestore_emulators', sourceDocuments: plan.sourcePaths.length, authIdentities: d.identities.length, assignments: d.identities.length, ...d.counts};
}

export function inspectFypCleanupRecord(input: {path: string; current?: DocumentData; baseline?: DocumentData; seedProof?: DocumentData; generatedProof?: DocumentData; approvedActorIds?: readonly string[]}):
  {owned: true; generated: boolean} | {owned: false; reason: string} {
  const {path, current, baseline, seedProof, generatedProof} = input;
  const preserve = (reason: string) => ({owned: false as const, reason});
  if (path !== FYP_ROOT && (!path.startsWith(`${FYP_ROOT}/`) || path.split('/').length % 2 !== 0 || path.split('/').some(p => !/^[A-Za-z0-9_-]{1,128}$/.test(p)))) return preserve('path_outside_cohort');
  if (!current) return preserve('record_missing');
  if (baseline && (!seedProof || seedProof.schemaVersion !== 1 || seedProof.seedId !== FYP_SEED_ID || seedProof.path !== path || seedProof.digest !== fypDigest(baseline))) return preserve('seed_ownership_missing_or_changed');
  const generatedValid = generatedProof?.schemaVersion === 1 && generatedProof.seedId === FYP_SEED_ID && generatedProof.datasetId === FYP_DATASET_ID
    && generatedProof.path === path && generatedProof.digest === fypDigest(current) && typeof generatedProof.actorId === 'string'
    && input.approvedActorIds?.includes(generatedProof.actorId) === true && Number.isSafeInteger(generatedProof.assignmentRevision)
    && Number(generatedProof.assignmentRevision) >= 1 && Number.isSafeInteger(generatedProof.lastWrittenAtMillis) && Number(generatedProof.lastWrittenAtMillis) > 0;
  if (generatedProof && !generatedValid) return preserve('generated_ownership_or_current_digest_changed');
  if (baseline && fypDigest(current) === fypDigest(baseline)) return {owned: true, generated: generatedValid};
  if (generatedValid) return {owned: true, generated: true};
  return preserve(baseline ? 'content_changed_without_matching_generated_ownership' : 'no_exact_ownership');
}

/** Exact source and runtime-owned inventory. Preserved records are never deletion candidates. */
export async function cleanupFypSeedDryRun(options: FypSeedOptions) {
  guardFypSeed(options); const d = options.dataset, plan = describeFypSeed(d), db = options.firestore;
  const run = (await db.doc(runPath).get()).data();
  if (!run || run.seedId !== d.seedId || run.planDigest !== d.digest || run.anchorMillis !== d.anchorMillis || run.status !== 'complete') fail('exact completed seed manifest required for cleanup planning');
  const registry = await db.collection(`${FYP_ROOT}/generatedOwnership`).limit(2001).get();
  if (registry.size > 2000) fail('generated ownership registry exceeds its reviewed bound');
  const generated = new Map<string, {proof: DocumentData; registryPath: string}>();
  const preserved: {path: string; reason: string}[] = [], confirmed = new Set<string>();
  for (const entry of registry.docs) {
    const proof = entry.data(), path = proof.path;
    if (typeof path !== 'string' || entry.id !== fypDigest(path) || !path.startsWith(`${FYP_ROOT}/`) || ['seedOwnership', 'seedAuthOwnership', 'seedRuns', 'generatedOwnership', 'module13DemoSource'].includes(path.slice(FYP_ROOT.length + 1).split('/')[0])) {
      preserved.push({path: entry.ref.path, reason: 'invalid_generated_registry_reference'}); continue;
    }
    generated.set(path, {proof, registryPath: entry.ref.path});
  }
  const paths = [...new Set([...plan.sourcePaths, ...generated.keys()])].sort();
  for (let n = 0; n < paths.length; n += 40) {
    guardFypSeed(options); const batch = paths.slice(n, n + 40);
    const snapshots = await db.getAll(...batch.flatMap(p => [db.doc(p), db.doc(owner(p))]));
    for (const [i, p] of batch.entries()) {
      const current = snapshots[2 * i].data(), seedProof = snapshots[2 * i + 1].data(), runtime = generated.get(p);
      const decision = inspectFypCleanupRecord({path: p, current, baseline: d.documents[p], seedProof, generatedProof: runtime?.proof, approvedActorIds: d.identities.map(u => u.uid)});
      if (!decision.owned) {preserved.push({path: p, reason: decision.reason}); if (seedProof) preserved.push({path: owner(p), reason: 'preserve_ownership_for_preserved_record'}); if (runtime) preserved.push({path: runtime.registryPath, reason: 'preserve_ownership_for_preserved_record'}); continue;}
      confirmed.add(p); if (d.documents[p]) confirmed.add(owner(p)); if (decision.generated && runtime) confirmed.add(runtime.registryPath);
    }
  }
  const authBindings: {uid: string; authCreatedAtMillis: number}[] = [];
  for (const spec of d.identities) {
    const actual = await user(options.auth, spec.uid), ownership = (await db.doc(authOwner(spec.uid)).get()).data();
    const canonical = await db.getAll(...canonicalPaths(spec.uid).map(p => db.doc(p)));
    const mixedIdentity = canonical.some(s => s.exists);
    for (const [i, s] of canonical.entries()) if (s.exists) preserved.push({path: canonicalPaths(spec.uid)[i], reason: 'canonical_identity_metadata_preserved'});
    const p = `datasetAssignments/${spec.uid}`, assignment = (await db.doc(p).get()).data(), assignmentProof = (await db.doc(owner(p)).get()).data();
    if (mixedIdentity || !actual || !ownership || ownership.schemaVersion !== 1 || ownership.seedId !== d.seedId || ownership.uid !== spec.uid
        || ownership.authCreatedAtMillis !== creation(actual) || !matches(actual, spec, false) || actual.customClaims?.fypAuthCreatedAtMillis !== creation(actual)
        || Object.keys(actual.customClaims ?? {}).some(k => k !== 'fypAuthCreatedAtMillis')) {
      preserved.push({path: `auth/${spec.uid}`, reason: mixedIdentity ? 'canonical_identity_metadata_present' : 'auth_identity_or_creation_binding_changed'}, {path: authOwner(spec.uid), reason: 'preserve_identity_ownership'});
    } else {authBindings.push({uid: spec.uid, authCreatedAtMillis: creation(actual)}); confirmed.add(authOwner(spec.uid));}
    const expected = actual ? assignmentForIdentity(spec, creation(actual)) : undefined;
    if (!expected || fypDigest(assignment ?? null) !== fypDigest(expected) || fypDigest(assignmentProof ?? null) !== fypDigest(proof(p, expected))) {
      preserved.push({path: p, reason: 'assignment_or_ownership_changed'}, {path: owner(p), reason: 'preserve_assignment_ownership'});
    } else {confirmed.add(p); confirmed.add(owner(p));}
  }
  if (preserved.length === 0) confirmed.add(plan.runPath);
  else preserved.push({path: plan.runPath, reason: 'retain_manifest_for_preserved_records'});
  return {schemaVersion: 1, dryRun: true, willDelete: false, seedId: FYP_SEED_ID, projectId: FYP_EMULATOR_PROJECT, databaseId: '(default)',
    firestorePaths: [...confirmed].sort(), authBindings, storagePaths: [], preserved,
    generatedRecords: [...generated.keys()].filter(p => confirmed.has(p)).length,
    reason: 'Read-only exact source and bounded runtime ownership inventory. Changed or unowned records and their proofs are preserved; no deletion API exists.'};
}
