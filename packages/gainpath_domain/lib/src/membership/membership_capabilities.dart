import 'membership_entitlement.dart';

/// Display/route hints only. Financial and paid actions reauthorize server-side.
class MembershipCapabilities {
  const MembershipCapabilities(this.entitlement);
  final MembershipEntitlement entitlement;
  bool get canUseDigitalFitness => true;
  bool get _paid => entitlement.isResolved && !entitlement.historicalOnly &&
      [MembershipTier.basic, MembershipTier.premium].contains(entitlement.effectiveTier);
  bool get canAccessGym => _paid;
  bool get canAccessMiniGames => _paid;
  bool get canBrowseCoaches => _paid;
  bool get canBookCoach => _paid;
  bool get canRedeemRegularPhysicalRewards => _paid;
  bool get canRedeemPremiumRewards => _paid && entitlement.effectiveTier == MembershipTier.premium;
  bool get isEligibleForPremiumCheckInBonus => canRedeemPremiumRewards;
  bool get isEligibleForCoachDiscount => canRedeemPremiumRewards;
}
