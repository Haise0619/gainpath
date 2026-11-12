import {DomainError} from '../../platform/errors';
import type {TransactionPort} from '../../platform/firestore/store';
import {resolveMembershipEntitlement} from './membership-entitlement';

/** Product policy only. Callers must still authorize identity, ownership and consent. */
export function membershipCapabilities(e: {status: string; effectiveTier: unknown; historicalOnly?: boolean}) {
  const paid=e.status==='resolved' && e.historicalOnly!==true && (e.effectiveTier==='basic'||e.effectiveTier==='premium');
  const premium=paid && e.effectiveTier==='premium';
  return {canUseDigitalFitness:true, canAccessGym:paid, canAccessMiniGames:paid,
    canBrowseCoaches:paid, canBookCoach:paid, canRedeemRegularPhysicalRewards:paid,
    canRedeemPremiumRewards:premium, isEligibleForPremiumCheckInBonus:premium,
    isEligibleForCoachDiscount:premium};
}
export type MembershipCapability=keyof ReturnType<typeof membershipCapabilities>;
export async function requireMembershipCapability(tx:TransactionPort,
  auth:{uid:string;token:Record<string,unknown>}|undefined, org:string,
  capability:MembershipCapability, now:number) {
  const entitlement=await resolveMembershipEntitlement(tx,auth,org,now);
  if(!membershipCapabilities(entitlement)[capability]) throw new DomainError('permission-denied',
    'An active Basic or Premium membership is required for this action.');
  return entitlement;
}
