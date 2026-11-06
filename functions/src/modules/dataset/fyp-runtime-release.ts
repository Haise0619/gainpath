/** Prepared release gate only. This module initializes no SDK and enables nothing by itself. */
import {Firestore} from 'firebase-admin/firestore';
import {DomainError} from '../../platform/errors';
import {fypDigest} from './fyp-integrity';

declare const releaseBrand: unique symbol;
/** Opaque in-process authority; serialized objects never retain this grant. */
export interface FypRuntimeReleaseGrant {readonly [releaseBrand]: true}
interface ReleaseBinding {
  readonly db: Firestore;
  readonly fingerprint: string;
  readonly sourceManifestDigest: string;
  readonly authUids: ReadonlySet<string>;
}
const grants = new WeakMap<object, ReleaseBinding>();
const releasePath = 'datasetRuntimeReleases/fyp-v1';
const keys = ['schemaVersion', 'projectId', 'databaseId', 'organizationId', 'datasetId', 'seedId', 'rootPath',
  'releaseVersion', 'enabled', 'fictionalOnly', 'sourceManifestDigest', 'authUids'];
const emulatorVariables = ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST', 'FIREBASE_DATABASE_EMULATOR_HOST',
  'FIREBASE_STORAGE_EMULATOR_HOST', 'FIREBASE_EMULATOR_HUB', 'FUNCTIONS_EMULATOR', 'PUBSUB_EMULATOR_HOST', 'EVENTARC_EMULATOR'];
const unavailable = () => new DomainError('failed-precondition', 'The FYP runtime release is unavailable.');
const isDigest = (value: unknown): value is string => typeof value === 'string' && /^[a-f0-9]{64}$/.test(value);
const isUid = (value: unknown): value is string => typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(value);

function guard(db: Firestore): void {
  // Only an already-supplied Admin SDK instance can be used. No project, host,
  // emulator override or request flag can construct release authority.
  if (!(db instanceof Firestore) || emulatorVariables.some(name => process.env[name] !== undefined)
      || process.env.GOOGLE_CLOUD_UNIVERSE_DOMAIN !== undefined && process.env.GOOGLE_CLOUD_UNIVERSE_DOMAIN !== 'googleapis.com') throw unavailable();
  try {
    const settings = (db as Firestore & {_settings?: Record<string, unknown>})._settings;
    if ((db as unknown as {projectId: string}).projectId !== 'gainpath-0619' || db.databaseId !== '(default)' || !settings
        || settings.ssl !== undefined && settings.ssl !== true
        || settings.port !== undefined && settings.port !== 443
        || settings.protocol !== undefined && settings.protocol !== 'https'
        || settings.universeDomain !== undefined && settings.universeDomain !== 'googleapis.com'
        || settings.universe_domain !== undefined && settings.universe_domain !== 'googleapis.com'
        || settings.sslCreds !== undefined
        || ['host', 'servicePath', 'apiEndpoint'].some(key => settings[key] !== undefined && settings[key] !== 'firestore.googleapis.com')) throw unavailable();
  } catch {throw unavailable();}
}

function parse(raw: unknown): Omit<ReleaseBinding, 'db'> {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) throw unavailable();
  const d = raw as Record<string, unknown>;
  if (Object.keys(d).length !== keys.length || Object.keys(d).some(key => !keys.includes(key))
      || d.schemaVersion !== 1 || d.projectId !== 'gainpath-0619' || d.databaseId !== '(default)'
      || d.organizationId !== 'gainpath' || d.datasetId !== 'fyp-v1' || d.seedId !== 'gainpath-fyp-v1'
      || d.rootPath !== 'orgs/gainpath/cohorts/fyp-v1' || d.releaseVersion !== 'fyp-cohort-v1'
      || d.enabled !== true || d.fictionalOnly !== true || !isDigest(d.sourceManifestDigest)
      || !Array.isArray(d.authUids) || d.authUids.length !== 27 || !d.authUids.every(isUid) || new Set(d.authUids).size !== 27) throw unavailable();
  return {fingerprint: fypDigest(d), sourceManifestDigest: d.sourceManifestDigest, authUids: new Set(d.authUids as string[])};
}

async function read(db: Firestore): Promise<Omit<ReleaseBinding, 'db'>> {
  guard(db);
  try {
    const snapshot = await db.doc(releasePath).get();
    guard(db);
    if (!snapshot.exists) throw unavailable();
    return parse(snapshot.data());
  } catch {throw unavailable();}
}

/** Missing, disabled, malformed or unreachable server configuration fails closed. */
export async function resolveFypRuntimeRelease(db: Firestore): Promise<FypRuntimeReleaseGrant> {
  const binding = await read(db);
  const grant = Object.freeze({}) as FypRuntimeReleaseGrant;
  grants.set(grant, {...binding, db});
  return grant;
}

export function assertFypRuntimeRelease(grant: FypRuntimeReleaseGrant, db: Firestore, uid?: string, sourceManifestDigest?: string): void {
  guard(db);
  const binding = grants.get(grant);
  if (!binding || binding.db !== db) throw unavailable();
  if (uid !== undefined && (!isUid(uid) || !binding.authUids.has(uid))) throw unavailable();
  if (sourceManifestDigest !== undefined && (!isDigest(sourceManifestDigest) || sourceManifestDigest !== binding.sourceManifestDigest)) throw unavailable();
}

/** Re-check the same explicit server release before returning a protected result. */
export async function revalidateFypRuntimeRelease(grant: FypRuntimeReleaseGrant, db: Firestore): Promise<void> {
  assertFypRuntimeRelease(grant, db);
  const current = await read(db);
  if (current.fingerprint !== grants.get(grant)!.fingerprint) throw unavailable();
}
