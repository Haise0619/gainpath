import {DomainError} from '../../platform/errors';
import type {DocumentData} from '../../platform/firestore/store';
const fail = () => new DomainError('failed-precondition', 'Reward information is unavailable.');
function text(v: unknown, max: number, required = false): string {
  if (typeof v !== 'string' || v.length > max || v.includes('\u0000') || (required && !v.trim())) throw fail();
  return v;
}
export function rewardContent(d: DocumentData) {
  if (d.rewardDetailsVersion === undefined) return null;
  if (d.rewardDetailsVersion !== 1) throw fail();
  const imageUrl = text(d.imageUrl, 2048);
  if (imageUrl) {let uri: URL; try {uri = new URL(imageUrl);} catch (_) {throw fail();}
    if (uri.protocol !== 'https:' || !uri.hostname || uri.username || uri.password || /\s/.test(imageUrl)) throw fail();}
  return {rewardDetailsVersion: 1, description: text(d.description, 2000), imageUrl,
    conditions: text(d.conditions, 2000, true), collectionInstructions: text(d.collectionInstructions, 2000, true)};
}
export function rewardItemDetails(d: DocumentData) {
  const content = rewardContent(d);
  if (!content) return null;
  if (!Number.isSafeInteger(d.validityDays) || Number(d.validityDays) < 1 || Number(d.validityDays) > 365) throw fail();
  return {...content, validityDays: Number(d.validityDays)};
}
export function rewardVoucherDetails(d: DocumentData) {
  const content = rewardContent(d);
  if (!content) {
    if (d.expiresAtMillis !== undefined || d.expiredPointsPolicy !== undefined) throw fail();
    return null;
  }
  if (!Number.isSafeInteger(d.expiresAtMillis) || Number(d.expiresAtMillis) <= Number(d.issuedAtMillis) || Number(d.expiresAtMillis) > 8640000000000000 ||
      d.expiredPointsPolicy !== 'remain_spent' || (d.status === 'fulfilled' && (Number(d.fulfilledAtMillis) < Number(d.issuedAtMillis) || Number(d.fulfilledAtMillis) >= Number(d.expiresAtMillis)))) throw fail();
  return {...content, expiresAtMillis: Number(d.expiresAtMillis), expiredPointsPolicy: 'remain_spent'};
}
