import { getFirestore } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { onCall } from 'firebase-functions/v2/https';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { DomainError } from '../../platform/errors';
import { coachCommandError } from './coach-profile-callables';
import { changeCoachCertification, getCoachCertifications, type VerifiedUpload } from './coach-certification-service';
import { getCoachAccountSettings, saveCoachAccountSettings } from './coach-account-service';
async function validateUpload(path: string): Promise<VerifiedUpload> {
  const file = getStorage().bucket().file(path);
  let metadata;
  try { [metadata] = await file.getMetadata(); } catch { throw new DomainError('failed-precondition', 'Upload the certification before submitting.'); }
  const size = Number(metadata.size), type = metadata.contentType ?? '';
  if (!Number.isSafeInteger(size) || size < 1 || size > 5 * 1024 * 1024 || !['application/pdf', 'image/jpeg', 'image/png'].includes(type)) throw new DomainError('failed-precondition', 'Use a PDF, JPEG or PNG no larger than 5 MB.');
  const pinned = getStorage().bucket().file(path, { generation: metadata.generation });
  const [bytes] = await pinned.download({ start: 0, end: 15, validation: false });
  const valid = type === 'application/pdf' ? bytes.subarray(0, 5).equals(Buffer.from('%PDF-')) : type === 'image/png' ? bytes.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10])) : bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255;
  if (type === 'application/pdf') {
    const [tail] = await pinned.download({ start: Math.max(0, size - 1024), end: size - 1, validation: false });
    if (!tail.toString('latin1').includes('%%EOF')) throw new DomainError('failed-precondition', 'The uploaded PDF is incomplete.');
  }
  if (!valid) throw new DomainError('failed-precondition', 'The uploaded content does not match its file type.');
  return { generation: String(metadata.generation), contentType: type, size };
}
const store = () => new FirestoreStore(getFirestore());
export const submitCoachCertificationCommand = onCall({ enforceAppCheck: true }, async r => { try { return await changeCoachCertification(store(), r.auth, r.data, 'submit', validateUpload); } catch (e) { throw coachCommandError(e); } });
export const archiveCoachCertificationCommand = onCall({ enforceAppCheck: true }, async r => { try { return await changeCoachCertification(store(), r.auth, r.data, 'archive', validateUpload); } catch (e) { throw coachCommandError(e); } });
export const reviewCoachCertificationCommand = onCall({ enforceAppCheck: true }, async r => { try { return await changeCoachCertification(store(), r.auth, r.data, 'review', validateUpload); } catch (e) { throw coachCommandError(e); } });
export const getCoachCertificationsCommand = onCall({ enforceAppCheck: true, preserveExternalChanges: true }, async r => { try { return await getCoachCertifications(store(), r.auth, r.data); } catch (e) { throw coachCommandError(e); } });
export const getCoachAccountSettingsCommand = onCall({ enforceAppCheck: true }, async r => { try { return await getCoachAccountSettings(store(), r.auth, r.data); } catch (e) { throw coachCommandError(e); } });
export const saveCoachAccountSettingsCommand = onCall({ enforceAppCheck: true }, async r => { try { return await saveCoachAccountSettings(store(), r.auth, r.data); } catch (e) { throw coachCommandError(e); } });


import { getCoachPublishedPhoto } from './coach-photo-service';
async function downloadPublishedPhoto(path: string) {
  const file = getStorage().bucket().file(path);
  const [metadata] = await file.getMetadata();
  const size = Number(metadata.size), contentType = metadata.contentType ?? '';
  if (!Number.isSafeInteger(size) || size < 1 || size > 5 * 1024 * 1024 || !['image/jpeg', 'image/png', 'image/webp'].includes(contentType)) throw new DomainError('failed-precondition', 'Unsupported Coach photo.');
  const [bytes] = await getStorage().bucket().file(path, { generation: metadata.generation }).download({ start: 0, end: size - 1, validation: false });
  if (bytes.length !== size) throw new DomainError('failed-precondition', 'Coach photo is incomplete.');
  const valid = contentType === 'image/png' ? bytes.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10])) : contentType === 'image/jpeg' ? bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255 : bytes.subarray(0,4).toString() === 'RIFF' && bytes.subarray(8,12).toString() === 'WEBP';
  if (!valid) throw new DomainError('failed-precondition', 'Invalid Coach photo format.');
  return { contentType, bytesBase64: bytes.toString('base64') };
}
export const getCoachPublishedPhotoCommand = onCall({ enforceAppCheck: true, preserveExternalChanges: true }, async r => { try { return await getCoachPublishedPhoto(store(), r.auth, r.data, downloadPublishedPhoto); } catch (e) { throw coachCommandError(e); } });
