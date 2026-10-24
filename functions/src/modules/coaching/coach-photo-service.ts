import { DomainError } from '../../platform/errors';
import type { DocumentData, DocumentStore } from '../../platform/firestore/store';
import { prefetchReads } from '../../platform/firestore/prefetch-reads';
import { requiredIdentifier } from '../../platform/validation';
import { coachAuthority, commandContext, type CoachAuth } from './coach-management-common';
// The frozen lifecycle module keeps its decoder private. Mirror its persisted
// invariants here without changing that module or accepting old bearer sessions.
function requireCurrentMemberSession(user: DocumentData, token: Record<string, unknown>) {
  const raw = user.accountLifecycle;
  if (raw === undefined) return;
  const deny = () => { throw new DomainError('permission-denied', 'A current active Member session is required.'); };
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) deny();
  const value = raw as DocumentData;
  const integer = (v: unknown): v is number => Number.isSafeInteger(v) && Number(v) >= 0;
  const identifier = (v: unknown) => typeof v === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(v);
  if (value.schemaVersion !== 1 || value.state !== 'active' || value.revocationPending !== false
    || !integer(value.revision) || value.revision < 1
    || !integer(value.requestedAtMillis) || value.requestedAtMillis === 0
    || !integer(value.updatedAtMillis) || value.updatedAtMillis < value.requestedAtMillis
    || !integer(value.sessionNotBeforeSeconds) || value.sessionNotBeforeSeconds !== Math.floor(value.requestedAtMillis / 1000) + 1
    || !integer(value.sessionRevokedAtMillis) || value.sessionRevokedAtMillis < value.requestedAtMillis
    || !integer(value.reactivatedAtMillis) || value.reactivatedAtMillis < value.requestedAtMillis
    || !integer(value.revocationLeaseUntilMillis)
    || !(value.revocationAttemptId === null || identifier(value.revocationAttemptId))
    || !identifier(value.lastRequestId)
    || !((value.policy === 'pendingApproval' && value.retentionEndsAtMillis === null)
      || (value.policy === 'grace30Days' && value.retentionEndsAtMillis === value.requestedAtMillis + 30 * 86_400_000))
    || !integer(token.auth_time) || token.auth_time < value.sessionNotBeforeSeconds) deny();
}
export type PublishedPhotoDownload = (path: string) => Promise<{ contentType: string; bytesBase64: string }>;
export async function getCoachPublishedPhoto(store: DocumentStore, auth: CoachAuth, raw: unknown, download: PublishedPhotoDownload) {
  const { uid, org, data } = commandContext(auth, raw, ['schemaVersion', 'organizationId', 'coachId']);
  const coachId = requiredIdentifier(data.coachId, 'coachId'), publicPath = `orgs/${org}/coaches/${coachId}`;
  const read = () => store.transact(async tx => {
    const facts = await prefetchReads(tx, [`users/${uid}`, `orgs/${org}/members/${uid}`, `orgs/${org}`, publicPath]);
    await coachAuthority(facts, org, uid, ['member', 'coach', 'admin']);
    const member = await facts.get(`orgs/${org}/members/${uid}`);
    if (member?.role === 'member') requireCurrentMemberSession((await facts.get(`users/${uid}`))!, auth!.token);
    const profile = await facts.get(publicPath);
    if (profile?.status !== 'published' || profile.certificationVerified !== true || !Number.isSafeInteger(profile.approvedCertificationCount) || Number(profile.approvedCertificationCount) < 1) throw new DomainError('not-found', 'Published Coach photo unavailable.');
    const path = profile.photoPath;
    if (path === null || path === undefined) return { path: null, revision: profile.revision };
    const prefix = `orgs/${org}/coachProfilePhotos/${coachId}/`;
    if (typeof path !== 'string' || !path.startsWith(prefix) || !/^[a-f0-9]{32}$/.test(path.slice(prefix.length))) throw new DomainError('failed-precondition', 'Photo requires review.');
    return { path, revision: profile.revision };
  });
  const initial = await read();
  if (!initial.path) return { schemaVersion: 1, photoPath: null, contentType: null, bytesBase64: null };
  const image = await download(initial.path);
  const current = await read();
  if (current.path !== initial.path || current.revision !== initial.revision) throw new DomainError('aborted', 'Coach listing changed. Reload the photo.');
  return { schemaVersion: 1, photoPath: initial.path, ...image };
}
