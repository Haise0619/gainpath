/** Exact-owner-review live orchestration. No credential discovery, deploy or deletion API. */
import {createHash} from 'node:crypto';
import {Firestore} from 'firebase-admin/firestore';
import type {Auth, UserRecord} from 'firebase-admin/auth';
import type {DocumentData} from '../../platform/firestore/store';
import {FYP_ROOT, FYP_SEED_ID, fypDigest, type FypIdentity} from './fyp-dataset';
import {assignmentForIdentity, inspectFypCleanupRecord} from './fyp-seed';
import {requireFypLiveManifest, type FypLiveManifest} from './fyp-live-manifest';

export interface FypLiveVault {
  readonly executionId: string;
  get(uid: string): Promise<{password: string; provisioningNonce: string}>;
  bind(uid: string, actualCreatedAtMillis: number): Promise<void>;
}
export interface FypLiveAuditEvent {action: string; resource: string; atMillis: number; digest?: string}
export interface FypLiveExecutorOptions {
  firestore: Firestore; auth: Auth; manifest: FypLiveManifest; vault: FypLiveVault;
  clock?: () => number; audit: (event: FypLiveAuditEvent) => Promise<void>;
  /** Operator-side fresh deployed source/Rules/App Check checks, never a request flag. */
  activationCheck: () => Promise<void>;
}
function fail(reason: string): never {throw Error(`FYP live executor refused: ${reason}`);}
const emulatorKeys = ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST', 'FIREBASE_DATABASE_EMULATOR_HOST', 'FIREBASE_STORAGE_EMULATOR_HOST', 'FIREBASE_EMULATOR_HUB', 'FUNCTIONS_EMULATOR', 'PUBSUB_EMULATOR_HOST', 'EVENTARC_EMULATOR'];
export function guardFypLiveClients(db: Firestore, auth: Auth): void {
  const s = (db as Firestore & {_settings?: Record<string, unknown>})._settings;
  if (!(db instanceof Firestore) || (db as Firestore & {projectId: string}).projectId !== 'gainpath-0619' || db.databaseId !== '(default)' || auth.app.options.projectId !== 'gainpath-0619'
      || emulatorKeys.some(k => process.env[k] !== undefined) || ['GCLOUD_PROJECT', 'GOOGLE_CLOUD_PROJECT'].some(k => process.env[k] !== undefined && process.env[k] !== 'gainpath-0619')
      || process.env.GOOGLE_CLOUD_UNIVERSE_DOMAIN !== undefined && process.env.GOOGLE_CLOUD_UNIVERSE_DOMAIN !== 'googleapis.com'
      || !s || s.ssl !== undefined && s.ssl !== true || s.port !== undefined && s.port !== 443 || s.sslCreds !== undefined
      || ['host', 'servicePath', 'apiEndpoint'].some(k => s[k] !== undefined && s[k] !== 'firestore.googleapis.com')
      || s.protocol !== undefined && s.protocol !== 'https' || s.universeDomain !== undefined && s.universeDomain !== 'googleapis.com'
      || s.universe_domain !== undefined && s.universe_domain !== 'googleapis.com') fail('fixed project/default database/Google TLS SDK required');
}
const ownerPath = (p: string) => `${FYP_ROOT}/seedOwnership/${fypDigest(p)}`;
const authOwnerPath = (uid: string) => `${FYP_ROOT}/seedAuthOwnership/${uid}`;
const proof = (p: string, data: DocumentData) => ({schemaVersion: 1, seedId: FYP_SEED_ID, path: p, digest: fypDigest(data)});
const created = (u: UserRecord) => {const n = Date.parse(u.metadata.creationTime); if (!Number.isSafeInteger(n) || n <= 0) fail('actual Auth creation binding unavailable'); return n;};
const nonceHash = (v: string) => createHash('sha256').update(v).digest('hex');

export function createFypLiveExecutor(o: FypLiveExecutorOptions) {
  const {firestore: db, auth, manifest, vault} = o, d = manifest.dataset, plan = manifest.plan, now = o.clock ?? Date.now;
  const check = () => {guardFypLiveClients(db, auth); requireFypLiveManifest(manifest); if (!/^[A-Za-z0-9_-]{16,128}$/.test(vault.executionId)) fail('durable execution identity required');};
  check();
  const audit = (action: string, resource: string, data?: DocumentData) => o.audit({action, resource, atMillis: now(), ...(data ? {digest: fypDigest(data)} : {})});
  const read = async (p: string) => (await db.doc(p).get()).data();
  const refs = (paths: string[]) => paths.map(p => db.doc(p));
  async function all(paths: string[]) {const rows: (DocumentData | undefined)[] = []; for (let n = 0; n < paths.length; n += 50) {check(); rows.push(...(await db.getAll(...refs(paths.slice(n, n + 50)))).map(s => s.data()));} return rows;}
  async function user(uid: string): Promise<UserRecord | undefined> {try {return await auth.getUser(uid);} catch (e) {if ((e as {code?: string}).code === 'auth/user-not-found') return undefined; throw e;}}
  function ownedRun(run: DocumentData | undefined) {
    if (!run || run.schemaVersion !== 1 || run.seedId !== FYP_SEED_ID || run.planDigest !== d.digest || run.anchorMillis !== d.anchorMillis
        || run.executionId !== vault.executionId || run.manifestSha256 !== manifest.manifestSha256 || !['preparing', 'validated', 'activating', 'complete', 'disabled'].includes(String(run.status))
        || fypDigest(run.sourcePaths) !== fypDigest(plan.sourcePaths) || fypDigest(run.assignmentPaths) !== fypDigest(plan.assignmentPaths)
        || fypDigest(run.sourceDigests) !== fypDigest(Object.fromEntries(Object.entries(d.documents).map(([p, v]) => [p, fypDigest(v)])))) fail('exact live execution ownership missing or changed');
    return run;
  }
  function expectedCurrent(p: string, baseline: DocumentData, run: DocumentData): DocumentData {
    const r = run.recovery as {schemaVersion: number; sessionNotBeforeSeconds: number; users: Record<string,string>; assignments: Record<string,string>; assignmentRevisions: Record<string,number>} | undefined;
    if (!r) return baseline;
    const userPaths=d.identities.map(i=>`${FYP_ROOT}/users/${i.uid}`).sort(), assignmentPaths=[...plan.assignmentPaths].sort();
    if(r.schemaVersion!==1||!Number.isSafeInteger(r.sessionNotBeforeSeconds)||r.sessionNotBeforeSeconds<=0
      ||fypDigest(Object.keys(r.users??{}).sort())!==fypDigest(userPaths)||fypDigest(Object.keys(r.assignments??{}).sort())!==fypDigest(assignmentPaths)
      ||fypDigest(Object.keys(r.assignmentRevisions??{}).sort())!==fypDigest(assignmentPaths)) fail('recovery ownership inventory changed');
    if(userPaths.includes(p)) {const value={...baseline,accountLifecycle:{schemaVersion:1,state:'active',revocationPending:false,sessionNotBeforeSeconds:r.sessionNotBeforeSeconds}};if(r.users[p]!==fypDigest(value))fail('recovery lifecycle ownership drift');return value;}
    if(assignmentPaths.includes(p)){const revision=r.assignmentRevisions[p],value={...baseline,revision};if(!Number.isSafeInteger(revision)||revision<=Number(baseline.revision)||r.assignments[p]!==fypDigest(value))fail('recovery assignment ownership drift');return value;}
    return baseline;
  }
  function authIntent(raw: DocumentData | undefined, spec: FypIdentity, secret: {provisioningNonce: string}) {
    if (!raw || raw.schemaVersion !== 1 || raw.seedId !== FYP_SEED_ID || raw.uid !== spec.uid || raw.email !== spec.email
        || raw.executionId !== vault.executionId || raw.manifestSha256 !== manifest.manifestSha256 || raw.nonceHash !== nonceHash(secret.provisioningNonce)
        || !['reserved', 'bound'].includes(String(raw.state))) fail('Auth ownership intent missing or changed');
    return raw;
  }
  async function verifyAuth(spec: FypIdentity, u: UserRecord, allowPending: boolean, run: DocumentData) {
    const secret = await vault.get(spec.uid), intent = authIntent(await read(authOwnerPath(spec.uid)), spec, secret), pendingName = `FYP pending ${secret.provisioningNonce}`;
    if (u.uid !== spec.uid || u.email !== spec.email || u.emailVerified !== spec.emailVerified || !Number.isSafeInteger(intent.preparedAtMillis)
        || created(u) < Number(intent.preparedAtMillis) - 5000 || created(u) > now() + 5000) fail('Auth identity drift');
    if (intent.state === 'reserved') {
      if (!allowPending || u.disabled !== true || u.displayName !== pendingName || Object.keys(u.customClaims ?? {}).length) fail('unbound Auth record cannot be adopted');
    } else {
      if (intent.authCreatedAtMillis !== created(u) || ![spec.displayName, pendingName].includes(u.displayName ?? '')
          || Object.keys(u.customClaims ?? {}).some(k => k !== 'fypAuthCreatedAtMillis') || u.customClaims?.fypAuthCreatedAtMillis !== undefined && u.customClaims.fypAuthCreatedAtMillis !== created(u)
          || !allowPending && (u.displayName !== spec.displayName || u.customClaims?.fypAuthCreatedAtMillis !== created(u))) fail('Auth creation/claims/profile ownership drift');
    }
    if (run.status !== 'activating' && run.status !== 'complete' && u.disabled !== true) fail('account enabled before validated activation');
    if (run.status === 'complete' && u.disabled !== spec.disabled) fail('completed Auth lifecycle drift');
    return intent;
  }
  async function preflight() {
    check(); const run = await read(plan.runPath);
    if (run) ownedRun(run);
    const canonical = await all(d.identities.flatMap(i => [`users/${i.uid}`, `orgs/gainpath/members/${i.uid}`]));
    if (canonical.some(Boolean)) fail('canonical identity metadata occupies a fictional UID');
    const targets = [...plan.sourcePaths, ...plan.assignmentPaths], rows = await all(targets.flatMap(p => [p, ownerPath(p)]));
    for (const [i, p] of targets.entries()) {
      const current = rows[2 * i], ownership = rows[2 * i + 1];
      if (current || ownership) {
        if (!run || !current || !ownership || ownership.seedId !== FYP_SEED_ID || ownership.schemaVersion !== 1 || ownership.path !== p || ownership.digest !== fypDigest(current)) fail('unowned, altered or missing target collision');
        if (d.documents[p] && fypDigest(current) !== fypDigest(d.documents[p])) fail('source changed; reapply never restores consent or activity');
      }
    }
    const controls = await all([...plan.authOwnershipPaths, plan.releasePath]);
    if (!run && controls.some(Boolean)) fail('unowned control records already exist');
    if (!run && (await db.doc(FYP_ROOT).listCollections()).length) fail('unowned cohort descendants already exist');
    for (const spec of d.identities) {
      const existing = await user(spec.uid);
      if (existing) {if (!run) fail('Auth UID collision'); await verifyAuth(spec, existing, true, run);}
      else if (await read(authOwnerPath(spec.uid))) {
        const intent = authIntent(await read(authOwnerPath(spec.uid)), spec, await vault.get(spec.uid));
        if (intent.state !== 'reserved') fail('owned Auth identity missing; replacement prohibited');
      }
      try {const found = await auth.getUserByEmail(spec.email); if (found.uid !== spec.uid || !existing) fail('Auth email collision');} catch (e) {if ((e as {code?: string}).code !== 'auth/user-not-found') throw e;}
    }
    if (run && controls.at(-1) && fypDigest(controls.at(-1)) !== fypDigest({...plan.releaseRecord, enabled: run.status === 'complete'})) fail('release control changed');
    return run;
  }
  async function writeEntries(entries: [string, DocumentData][]) {
    for (let n = 0; n < entries.length; n += 40) {
      check(); const batch = entries.slice(n, n + 40);
      await db.runTransaction(async tx => {
        const run = ownedRun((await tx.get(db.doc(plan.runPath))).data()); if (run.status !== 'preparing') fail('source writes require preparing state');
        const reads = await tx.getAll(...refs(batch.flatMap(([p]) => [p, ownerPath(p)])));
        const assignmentIds = batch.map(([p]) => /^datasetAssignments\/([A-Za-z0-9_-]+)$/.exec(p)?.[1]).filter((s): s is string => !!s);
        if (assignmentIds.length && (await tx.getAll(...refs(assignmentIds.flatMap(uid => [`users/${uid}`, `orgs/gainpath/members/${uid}`])))).some(s => s.exists)) fail('canonical identity race before assignment');
        for (const [i, [p, data]] of batch.entries()) {
          if (reads[2 * i].exists || reads[2 * i + 1].exists) {
            if (!reads[2 * i].exists || !reads[2 * i + 1].exists || fypDigest(reads[2 * i].data()) !== fypDigest(data) || fypDigest(reads[2 * i + 1].data()) !== fypDigest(proof(p, data))) fail('create-only source or ownership collision');
          }
        }
        for (const [i, [p, data]] of batch.entries()) if (!reads[2 * i].exists) {tx.create(db.doc(p), data); tx.create(db.doc(ownerPath(p)), proof(p, data));}
      });
      for (const [p, data] of batch) await audit('source-and-owner-verified', p, data);
    }
  }
  async function validate() {
    check(); const run = ownedRun(await read(plan.runPath));
    if (!['validated', 'activating', 'complete', 'disabled'].includes(String(run.status))) fail('source graph not validated');
    const entries: [string, DocumentData][] = Object.entries(d.documents);
    for (const spec of d.identities) {const u = await user(spec.uid); if (!u) fail('owned Auth missing'); await verifyAuth(spec, u, false, run); entries.push([`datasetAssignments/${spec.uid}`, assignmentForIdentity(spec, created(u))]);}
    const rows = await all(entries.flatMap(([p]) => [p, ownerPath(p)]));
    for (const [i, [p, expected]] of entries.entries()) {
      const current = rows[2 * i], activeExpected=expectedCurrent(p,expected,run);
      if (run.status === 'disabled' && p.startsWith('datasetAssignments/')) {
        if (!current || current.enabled !== false || fypDigest(current) !== (run.revokedAssignmentDigests as Record<string, string> | undefined)?.[p]
            || fypDigest(rows[2 * i + 1] ?? null) !== fypDigest(proof(p, expected))) fail('revocation ownership drift');
      } else if (run.status === 'disabled' && p === FYP_ROOT) {
        if (!current || current.enabled !== false || fypDigest(current) !== run.disabledRootDigest || fypDigest(rows[2 * i + 1] ?? null) !== fypDigest(proof(p, expected))) fail('disabled cohort metadata drift');
      } else if (fypDigest(current ?? null) !== fypDigest(activeExpected) || fypDigest(rows[2 * i + 1] ?? null) !== fypDigest(proof(p, expected))) fail('persisted source/assignment digest mismatch');
    }
    const release = await read(plan.releasePath);
    if (fypDigest(release ?? null) !== fypDigest({...plan.releaseRecord, enabled: run.status === 'complete'})) fail('release configuration drift');
    return {valid: true as const, sourceDocuments: 466, authIdentities: 27, accountsEnabled: run.status === 'complete', releaseEnabled: run.status === 'complete', status: run.status};
  }
  async function apply() {
    let run = await preflight();
    if (run && run.status !== 'preparing') return validate();
    if (!run) {
      const initial = {schemaVersion: 1, seedId: FYP_SEED_ID, anchorMillis: d.anchorMillis, planDigest: d.digest, manifestSha256: manifest.manifestSha256,
        executionId: vault.executionId, executorVersion: 'fyp-live-v1', status: 'preparing', sourceDigests: Object.fromEntries(Object.entries(d.documents).map(([p, value]) => [p, fypDigest(value)])), sourcePaths: plan.sourcePaths, assignmentPaths: plan.assignmentPaths};
      await db.runTransaction(async tx => {if ((await tx.getAll(db.doc(plan.runPath), db.doc(plan.releasePath))).some(s => s.exists)) fail('control creation collision'); tx.create(db.doc(plan.runPath), initial); tx.create(db.doc(plan.releasePath), plan.releaseRecord);});
      run = initial; await audit('owned-disabled-controls-created', plan.runPath, initial);
    }
    for (const spec of d.identities) {
      check(); const secret = await vault.get(spec.uid);
      if (secret.password.length < 24 || secret.provisioningNonce.length < 40) fail('secure external provisioning vault required');
      let u = await user(spec.uid), intent = await read(authOwnerPath(spec.uid));
      if (!intent) {
        if (u) fail('unowned Auth record cannot be adopted');
        intent = {schemaVersion: 1, seedId: FYP_SEED_ID, uid: spec.uid, email: spec.email, executionId: vault.executionId, manifestSha256: manifest.manifestSha256, state: 'reserved', nonceHash: nonceHash(secret.provisioningNonce), preparedAtMillis: now()};
        await db.doc(authOwnerPath(spec.uid)).create(intent); await audit('auth-intent-created', authOwnerPath(spec.uid), intent);
      }
      authIntent(intent, spec, secret);
      if (!u) {
        if (intent.state !== 'reserved') fail('owned Auth missing; replacement prohibited');
        await audit('auth-create-started', `auth/${spec.uid}`);
        u = await auth.createUser({uid: spec.uid, email: spec.email, emailVerified: spec.emailVerified, displayName: `FYP pending ${secret.provisioningNonce}`, disabled: true, password: secret.password});
      }
      await verifyAuth(spec, u, true, run);
      const bound = {...intent, state: 'bound', authCreatedAtMillis: created(u)};
      await db.runTransaction(async tx => {const current = (await tx.get(db.doc(authOwnerPath(spec.uid)))).data(); if (fypDigest(current ?? null) !== fypDigest(intent)) fail('Auth intent changed during binding'); tx.set(db.doc(authOwnerPath(spec.uid)), bound);});
      await vault.bind(spec.uid, created(u));
      await auth.setCustomUserClaims(spec.uid, {fypAuthCreatedAtMillis: created(u)});
      await auth.updateUser(spec.uid, {displayName: spec.displayName, disabled: true});
      await audit('auth-disabled-and-bound', `auth/${spec.uid}`);
    }
    await writeEntries(Object.entries(d.documents));
    const assignments: [string, DocumentData][] = [];
    for (const spec of d.identities) {const u = (await user(spec.uid))!; await verifyAuth(spec, u, false, run); assignments.push([`datasetAssignments/${spec.uid}`, assignmentForIdentity(spec, created(u))]);}
    await writeEntries(assignments);
    await db.runTransaction(async tx => {const current = ownedRun((await tx.get(db.doc(plan.runPath))).data()); if (current.status !== 'preparing') fail('execution state changed'); tx.set(db.doc(plan.runPath), {...current, status: 'validated', validatedAtMillis: now()});});
    const result = await validate(); await audit('source-validated-release-disabled', plan.runPath); return result;
  }
  async function activate() {
    try {
    check(); await o.activationCheck(); const verified = await validate(); if (verified.status === 'complete') return verified;
    if (!['validated', 'activating'].includes(String(verified.status))) fail('validated activation state required');
    await db.runTransaction(async tx => {const run = ownedRun((await tx.get(db.doc(plan.runPath))).data()); if (!['validated', 'activating'].includes(String(run.status))) fail('activation state changed'); tx.set(db.doc(plan.runPath), {...run, status: 'activating'});});
    for (const spec of d.identities) {check(); const u = (await user(spec.uid))!; await verifyAuth(spec, u, false, ownedRun(await read(plan.runPath))); await auth.updateUser(spec.uid, {disabled: spec.disabled}); await audit('auth-enabled-as-manifest', `auth/${spec.uid}`);}
    await o.activationCheck();
    await db.runTransaction(async tx => {const snapshots = await tx.getAll(db.doc(plan.runPath), db.doc(plan.releasePath)), run = ownedRun(snapshots[0].data()); if (run.status !== 'activating' || fypDigest(snapshots[1].data()) !== fypDigest(plan.releaseRecord)) fail('release changed before activation'); tx.set(db.doc(plan.runPath), {...run, status: 'complete', activatedAtMillis: now()}); tx.set(db.doc(plan.releasePath), {...plan.releaseRecord, enabled: true});});
    await audit('exact-fictional-release-enabled', plan.releasePath); return validate();
    } catch (error) {
      // A failed/partial enable must also close direct Rules reads, independently
      // of the callable release gate. Preserve the original failure and audit a
      // quarantine failure rather than silently claiming recovery succeeded.
      try {await disable();} catch {await audit('activation-quarantine-incomplete', plan.releasePath);}
      throw error;
    }
  }
  async function disable() {
    check();
    // Quarantine both callable and direct Rules access first. A later altered
    // assignment must be preserved, rather than preventing safe quarantine.
    await db.runTransaction(async tx => {
      const rows = await tx.getAll(...refs([plan.runPath, plan.releasePath, FYP_ROOT, ownerPath(FYP_ROOT)])), run = ownedRun(rows[0].data()), release = rows[1].data(), root = rows[2].data();
      if (!release || fypDigest({...release, enabled: false}) !== fypDigest(plan.releaseRecord) || !root
          || fypDigest(rows[3].data()) !== fypDigest(proof(FYP_ROOT, d.documents[FYP_ROOT]))
          || fypDigest(root) !== fypDigest(d.documents[FYP_ROOT]) && fypDigest(root) !== run.disabledRootDigest) fail('exact release/cohort ownership unavailable for quarantine');
      const disabled = {...root, enabled: false}; tx.set(db.doc(plan.releasePath), {...release, enabled: false}); tx.set(db.doc(FYP_ROOT), disabled);
      tx.set(db.doc(plan.runPath), {...run, status: 'disabled', disabledAtMillis: now(), disabledRootDigest: fypDigest(disabled)});
    });
    await audit('release-and-direct-reads-quarantined', plan.releasePath);
    const expected = new Map<string, DocumentData>();
    for (const spec of d.identities) {const u = await user(spec.uid); if (!u) continue; await verifyAuth(spec, u, false, {...ownedRun(await read(plan.runPath)), status: 'activating'}); expected.set(`datasetAssignments/${spec.uid}`, assignmentForIdentity(spec, created(u)));}
    await db.runTransaction(async tx => {
      const rows = await tx.getAll(...refs([plan.runPath, ...plan.assignmentPaths.flatMap(p => [p, ownerPath(p)])])), run = ownedRun(rows[0].data()), writes: [string, DocumentData][] = [];
      for (const [i, p] of plan.assignmentPaths.entries()) {
        const a = rows[1 + 2 * i].data(), ownership = rows[2 + 2 * i].data(), baseline = expected.get(p);
        if (!a && !ownership) continue;
        if (!a || !baseline || fypDigest(ownership ?? null) !== fypDigest(proof(p, baseline))
            || fypDigest(a) !== fypDigest(expectedCurrent(p,baseline,run)) && fypDigest(a) !== (run.revokedAssignmentDigests as Record<string, string> | undefined)?.[p]) fail('assignment changed; quarantine retained without overwriting it');
        writes.push([p, {...a, enabled: false, revision: Number(a.revision) + 1}]);
      }
      for (const [p, value] of writes) tx.set(db.doc(p), value);
      tx.set(db.doc(plan.runPath), {...run, revokedAssignmentDigests: Object.fromEntries(writes.map(([p, value]) => [p, fypDigest(value)]))});
    });
    for (const spec of d.identities) {const u = await user(spec.uid); if (u) {await verifyAuth(spec, u, true, {...ownedRun(await read(plan.runPath)), status: 'activating'}); await auth.updateUser(spec.uid, {disabled: true});}}
    await audit('release-and-assignments-disabled', plan.releasePath); return {releaseEnabled: false, assignmentsEnabled: false, accountsEnabled: false};
  }
  /** One bounded recovery from this execution's exact quarantine. Never restores
   * consent/history. Uses the existing lifecycle contract to reject old tokens,
   * advances assignment revisions, and keeps Auth/release off until activate. */
  async function recover() {
    check(); await o.activationCheck(); const initial=ownedRun(await read(plan.runPath));
    if(initial.status!=='disabled'||initial.recovery||!Number.isSafeInteger(initial.disabledAtMillis)||now()-Number(initial.disabledAtMillis)<2000)fail('one fresh exact-owned quarantine recovery required');
    await validate();const floor=Math.floor(now()/1000),values=new Map<string,DocumentData>(),baselines=new Map<string,DocumentData>();
    for(const spec of d.identities){
      const u=await user(spec.uid);if(!u)fail('recovery Auth missing');await verifyAuth(spec,u,false,initial);await auth.revokeRefreshTokens(spec.uid);await audit('owned-auth-refresh-tokens-revoked',`auth/${spec.uid}`);
      const path=`${FYP_ROOT}/users/${spec.uid}`,baseline=d.documents[path],aPath=`datasetAssignments/${spec.uid}`,assignment=assignmentForIdentity(spec,created(u)),current=await read(aPath);
      if(!current||current.enabled!==false||fypDigest(current)!==(initial.revokedAssignmentDigests as Record<string,string>)[aPath])fail('quarantine assignment drift');
      baselines.set(path,baseline);baselines.set(aPath,assignment);
      values.set(path,{...baseline,accountLifecycle:{schemaVersion:1,state:'active',revocationPending:false,sessionNotBeforeSeconds:floor}});
      values.set(aPath,{...assignment,revision:Number(current.revision)+1});
    }
    const recovery={schemaVersion:1,recoveredAtMillis:now(),sessionNotBeforeSeconds:floor,users:Object.fromEntries([...values].filter(([p])=>p.startsWith(FYP_ROOT+'/users/')).map(([p,v])=>[p,fypDigest(v)])),assignments:Object.fromEntries([...values].filter(([p])=>p.startsWith('datasetAssignments/')).map(([p,v])=>[p,fypDigest(v)])),assignmentRevisions:Object.fromEntries([...values].filter(([p])=>p.startsWith('datasetAssignments/')).map(([p,v])=>[p,v.revision]))};
    await o.activationCheck();
    await db.runTransaction(async tx=>{
      const paths=[plan.runPath,plan.releasePath,FYP_ROOT,ownerPath(FYP_ROOT),...[...values.keys()].flatMap(p=>[p,ownerPath(p)])],rows=await tx.getAll(...refs(paths)),run=ownedRun(rows[0].data());
      if(fypDigest(run)!==fypDigest(initial)||fypDigest(rows[1].data())!==fypDigest(plan.releaseRecord)||fypDigest(rows[2].data())!==run.disabledRootDigest||fypDigest(rows[3].data())!==fypDigest(proof(FYP_ROOT,d.documents[FYP_ROOT])))fail('quarantine changed before recovery');
      for(const[i,[p]]of [...values].entries()){const baseline=baselines.get(p)!,current=rows[4+i*2].data(),ownership=rows[5+i*2].data();if(fypDigest(ownership??null)!==fypDigest(proof(p,baseline))||fypDigest(current??null)!==(p.startsWith('datasetAssignments/')?(run.revokedAssignmentDigests as Record<string,string>)[p]:fypDigest(baseline)))fail('recovery source or assignment changed');}
      for(const[p,value]of values)tx.set(db.doc(p),value);
      tx.set(db.doc(FYP_ROOT),d.documents[FYP_ROOT]);tx.set(db.doc(plan.runPath),{...run,status:'validated',recovery});
    });
    await audit('owned-quarantine-recovered-with-new-session-floor',plan.runPath);return validate();
  }
  /** One actual denial probe for the fixed unscored fixture identity. This is
   * operator-only, never a callable. Restore advances the revision (no ABA),
   * preserves owner drift, and does not touch consent, Auth or workout data. */
  async function testRevokedFixtureAssignment(whenRevoked:()=>Promise<void>) {
    check();await validate();const initial=ownedRun(await read(plan.runPath)),uid='demo-m13-member-18',spec=d.identities.find(i=>i.uid===uid)!;
    if(initial.status!=='complete'||!initial.recovery||initial.assignmentAcceptance||spec.role!=='member')fail('one active fixed-fixture assignment probe required');
    const u=await user(uid);if(!u)fail('fixture Auth missing');await verifyAuth(spec,u,false,initial);
    const path=`datasetAssignments/${uid}`,baseline=assignmentForIdentity(spec,created(u)),original=expectedCurrent(path,baseline,initial),revoked={...original,enabled:false,revision:Number(original.revision)+1},testId=fypDigest({executionId:vault.executionId,uid,revision:original.revision,atMillis:now()});
    if(!Number.isSafeInteger(original.revision)||Number(original.revision)>Number.MAX_SAFE_INTEGER-2)fail('fixture assignment revision bound exceeded');
    const controlPaths=[plan.runPath,plan.releasePath,FYP_ROOT,path,ownerPath(path),`users/${uid}`,`orgs/gainpath/members/${uid}`];
    await db.runTransaction(async tx=>{const rows=await tx.getAll(...refs(controlPaths)),run=ownedRun(rows[0].data());if(fypDigest(run)!==fypDigest(initial)||fypDigest(rows[1].data())!==fypDigest({...plan.releaseRecord,enabled:true})||fypDigest(rows[2].data())!==fypDigest(d.documents[FYP_ROOT])||fypDigest(rows[3].data())!==fypDigest(original)||fypDigest(rows[4].data())!==fypDigest(proof(path,baseline))||rows[5].exists||rows[6].exists)fail('fixture assignment ownership changed before probe');
      tx.set(db.doc(path),revoked);tx.set(db.doc(plan.runPath),{...run,assignmentAcceptance:{schemaVersion:1,uid,testId,phase:'revoked',originalRevision:original.revision,revokedRevision:revoked.revision,revokedDigest:fypDigest(revoked),atMillis:now()}});
    });await audit('fixed-fixture-assignment-revoked-for-denial-probe',path);
    let error:unknown,failed=false;try{await whenRevoked();}catch(e){failed=true;error=e;}
    const latest=await user(uid);if(!latest)fail('fixture Auth missing before restore');await verifyAuth(spec,latest,false,ownedRun(await read(plan.runPath)));
    const restored={...original,enabled:true,revision:Number(revoked.revision)+1};
    await db.runTransaction(async tx=>{const rows=await tx.getAll(...refs(controlPaths)),run=ownedRun(rows[0].data()),probe=run.assignmentAcceptance as Record<string,unknown>,recovery=run.recovery as Record<string,unknown>;
      if(run.status!=='complete'||probe?.testId!==testId||probe.phase!=='revoked'||fypDigest(expectedCurrent(path,baseline,run))!==fypDigest(original)||fypDigest(rows[1].data())!==fypDigest({...plan.releaseRecord,enabled:true})||fypDigest(rows[2].data())!==fypDigest(d.documents[FYP_ROOT])||fypDigest(rows[3].data())!==fypDigest(revoked)||fypDigest(rows[4].data())!==fypDigest(proof(path,baseline))||rows[5].exists||rows[6].exists)fail('fixture assignment changed; automatic restore refused');
      tx.set(db.doc(path),restored);tx.set(db.doc(plan.runPath),{...run,recovery:{...recovery,assignments:{...(recovery.assignments as object),[path]:fypDigest(restored)},assignmentRevisions:{...(recovery.assignmentRevisions as object),[path]:restored.revision}},assignmentAcceptance:{...probe,phase:'complete',passed:!failed,restoredRevision:restored.revision,completedAtMillis:now()}});
    });await audit('fixed-fixture-assignment-restored-with-forward-revision',path);if(failed)throw error;
    return{tested:true,restored:true,revision:restored.revision};
  }
  async function cleanupDryRun() {
    check(); const run = ownedRun(await read(plan.runPath)), registry = await db.collection(`${FYP_ROOT}/generatedOwnership`).limit(2001).get(); if (registry.size > 2000) fail('generated ownership inventory exceeds bound');
    const runtime = new Map<string, DocumentData>(); const preserved: {path: string; reason: string}[] = [], confirmed = new Set<string>();
    for (const doc of registry.docs) {const proof = doc.data(); if (typeof proof.path !== 'string' || !proof.path.startsWith(FYP_ROOT + '/') || doc.id !== fypDigest(proof.path)) {preserved.push({path: doc.ref.path, reason: 'invalid_generated_ownership'}); continue;} runtime.set(proof.path, proof);}
    const paths = [...new Set([...plan.sourcePaths, ...runtime.keys()])].sort(), rows = await all(paths.flatMap(p => [p, ownerPath(p)])), owned: string[] = [];
    for (const [i, p] of paths.entries()) {
      const current = rows[2 * i], seedProof = rows[2 * i + 1], decision = inspectFypCleanupRecord({path: p, current, baseline: d.documents[p], seedProof, generatedProof: runtime.get(p), approvedActorIds: d.identities.map(i => i.uid)});
      const disabledRoot = p === FYP_ROOT && current?.enabled === false && fypDigest(current) === run.disabledRootDigest && fypDigest(seedProof ?? null) === fypDigest(proof(p, d.documents[p]));
      const recoveredUser=!!d.documents[p]&&p.startsWith(FYP_ROOT+'/users/')&&!!run.recovery&&fypDigest(current??null)===fypDigest(expectedCurrent(p,d.documents[p],run))&&fypDigest(seedProof??null)===fypDigest(proof(p,d.documents[p]));
      if (decision.owned || disabledRoot || recoveredUser) {owned.push(p); confirmed.add(p); if (d.documents[p]) confirmed.add(ownerPath(p)); if (runtime.has(p) && decision.owned) confirmed.add(`${FYP_ROOT}/generatedOwnership/${fypDigest(p)}`);}
      else preserved.push({path: p, reason: decision.owned ? 'control_review_required' : decision.reason});
    }
    const authBindings: {uid: string; authCreatedAtMillis: number}[] = [];
    for (const spec of d.identities) {
      const u = await user(spec.uid); if (!u) {preserved.push({path: `auth/${spec.uid}`, reason: 'owned_identity_missing'}); continue;}
      try {await verifyAuth(spec, u, false, {...run, status: 'activating'});} catch {preserved.push({path: `auth/${spec.uid}`, reason: 'identity_or_ownership_changed'}); continue;}
      if ((await all([`users/${spec.uid}`, `orgs/gainpath/members/${spec.uid}`])).some(Boolean)) {preserved.push({path: `auth/${spec.uid}`, reason: 'canonical_identity_metadata_present'}); continue;}
      authBindings.push({uid: spec.uid, authCreatedAtMillis: created(u)}); confirmed.add(authOwnerPath(spec.uid));
      const p = `datasetAssignments/${spec.uid}`, baseline = assignmentForIdentity(spec, created(u)), a = await read(p), ownership = await read(ownerPath(p));
      if (a && fypDigest(ownership ?? null) === fypDigest(proof(p, baseline)) && (fypDigest(a) === fypDigest(expectedCurrent(p,baseline,run)) || fypDigest(a) === (run.revokedAssignmentDigests as Record<string, string> | undefined)?.[p])) {confirmed.add(p); confirmed.add(ownerPath(p));}
      else preserved.push({path: p, reason: 'assignment_or_ownership_changed'});
    }
    const release = await read(plan.releasePath); if (fypDigest({...release, enabled: false}) === fypDigest(plan.releaseRecord)) confirmed.add(plan.releasePath); else preserved.push({path: plan.releasePath, reason: 'release_control_changed'});
    if (!preserved.length) confirmed.add(plan.runPath); else preserved.push({path: plan.runPath, reason: 'retain_manifest_for_preserved_resources'});
    return {dryRun: true, willDelete: false, projectId: 'gainpath-0619', databaseId: '(default)', firestorePaths: [...confirmed].sort(), authBindings, ownedSourceOrGeneratedPaths: owned, preserved, reason: 'Exact bounded source/generated/control/Auth ownership inventory only. No deletion API exists.'};
  }
  return {dryRun: async () => {await preflight(); return {dryRun: true, willWrite: false, sourceDocuments: 466, authIdentities: 27, manifestSha256: manifest.manifestSha256};}, apply, validate, activate, disable, recover, testRevokedFixtureAssignment, cleanupDryRun};
}
