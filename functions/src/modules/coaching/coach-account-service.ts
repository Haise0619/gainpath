import { DomainError } from '../../platform/errors';
import type { DocumentStore } from '../../platform/firestore/store';
import { keyOf } from '../../platform/idempotency';
import { InputValidationError } from '../../platform/validation';
import { coachAuthority, commandContext, expectedRevision, receipt, replayReceipt, saveReceipt, type CoachAuth } from './coach-management-common';
const preferenceKeys = ['newBookings', 'cancellations', 'reminders'];
const defaults = { newBookings: true, cancellations: true, reminders: false };
export async function getCoachAccountSettings(store: DocumentStore, auth: CoachAuth, raw: unknown) {
  const { uid, org } = commandContext(auth, raw, ['schemaVersion', 'organizationId']);
  return store.transact(async tx => { await coachAuthority(tx, org, uid, ['coach']); const user = (await tx.get(`users/${uid}`))!; return { schemaVersion: 1, revision: user.coachAccountRevision ?? 0, updatedAtMillis: user.coachAccountUpdatedAtMillis ?? null, contactPhone: user.contactPhone ?? '', coachNotificationPreferences: user.coachNotificationPreferences ?? defaults }; });
}
export async function saveCoachAccountSettings(store: DocumentStore, auth: CoachAuth, raw: unknown, clock = Date.now) {
  const { uid, org, data } = commandContext(auth, raw, ['schemaVersion', 'organizationId', 'requestId', 'expectedRevision', 'contactPhone', 'coachNotificationPreferences']);
  const expected = expectedRevision(data.expectedRevision);
  if (typeof data.contactPhone !== 'string') throw new InputValidationError('Phone must be E.164.');
  const phone = data.contactPhone.trim().replace(/[ ()-]/g, '');
  if (phone !== '' && !/^\+[1-9]\d{7,14}$/.test(phone)) throw new InputValidationError('Phone must be E.164.');
  const prefs = data.coachNotificationPreferences as Record<string, unknown>;
  if (!prefs || typeof prefs !== 'object' || Object.keys(prefs).length !== 3 || preferenceKeys.some(k => typeof prefs[k] !== 'boolean')) throw new InputValidationError('Invalid notification preferences.');
  const preferences = Object.fromEntries(preferenceKeys.map(k => [k, prefs[k]]));
  const fingerprint = keyOf(org, expected, phone, preferences), receiptPath = receipt(org, uid, 'saveCoachAccountSettings', data.requestId);
  return store.transact(async tx => {
    await coachAuthority(tx, org, uid, ['coach']);
    const prior = replayReceipt(await tx.get(receiptPath), fingerprint); if (prior) return prior;
    const userPath = `users/${uid}`, user = (await tx.get(userPath))!;
    if ((user.coachAccountRevision ?? 0) !== expected) throw new DomainError('aborted', 'Account settings changed. Reload first.');
    const claimPath = phone ? `phoneClaims/${keyOf(phone)}` : null, claim = claimPath ? await tx.get(claimPath) : undefined;
    const oldPhone = typeof user.contactPhone === 'string' ? user.contactPhone : null;
    const oldClaimPath = oldPhone ? `phoneClaims/${keyOf(oldPhone)}` : null;
    const oldClaim = oldClaimPath && oldClaimPath !== claimPath ? await tx.get(oldClaimPath) : null;
    if (claim && claim.uid !== uid && claim.active !== false) throw new DomainError('already-exists', 'Phone is already in use.');
    const now = clock(), revision = expected + 1;
    if (claimPath) tx.set(claimPath, { uid, organizationId: org, active: true, updatedAtMillis: now });
    if (oldClaimPath && oldClaimPath !== claimPath && oldClaim?.uid === uid) tx.set(oldClaimPath, { ...oldClaim, active: false, updatedAtMillis: now });
    tx.set(userPath, { ...user, contactPhone: phone, coachNotificationPreferences: preferences, coachAccountRevision: revision, coachAccountUpdatedAtMillis: now });
    const result = { schemaVersion: 1, revision, updatedAtMillis: now, contactPhone: phone, coachNotificationPreferences: preferences };
    saveReceipt(tx, receiptPath, uid, fingerprint, result, now); return result;
  });
}
