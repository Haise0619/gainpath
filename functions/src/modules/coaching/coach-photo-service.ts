import { DomainError } from '../../platform/errors';
import type { DocumentStore } from '../../platform/firestore/store';
import { requiredIdentifier } from '../../platform/validation';
import { coachAuthority, commandContext, type CoachAuth } from './coach-management-common';
export type PublishedPhotoDownload = (path: string) => Promise<{ contentType: string; bytesBase64: string }>;
export async function getCoachPublishedPhoto(store: DocumentStore, auth: CoachAuth, raw: unknown, download: PublishedPhotoDownload) {
  const { uid, org, data } = commandContext(auth, raw, ['schemaVersion', 'organizationId', 'coachId']);
  const coachId = requiredIdentifier(data.coachId, 'coachId'), publicPath = `orgs/${org}/coaches/${coachId}`;
  const read = () => store.transact(async tx => {
    await coachAuthority(tx, org, uid, ['member', 'coach', 'admin']);
    const profile = await tx.get(publicPath);
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
