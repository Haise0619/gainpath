enum MembershipTier { free, basic, premium }

enum PaidMembershipStatus { none, active, expired, unknown }

extension MembershipTierLabel on MembershipTier {
  String get label => switch (this) {
        MembershipTier.free => 'Free',
        MembershipTier.basic => 'Basic',
        MembershipTier.premium => 'Premium',
      };
}

/// A validated server projection for display. Financial commands reauthorize.
/// A cached projection is historical and never current admission/payment proof.
class MembershipEntitlement {
  const MembershipEntitlement._(
      {required this.isResolved,
      required this.historicalOnly,
      required this.reason,
      this.organizationId,
      this.memberId,
      this.resolvedAtMillis,
      this.effectiveTier,
      this.paidTier,
      this.paidPlanId,
      this.paidPlanName,
      this.paidExpiresAtMillis,
      this.paidStatus = PaidMembershipStatus.unknown,
      this.benefits = const []});
  final bool isResolved, historicalOnly;
  final String reason;
  final String? organizationId, memberId, paidPlanId, paidPlanName;
  final int? resolvedAtMillis, paidExpiresAtMillis;
  final MembershipTier? effectiveTier, paidTier;
  final PaidMembershipStatus paidStatus;
  final List<String> benefits;
  bool get canStartCheckout => isResolved && !historicalOnly;
  bool get hasPaidPlan => paidTier != null && paidPlanId != null;

  factory MembershipEntitlement.fromOverview(Map<String, dynamic> data) {
    final historical = data['cached'] == true;
    try {
      final raw = data['entitlement'];
      if (raw is! Map) throw const FormatException('Entitlement unavailable.');
      return MembershipEntitlement.fromJson(Map<String, dynamic>.from(raw),
          historicalOnly: historical);
    } on FormatException {
      return MembershipEntitlement._(
          isResolved: false,
          historicalOnly: historical,
          reason: 'entitlement_unavailable');
    }
  }

  factory MembershipEntitlement.fromJson(Map<String, dynamic> d,
      {bool historicalOnly = false,
      String? expectedOrganizationId,
      String? expectedMemberId}) {
    Never invalid() =>
        throw const FormatException('Invalid membership entitlement.');
    bool text(Object? v) =>
        v is String && v.trim().isNotEmpty && v.length <= 500;
    bool time(Object? v) => v is int && v > 0 && v <= 8640000000000000;
    MembershipTier? parseTier(Object? v) => switch (v) {
          'free' => MembershipTier.free,
          'basic' => MembershipTier.basic,
          'premium' => MembershipTier.premium,
          null => null,
          _ => invalid(),
        };
    if (d['schemaVersion'] != 1 ||
        d['policyVersion'] != 'gainpath-effective-membership-v1' ||
        !text(d['organizationId']) ||
        !text(d['memberId']) ||
        !time(d['resolvedAtMillis']) ||
        !text(d['reason']) ||
        (expectedOrganizationId != null &&
            d['organizationId'] != expectedOrganizationId) ||
        (expectedMemberId != null && d['memberId'] != expectedMemberId) ||
        !['resolved', 'unknown'].contains(d['status'])) {
      invalid();
    }
    final effective = parseTier(d['effectiveTier']),
        paidTier = parseTier(d['paidTier']);
    if (paidTier == MembershipTier.free) invalid();
    final paidStatus = switch (d['paidStatus']) {
      'none' => PaidMembershipStatus.none,
      'active' => PaidMembershipStatus.active,
      'expired' => PaidMembershipStatus.expired,
      'unknown' => PaidMembershipStatus.unknown,
      _ => invalid(),
    };
    for (final key in ['paidPlanId', 'paidPlanName']) {
      if (d[key] != null && !text(d[key])) {
        invalid();
      }
    }
    if (d['paidExpiresAtMillis'] != null && !time(d['paidExpiresAtMillis'])) {
      invalid();
    }
    final rawBenefits = d['benefits'];
    if (rawBenefits is! List ||
        !rawBenefits.every((b) => b is String && b.length <= 500)) {
      invalid();
    }
    final resolved = d['status'] == 'resolved';
    if (!resolved) {
      if (effective != null ||
          paidStatus != PaidMembershipStatus.unknown ||
          rawBenefits.isNotEmpty) {
        invalid();
      }
    } else {
      if (effective == null || paidStatus == PaidMembershipStatus.unknown) {
        invalid();
      }
      switch (paidStatus) {
        case PaidMembershipStatus.none:
          if (effective != MembershipTier.free ||
              paidTier != null ||
              d['paidPlanId'] != null ||
              d['paidPlanName'] != null ||
              d['paidExpiresAtMillis'] != null ||
              rawBenefits.isNotEmpty) {
            invalid();
          }
        case PaidMembershipStatus.active:
        case PaidMembershipStatus.expired:
          if (paidTier == null ||
              d['paidPlanId'] != paidTier.name ||
              !text(d['paidPlanName']) ||
              !time(d['paidExpiresAtMillis'])) {
            invalid();
          }
          if (paidStatus == PaidMembershipStatus.active) {
            if (effective != paidTier ||
                (d['paidExpiresAtMillis'] as int) <=
                    (d['resolvedAtMillis'] as int)) {
              invalid();
            }
          } else if (effective != MembershipTier.free ||
              (d['paidExpiresAtMillis'] as int) >
                  (d['resolvedAtMillis'] as int) ||
              rawBenefits.isNotEmpty) {
            invalid();
          }
        case PaidMembershipStatus.unknown:
          invalid();
      }
    }
    return MembershipEntitlement._(
        isResolved: resolved,
        historicalOnly: historicalOnly,
        reason: d['reason'] as String,
        organizationId: d['organizationId'] as String,
        memberId: d['memberId'] as String,
        resolvedAtMillis: d['resolvedAtMillis'] as int,
        effectiveTier: effective,
        paidTier: paidTier,
        paidPlanId: d['paidPlanId'] as String?,
        paidPlanName: d['paidPlanName'] as String?,
        paidExpiresAtMillis: d['paidExpiresAtMillis'] as int?,
        paidStatus: paidStatus,
        benefits: List.unmodifiable(rawBenefits.cast<String>()));
  }
}
