import { DomainError } from '../../platform/errors';
import type { DocumentData, DocumentStore } from '../../platform/firestore/store';
import { readAll } from '../../platform/firestore/store';
import { prefetchReads } from '../../platform/firestore/prefetch-reads';
import { keyOf } from '../../platform/idempotency';
import { InputValidationError, requiredIdentifier } from '../../platform/validation';
import { boundedText, coachAuthority, commandContext, credentialGateEnabled, expectedRevision, receipt, replayReceipt, saveReceipt, type CoachAuth } from './coach-management-common';
export interface VerifiedUpload { generation: string; contentType: string; size: number; }
export type UploadValidator = (path: string) => Promise<VerifiedUpload>;
export async function changeCoachCertification(store: DocumentStore, auth: CoachAuth, raw: unknown, action: 'submit' | 'archive' | 'review', validator: UploadValidator, clock = Date.now) {
  const allowed = ['schemaVersion', 'organizationId', 'requestId', 'certificationId', ...(action === 'submit' ? ['title', 'issuer', 'storagePath'] : ['expectedRevision']), ...(action === 'review' ? ['coachId', 'decision', 'reason'] : [])];
  const { uid, org, data } = commandContext(auth, raw, allowed);
  const coachId = action === 'review' ? requiredIdentifier(data.coachId, 'coachId') : uid;
  const id = boundedText(data.certificationId, 32); if (!/^[a-f0-9]{32}$/.test(id)) throw new InputValidationError('Invalid certification ID.');
  const path = `orgs/${org}/coachProfiles/${coachId}/certifications/${id}`, summaryPath = `orgs/${org}/coachProfiles/${coachId}/certificationState/current`;
  const uploadPath = `orgs/${org}/coachCertifications/${coachId}/${id}`;
  const fields: DocumentData = action === 'submit' ? { title: boundedText(data.title, 120), issuer: boundedText(data.issuer, 120), storagePath: data.storagePath } : {};
  if (action === 'submit' && data.storagePath !== uploadPath) throw new InputValidationError('Invalid upload path.');
  const expected = action === 'submit' ? 0 : expectedRevision(data.expectedRevision);
  if (action === 'review' && !['approve', 'reject'].includes(String(data.decision))) throw new InputValidationError('Invalid decision.');
  const reason = action === 'review' && data.decision === 'reject' ? boundedText(data.reason, 1000) : null;
  const fingerprint = keyOf(action, coachId, id, expected, fields, data.decision ?? null, reason), receiptPath = receipt(org, uid, `certification:${action}`, data.requestId);
  const prior = await store.transact(async tx => { await coachAuthority(tx, org, uid, [action === 'review' ? 'admin' : 'coach']); return replayReceipt(await tx.get(receiptPath), fingerprint); });
  if (prior) return prior;
  const upload = action === 'submit' ? await validator(uploadPath) : null;
  return store.transact(async tx => {
    await coachAuthority(tx, org, uid, [action === 'review' ? 'admin' : 'coach']);
    if (action === 'review') await coachAuthority(tx, org, coachId, ['coach']);
    const prior = replayReceipt(await tx.get(receiptPath), fingerprint); if (prior) return prior;
    const current = await tx.get(path), state = await tx.get(summaryPath), publicPath = `orgs/${org}/coaches/${coachId}`, publicDoc = await tx.get(publicPath);
    if ((current?.revision ?? 0) !== expected) throw new DomainError('aborted', 'Certification changed. Reload before continuing.');
    if (action !== 'submit' && !current) throw new DomainError('not-found', 'Certification unavailable.');
    if (current?.status === 'archived') throw new DomainError('failed-precondition', 'Archived certification cannot change. Upload a new certification.');
    const ids = Array.isArray(state?.certificationIds) ? state.certificationIds as string[] : [];
    if (action === 'submit' && ids.length >= 100) throw new DomainError('resource-exhausted', 'Certification limit reached.');
    const status = action === 'submit' ? 'pending' : action === 'archive' ? 'archived' : data.decision === 'approve' ? 'approved' : 'rejected';
    const approvedCount = Number(state?.approvedCount ?? 0) + (status === 'approved' ? 1 : 0) - (current?.status === 'approved' ? 1 : 0);
    if (!Number.isSafeInteger(approvedCount) || approvedCount < 0) throw new DomainError('failed-precondition', 'Certification summary requires review.');
    if (expected >= 100) throw new DomainError('resource-exhausted', 'Certification revision limit reached. Upload a new certification.');
    const now = clock(), revision = expected + 1;
    const next = { ...current, ...fields, ...(upload ? { upload } : {}), schemaVersion: 1, id, coachId, status, revision, reason, actorId: uid, createdAtMillis: current?.createdAtMillis ?? now, updatedAtMillis: now };
    tx.set(path, next); tx.create(`${path}/history/${revision}`, next);
    tx.set(summaryPath, { schemaVersion: 1, certificationIds: action === 'submit' ? [...ids, id] : ids, approvedCount, certificationVerified: approvedCount > 0, updatedAtMillis: now });
    if (publicDoc) tx.set(publicPath, { ...publicDoc, certificationVerified: approvedCount > 0, approvedCertificationCount: approvedCount, ...(credentialGateEnabled() && approvedCount === 0 && publicDoc.status === 'published' ? { status: 'inactive' } : {}), revision: Number(publicDoc.revision) + 1, updatedAtMillis: now });
    const result = { schemaVersion: 1, certificationId: id, revision, status, certificationVerified: approvedCount > 0, approvedCount };
    saveReceipt(tx, receiptPath, uid, fingerprint, result, now); return result;
  });
}

export async function getCoachCertifications(store: DocumentStore, auth: CoachAuth, raw: unknown) {
  const { uid, org, data } = commandContext(auth, raw, ['schemaVersion', 'organizationId', 'coachId', 'afterId', 'certificationId']);
  const coachId = data.coachId === undefined ? uid : requiredIdentifier(data.coachId, 'coachId');
  const selectedId = data.certificationId === undefined ? null : boundedText(data.certificationId, 32);
  const afterId = data.afterId === undefined ? null : boundedText(data.afterId, 32);
  if ([selectedId, afterId].some(id => id !== null && !/^[a-f0-9]{32}$/.test(id)) || (selectedId && afterId)) throw new InputValidationError('Invalid certification cursor.');
  return store.transact(async tx => {
    const summaryPath = `orgs/${org}/coachProfiles/${coachId}/certificationState/current`;
    const facts = await prefetchReads(tx, [`users/${uid}`, `orgs/${org}/members/${uid}`, `orgs/${org}`, summaryPath]);
    await coachAuthority(facts, org, uid, coachId === uid ? ['coach', 'admin'] : ['admin']);
    const state = await facts.get(summaryPath);
    const ids = Array.isArray(state?.certificationIds) ? (state.certificationIds as string[]).slice().sort() : [];
    if (ids.length > 100 || ids.some(id => !/^[a-f0-9]{32}$/.test(id))) throw new DomainError('failed-precondition', 'Certification summary requires review.');
    if (selectedId && !ids.includes(selectedId)) throw new DomainError('not-found', 'Certification unavailable.');
    const remaining = selectedId ? [selectedId] : ids.filter(id => !afterId || id > afterId);
    const page = remaining.slice(0, 20), certifications = [];
    const items = await readAll(tx, page.map(id => `orgs/${org}/coachProfiles/${coachId}/certifications/${id}`));
    for (const [index, id] of page.entries()) {
      const item = items[index];
      if (!item) continue;
      const history = [], revision = Number(item.revision);
      if (!Number.isSafeInteger(revision) || revision < 1 || revision > 100) throw new DomainError('failed-precondition', 'Certification needs review.');
      if (selectedId) {
        const paths = Array.from({ length: Math.min(20, revision) }, (_, i) => `orgs/${org}/coachProfiles/${coachId}/certifications/${id}/history/${revision - i}`);
        for (const entry of await readAll(tx, paths)) if (entry) history.push(entry);
      }
      certifications.push({ ...item, history });
    }
    return { schemaVersion: 1, certifications, nextCursor: remaining.length > 20 ? page[page.length - 1] : null, approvedCount: state?.approvedCount ?? 0, certificationVerified: state?.certificationVerified === true };
  });
}
