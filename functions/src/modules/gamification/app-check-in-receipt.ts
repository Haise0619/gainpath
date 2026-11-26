import type { DocumentData } from '../../platform/firestore/store';

/** Accept base-only receipts and receipts that snapshot a configured bonus. */
export function validCheckInBonusReceipt(raw: DocumentData, base: number) {
  const { basePoints, premiumBonusPoints, premiumBonusPolicyVersion, points } = raw;
  if (premiumBonusPoints === undefined) {
    return basePoints === undefined && premiumBonusPolicyVersion === undefined && points === base;
  }
  return basePoints === base && typeof premiumBonusPoints === 'number' &&
    Number.isSafeInteger(premiumBonusPoints) && premiumBonusPoints > 0 &&
    typeof premiumBonusPolicyVersion === 'string' &&
    premiumBonusPolicyVersion.trim().length > 0 && premiumBonusPolicyVersion.length <= 128 &&
    Number.isSafeInteger(points) && points === base + premiumBonusPoints;
}
