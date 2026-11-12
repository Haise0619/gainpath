import type {DocumentData,TransactionPort} from '../../platform/firestore/store';
import {resolveMembershipEntitlement} from '../commerce/membership-entitlement';
import {membershipCapabilities} from '../commerce/membership-capabilities';

/** No default value or automatic activation. Missing/invalid policy preserves base earning. */
export async function premiumCheckInBonus(tx: TransactionPort,
  auth: {uid: string; token: Record<string, unknown>}, org: string, now: number, availableHeadroom: number) {
  const policy = await tx.get(`orgs/${org}/settings/premiumCheckInBonus`);
  if (!policy || policy.schemaVersion !== 1 || policy.organizationId !== org || policy.enabled !== true) return null;
  const {version, bonusPoints, effectiveFromMillis, effectiveUntilMillis} = policy;
  if (typeof version !== 'string' || !version.trim() || version.length > 128) return null;
  if (typeof bonusPoints !== 'number' || !Number.isSafeInteger(bonusPoints) || bonusPoints < 1 || bonusPoints > availableHeadroom) return null;
  if (typeof effectiveFromMillis !== 'number' || !Number.isSafeInteger(effectiveFromMillis) || effectiveFromMillis <= 0 || effectiveFromMillis > now) return null;
  if (typeof effectiveUntilMillis !== 'number' || !Number.isSafeInteger(effectiveUntilMillis) || effectiveUntilMillis <= now || effectiveUntilMillis > 8640000000000000) return null;
  const entitlement = await resolveMembershipEntitlement(tx, auth, org, now);
  return membershipCapabilities(entitlement).isEligibleForPremiumCheckInBonus ? {points: bonusPoints, version} : null;
}
export function validCheckInBonusReceipt(raw: DocumentData, base: number) {
  const {basePoints, premiumBonusPoints, premiumBonusPolicyVersion, points} = raw;
  if (premiumBonusPoints === undefined) return basePoints === undefined && premiumBonusPolicyVersion === undefined && points === base;
  return basePoints === base && typeof premiumBonusPoints === 'number' && Number.isSafeInteger(premiumBonusPoints) && premiumBonusPoints > 0
    && typeof premiumBonusPolicyVersion === 'string' && premiumBonusPolicyVersion.trim().length > 0 && premiumBonusPolicyVersion.length <= 128
    && Number.isSafeInteger(points) && points === base + premiumBonusPoints;
}
