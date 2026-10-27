import {createHash} from 'node:crypto';
import {requireActiveMembership, requireVerifiedEmail} from '../../platform/auth-context';
import {DomainError} from '../../platform/errors';
import {readAll, type DocumentData, type DocumentStore, type TransactionPort} from '../../platform/firestore/store';
import {InputValidationError, requiredIdentifier} from '../../platform/validation';

export type MiniGameAuth = {uid: string; token: Record<string, unknown>};
export type MiniGameMediaKind = 'cover' | 'preview';
export interface MiniGameMediaStore {
  /** Immutable create, or return the existing URL only when bytes/type/digest match. */
  upload(path: string, bytes: Buffer, contentType: string, sha256: string): Promise<string>;
}
export interface MiniGameContentDependencies {
  media: MiniGameMediaStore;
  freshAuth(auth: MiniGameAuth): Promise<void>;
  clock?: () => number;
}
export interface MiniGameContent {
  schemaVersion: 1;
  organizationId: string;
  gameId: string;
  revision: number;
  title: string;
  introduction: string;
  instructions: string[];
  coverUrl: string;
  previewVideoUrl: string;
  updatedAtMillis: number;
}
const GAME_ID = 'move-catch-v1';
const CONTENT_FIELDS = ['title', 'introduction', 'instructions', 'coverUrl', 'previewVideoUrl'];
const integer = (v: unknown, minimum = 0): v is number => Number.isSafeInteger(v) && Number(v) >= minimum;
const identifier = (v: unknown): v is string => typeof v === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(v);
const hexId = (v: unknown): v is string => typeof v === 'string' && /^[a-f0-9]{32}$/.test(v);
const text = (v: unknown, max: number): v is string => typeof v === 'string' && v.trim().length > 0 && v.length <= max
  && !/[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/.test(v);
const url = (v: unknown): v is string => {
  if (typeof v !== 'string' || v.length > 2048) return false;
  if (v === '') return true;
  try {const u = new URL(v); return u.protocol === 'https:' && !u.username && !u.password && u.href === v;} catch {return false;}
};
const digest = (...parts: string[]) => createHash('sha256').update(JSON.stringify(parts)).digest('hex');
const unavailable = () => new DomainError('failed-precondition', 'Mini-game content is unavailable. Reload before editing.');
const deny = () => new DomainError('permission-denied', 'Current verified organization authority is required.');

function validContent(d: DocumentData): boolean {
  return text(d.title, 80) && text(d.introduction, 2000) && Array.isArray(d.instructions)
    && d.instructions.length >= 1 && d.instructions.length <= 8 && d.instructions.every(v => text(v, 500))
    && url(d.coverUrl) && url(d.previewVideoUrl);
}
/** Registry defaults describe the implemented game; reading them never seeds Firestore. */
function builtin(org: string): MiniGameContent {
  return {schemaVersion: 1, organizationId: org, gameId: GAME_ID, revision: 0, title: 'Move & Catch',
    introduction: 'Lean left and right to catch stars and avoid obstacles in a 40-second round.',
    instructions: ['Face the camera with your shoulders and hips visible.',
      'Hold your starting position for calibration, then start the round.',
      'Lean gently to catch stars and avoid diamonds. Return into view during the tracking warning.'],
    coverUrl: '', previewVideoUrl: '', updatedAtMillis: 0};
}
function serialized(d: DocumentData | undefined, org: string): MiniGameContent {
  if (!d) return builtin(org);
  if (d.schemaVersion !== 1 || d.organizationId !== org || d.gameId !== GAME_ID || !integer(d.revision, 1)
      || !integer(d.updatedAtMillis, 1) || d.updatedAtMillis > 8640000000000000 || !validContent(d)) throw unavailable();
  return {schemaVersion: 1, organizationId: org, gameId: GAME_ID, revision: d.revision,
    title: d.title as string, introduction: d.introduction as string, instructions: [...d.instructions as string[]],
    coverUrl: d.coverUrl as string, previewVideoUrl: d.previewVideoUrl as string, updatedAtMillis: d.updatedAtMillis};
}

/** Canonical roles/lifecycle are independent of reward eligibility and paid membership. */
async function authorize(tx: TransactionPort, auth: MiniGameAuth, org: string, write: boolean) {
  const [user, membership, organization] = await readAll(tx, [`users/${auth.uid}`, `orgs/${org}/members/${auth.uid}`, `orgs/${org}`]);
  const role = requireActiveMembership(membership).role;
  if (!(write ? role === 'admin' : ['member', 'admin', 'staff'].includes(role))
      || organization?.status !== 'active' || user?.organizationId !== org
      || (user.role !== undefined && user.role !== role) || membership?.organizationId !== org
      || (membership.userId !== undefined && membership.userId !== auth.uid)) throw deny();
  const lifecycle = user.accountLifecycle as DocumentData | undefined;
  if (lifecycle !== undefined && (!lifecycle || lifecycle.schemaVersion !== 1 || lifecycle.state !== 'active'
      || lifecycle.revocationPending !== false || !integer(lifecycle.sessionNotBeforeSeconds)
      || (lifecycle.sessionNotBeforeSeconds > 0 && (!integer(auth.token.auth_time)
        || auth.token.auth_time < lifecycle.sessionNotBeforeSeconds)))) throw deny();
}
function request(raw: unknown): DocumentData {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) throw new InputValidationError('Mini-game command required.');
  const d = raw as DocumentData;
  const actions: Record<string, string[]> = {
    list: [], save: ['gameId', 'requestId', 'baseRevision', ...CONTENT_FIELDS],
    uploadMedia: ['gameId', 'kind', 'uploadId', 'contentType', 'dataBase64'],
  };
  if (d.schemaVersion !== 1 || typeof d.action !== 'string' || !Object.hasOwn(actions, d.action)) throw new InputValidationError('Unsupported mini-game command.');
  const fields = ['schemaVersion', 'organizationId', 'action', ...actions[d.action]];
  if (Object.keys(d).length !== fields.length || Object.keys(d).some(k => !fields.includes(k))) throw new InputValidationError('Invalid mini-game command fields.');
  requiredIdentifier(d.organizationId, 'organizationId');
  if (d.action !== 'list' && d.gameId !== GAME_ID) throw new InputValidationError('Only existing supported games can be edited.');
  if (d.action === 'save' && (!hexId(d.requestId) || !integer(d.baseRevision) || d.baseRevision >= Number.MAX_SAFE_INTEGER || !validContent(d))) throw new InputValidationError('Invalid mini-game content.');
  return d;
}
function mediaInput(d: DocumentData) {
  const cover = d.kind === 'cover', preview = d.kind === 'preview', limit = (cover ? 5 : 20) * 1024 * 1024;
  if ((!cover && !preview) || !hexId(d.uploadId) || typeof d.contentType !== 'string'
      || !(cover ? ['image/jpeg', 'image/png', 'image/webp'] : ['video/mp4']).includes(d.contentType)
      || typeof d.dataBase64 !== 'string' || !d.dataBase64.length || d.dataBase64.length > Math.ceil(limit / 3) * 4
      || /[^A-Za-z0-9+/=]/.test(d.dataBase64)) throw new InputValidationError('Choose JPG/PNG/WebP up to 5 MB or an MP4 preview up to 20 MB.');
  const bytes = Buffer.from(d.dataBase64, 'base64');
  if (!bytes.length || bytes.length > limit || bytes.toString('base64') !== d.dataBase64) throw new InputValidationError('Invalid media encoding or size.');
  const starts = (a: number[]) => a.every((v, i) => bytes[i] === v);
  const imageType = starts([255, 216, 255]) ? 'image/jpeg' : starts([137, 80, 78, 71, 13, 10, 26, 10]) ? 'image/png'
    : starts([82, 73, 70, 70]) && bytes.length >= 12 && bytes.subarray(8, 12).toString('ascii') === 'WEBP' ? 'image/webp' : null;
  // ISO BMFF files must carry a complete bounded ftyp box and a supported MP4 brand.
  const boxSize = bytes.length >= 16 ? bytes.readUInt32BE(0) : 0;
  const mp4 = bytes.length >= 16 && bytes.subarray(4, 8).toString('ascii') === 'ftyp'
    && boxSize >= 16 && boxSize <= bytes.length && boxSize <= 1024 && (boxSize - 16) % 4 === 0
    && [8, ...Array.from({length: Math.max(0, (boxSize - 16) / 4)}, (_, i) => 16 + i * 4)]
      .some(offset => ['isom', 'iso2', 'iso3', 'iso4', 'iso5', 'iso6', 'mp41', 'mp42', 'avc1', 'M4V '].includes(bytes.subarray(offset, offset + 4).toString('ascii')));
  if (cover ? imageType !== d.contentType : !mp4) throw new InputValidationError('Media content does not match its type.');
  return {bytes, kind: d.kind as MiniGameMediaKind, contentType: d.contentType,
    sha256: createHash('sha256').update(bytes).digest('hex')};
}
const receiptPath = (org: string, kind: MiniGameMediaKind, mediaUrl: string) => `orgs/${org}/miniGameMediaReceipts/${digest(GAME_ID, kind, mediaUrl)}`;
function validMediaReceipt(r: DocumentData | undefined, org: string, kind: MiniGameMediaKind, mediaUrl: string): r is DocumentData {
  return !!r && r.schemaVersion === 1 && r.organizationId === org && r.gameId === GAME_ID && r.kind === kind && r.url === mediaUrl
    && identifier(r.uploadedBy) && hexId(r.uploadId) && typeof r.sha256 === 'string' && /^[a-f0-9]{64}$/.test(r.sha256)
    && integer(r.createdAtMillis, 1) && integer(r.sizeBytes, 1)
    && r.sizeBytes <= (kind === 'cover' ? 5 : 20) * 1024 * 1024
    && (kind === 'cover' ? ['image/jpeg', 'image/png', 'image/webp'] : ['video/mp4']).includes(String(r.contentType))
    && r.objectPath === `orgs/${org}/miniGameMedia/${GAME_ID}/${kind}/${r.uploadedBy}/${r.uploadId}`;
}

/** The only editable surface is descriptive content for the fixed supported registry. */
export async function miniGameContent(store: DocumentStore, auth: MiniGameAuth | undefined, raw: unknown, deps: MiniGameContentDependencies): Promise<Record<string, any>> {
  requireVerifiedEmail(auth);
  const d = request(raw), org = d.organizationId as string, uid = requiredIdentifier(auth!.uid, 'uid');
  const write = d.action !== 'list', clock = deps.clock ?? Date.now;
  const time = () => {const at = clock(); if (!integer(at, 1) || at > 8640000000000000) throw unavailable(); return at;};
  await deps.freshAuth(auth!);
  let result: Record<string, any>;
  if (d.action === 'uploadMedia') {
    await store.transact(tx => authorize(tx, auth!, org, true));
    const input = mediaInput(d);
    const objectPath = `orgs/${org}/miniGameMedia/${GAME_ID}/${input.kind}/${uid}/${d.uploadId}`;
    const mediaUrl = await deps.media.upload(objectPath, input.bytes, input.contentType, input.sha256);
    if (!url(mediaUrl) || !mediaUrl) throw unavailable();
    await deps.freshAuth(auth!);
    await store.transact(async tx => {
      await authorize(tx, auth!, org, true);
      const p = receiptPath(org, input.kind, mediaUrl), prior = await tx.get(p);
      if (prior) {
        if (!validMediaReceipt(prior, org, input.kind, mediaUrl) || prior.uploadedBy !== uid || prior.uploadId !== d.uploadId
            || prior.sha256 !== input.sha256 || prior.contentType !== input.contentType || prior.sizeBytes !== input.bytes.length) throw new DomainError('already-exists', 'Upload reference already used for different media.');
      } else tx.create(p, {schemaVersion: 1, organizationId: org, gameId: GAME_ID, kind: input.kind, url: mediaUrl,
        objectPath, uploadedBy: uid, uploadId: d.uploadId, sha256: input.sha256, contentType: input.contentType, sizeBytes: input.bytes.length, createdAtMillis: time()});
    });
    result = {schemaVersion: 1, organizationId: org, gameId: GAME_ID, kind: input.kind, url: mediaUrl};
  } else result = await store.transact(async tx => {
    await authorize(tx, auth!, org, write);
    const contentPath = `orgs/${org}/miniGameContent/${GAME_ID}`;
    if (d.action === 'list') return {schemaVersion: 1, organizationId: org, games: [serialized(await tx.get(contentPath), org)]};
    const fingerprint = digest(GAME_ID, String(d.baseRevision), ...CONTENT_FIELDS.map(k => JSON.stringify(d[k])));
    const p = `orgs/${org}/miniGameContentRequests/${digest(uid, d.requestId as string)}`, prior = await tx.get(p);
    if (prior) {
      if (prior.schemaVersion !== 1 || prior.organizationId !== org || prior.gameId !== GAME_ID || prior.uid !== uid || prior.requestId !== d.requestId) throw unavailable();
      if (prior.fingerprint !== fingerprint) throw new DomainError('already-exists', 'Request reference already used. Retry the original request or reload.');
      if (!prior.game || typeof prior.game !== 'object' || Array.isArray(prior.game)) throw unavailable();
      const game = serialized(prior.game as DocumentData, org);
      if (game.revision !== Number(d.baseRevision) + 1
          || CONTENT_FIELDS.some(k => JSON.stringify((game as unknown as DocumentData)[k]) !== JSON.stringify(d[k]))) throw unavailable();
      return {schemaVersion: 1, organizationId: org, confirmed: true, game};
    }
    const current = serialized(await tx.get(contentPath), org);
    if (current.revision !== d.baseRevision) throw new DomainError('aborted', 'Mini-game content changed. Reload and review the latest revision.');
    for (const [kind, field] of [['cover', 'coverUrl'], ['preview', 'previewVideoUrl']] as const) {
      const mediaUrl = d[field] as string;
      if (mediaUrl && !validMediaReceipt(await tx.get(receiptPath(org, kind, mediaUrl)), org, kind, mediaUrl)) throw new DomainError('permission-denied', 'Upload media for this organization and game before saving.');
    }
    const game: MiniGameContent = {schemaVersion: 1, organizationId: org, gameId: GAME_ID, revision: current.revision + 1,
      title: d.title as string, introduction: d.introduction as string, instructions: [...d.instructions as string[]],
      coverUrl: d.coverUrl as string, previewVideoUrl: d.previewVideoUrl as string, updatedAtMillis: time()};
    tx.set(contentPath, {...game, updatedBy: uid});
    tx.create(p, {schemaVersion: 1, organizationId: org, gameId: GAME_ID, uid, requestId: d.requestId, fingerprint, game});
    return {schemaVersion: 1, organizationId: org, confirmed: true, game};
  });
  await deps.freshAuth(auth!);
  await store.transact(tx => authorize(tx, auth!, org, write));
  return result;
}
