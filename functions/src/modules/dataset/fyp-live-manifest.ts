/** Offline exact-owner-review loader. Never initializes Firebase or chooses a project. */
import {createHash} from 'node:crypto';
import {buildFypDataset, fypDigest, FYP_ROOT, type FypDataset} from './fyp-dataset';

export const FYP_APPROVED_LIVE_MANIFEST_SHA256 = '8af85d9a07470fe2230f7fc42371d5a64618eca829fee70be1d22b2de247e855';
const accepted = new WeakMap<object, string>();
export interface FypLiveManifest {
  readonly dataset: FypDataset;
  readonly manifestSha256: string;
  readonly sourceFileSha256: string;
  readonly plan: {sourcePaths: string[]; assignmentPaths: string[]; ownershipPaths: string[]; authOwnershipPaths: string[]; runPath: string; releasePath: string; releaseRecord: Record<string, unknown>};
}
const sha = (v: string) => createHash('sha256').update(v).digest('hex');
const fail = (): never => {throw Error('FYP live manifest is not the exact owner-reviewed source.');};
export async function loadFypLiveManifest(manifestText: string, sourceText: string): Promise<FypLiveManifest> {
  if (Buffer.byteLength(manifestText) > 2_000_000 || Buffer.byteLength(sourceText) > 4_000_000 || sha(manifestText) !== FYP_APPROVED_LIVE_MANIFEST_SHA256) fail();
  const plan = JSON.parse(manifestText), source = JSON.parse(sourceText);
  if (plan.projectId !== 'gainpath-0619' || plan.databaseId !== '(default)' || plan.rootPath !== FYP_ROOT
      || plan.seedId !== 'gainpath-fyp-v1' || plan.identities?.length !== 27 || plan.executionEnabled !== false
      || source.schemaVersion !== 1 || source.sourceManifestDigest !== plan.sourceManifestDigest || sha(sourceText) !== plan.sourceRecordFileSha256) fail();
  const dataset = await buildFypDataset({anchorMillis: plan.anchorMillis});
  const encode = (v: unknown): unknown => v instanceof Date ? {$timestampMillis: v.getTime()} : Array.isArray(v) ? v.map(encode)
    : v && typeof v === 'object' ? Object.fromEntries(Object.entries(v).map(([k, x]) => [k, encode(x)])) : v;
  const records = Object.entries(dataset.documents).sort(([a], [b]) => a.localeCompare(b)).map(([path, data]) => ({path, digest: fypDigest(data), data: encode(data)}));
  if (dataset.digest !== plan.sourceManifestDigest || fypDigest(dataset.identities) !== fypDigest(plan.identities)
      || fypDigest(records) !== fypDigest(source.records) || fypDigest(Object.keys(dataset.documents).sort()) !== fypDigest(plan.sourcePaths)
      || plan.runPath !== `${FYP_ROOT}/seedRuns/gainpath-fyp-v1` || plan.releasePath !== 'datasetRuntimeReleases/fyp-v1'
      || plan.releaseRecord.enabled !== false || plan.releaseRecord.sourceManifestDigest !== dataset.digest) fail();
  const freeze = (value: unknown): void => {if (value && typeof value === 'object') {for (const child of Object.values(value)) freeze(child); Object.freeze(value);}};
  freeze(plan); freeze(dataset);
  const result = Object.freeze({dataset, manifestSha256: sha(manifestText), sourceFileSha256: sha(sourceText), plan}) as FypLiveManifest;
  accepted.set(result, plan.sourceManifestDigest); return result;
}
export function requireFypLiveManifest(manifest: FypLiveManifest): void {
  if (!accepted.has(manifest) || manifest.dataset.digest !== accepted.get(manifest)
      || fypDigest({anchorMillis: manifest.dataset.anchorMillis, identities: manifest.dataset.identities, documents: manifest.dataset.documents}) !== accepted.get(manifest)) fail();
}
