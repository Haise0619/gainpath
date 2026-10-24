import 'membership_entitlement.dart';

enum MembershipAccessFeature { exercise, advancedReport }

enum MembershipAccessOutcome { allowed, denied, unknown, legacy }

abstract interface class MembershipAccessRepository {
  bool get current;
  Future<MembershipAccessDecision> check(
      MembershipAccessFeature feature, String resourceId);
}

abstract interface class MembershipVerificationRepository {
  Future<MemberMembershipVerification> verifyMembership(String memberId);
}

/// Fresh response only; local caches and UI hints are never authorization.
class MembershipAccessDecision {
  const MembershipAccessDecision._(this.outcome, this.requiredTier,
      this.effectiveTier, this.resolvedAtMillis, this.reason);
  final MembershipAccessOutcome outcome;
  final MembershipTier? requiredTier, effectiveTier;
  final int resolvedAtMillis;
  final String reason;
  bool get permitsEntry =>
      outcome == MembershipAccessOutcome.allowed ||
      outcome == MembershipAccessOutcome.legacy;
  factory MembershipAccessDecision.fromJson(Map<String, dynamic> d,
      {required String organizationId,
      required String memberId,
      required MembershipAccessFeature feature,
      required String resourceId}) {
    Never invalid() =>
        throw const FormatException('Invalid membership access response.');
    MembershipTier? tier(Object? v) => v == null
        ? null
        : MembershipTier.values.where((x) => x.name == v).firstOrNull ??
            invalid();
    final outcome = MembershipAccessOutcome.values
        .where((x) => x.name == d['decision'])
        .firstOrNull;
    if (d['schemaVersion'] != 1 ||
        d['cached'] == true ||
        d['policyVersion'] != 'gainpath-membership-access-v1' ||
        d['organizationId'] != organizationId ||
        d['memberId'] != memberId ||
        d['feature'] != feature.name ||
        d['resourceId'] != resourceId ||
        d['resolvedAtMillis'] is! int ||
        (d['resolvedAtMillis'] as int) <= 0 ||
        (d['resolvedAtMillis'] as int) > 8640000000000000 ||
        outcome == null ||
        d['reason'] is! String ||
        (d['reason'] as String).isEmpty) {
      invalid();
    }
    final requiredTier = tier(d['requiredTier']),
        effectiveTier = tier(d['effectiveTier']);
    if (outcome == MembershipAccessOutcome.allowed &&
        (requiredTier == null ||
            effectiveTier == null ||
            requiredTier == MembershipTier.premium &&
                effectiveTier != MembershipTier.premium ||
            requiredTier == MembershipTier.basic &&
                effectiveTier == MembershipTier.free)) {
      invalid();
    }
    if (outcome == MembershipAccessOutcome.unknown &&
            (effectiveTier != null || requiredTier != null) ||
        outcome == MembershipAccessOutcome.legacy && requiredTier != null) {
      invalid();
    }
    return MembershipAccessDecision._(outcome, requiredTier, effectiveTier,
        d['resolvedAtMillis'] as int, d['reason'] as String);
  }
}

class MemberMembershipVerification {
  const MemberMembershipVerification._(this.status, this.gymAdmission,
      this.verifiedAtMillis, this.entitlement, this.displayName, this.email);
  final String status;
  final bool gymAdmission;
  final int verifiedAtMillis;
  final MembershipEntitlement? entitlement;
  final String? displayName, email;
  factory MemberMembershipVerification.fromJson(Map<String, dynamic> d,
      {required String organizationId, required String memberId}) {
    Never invalid() =>
        throw const FormatException('Invalid membership verification.');
    if (d['schemaVersion'] != 1 ||
        d['cached'] == true ||
        d['organizationId'] != organizationId ||
        d['memberId'] != memberId ||
        !['verified', 'denied', 'unknown'].contains(d['status']) ||
        d['gymAdmission'] is! bool ||
        d['verifiedAtMillis'] is! int ||
        (d['verifiedAtMillis'] as int) <= 0 ||
        (d['verifiedAtMillis'] as int) > 8640000000000000) {
      invalid();
    }
    final raw = d['entitlement'];
    final entitlement = raw == null
        ? null
        : raw is Map
            ? MembershipEntitlement.fromJson(Map<String, dynamic>.from(raw),
                expectedOrganizationId: organizationId,
                expectedMemberId: memberId)
            : invalid();
    if (d['status'] == 'denied' && entitlement != null ||
        d['status'] != 'denied' && entitlement == null ||
        d['status'] == 'verified' && entitlement?.isResolved != true ||
        d['status'] == 'unknown' && entitlement?.isResolved != false ||
        entitlement != null &&
            entitlement.resolvedAtMillis != d['verifiedAtMillis']) {
      invalid();
    }
    final admits = d['status'] == 'verified' &&
        [MembershipTier.basic, MembershipTier.premium]
            .contains(entitlement?.effectiveTier);
    if (d['gymAdmission'] != admits) invalid();
    final identity = d['identity'];
    if (identity != null && identity is! Map) invalid();
    String? field(String key) {
      final value = identity is Map ? identity[key] : null;
      if (value != null && (value is! String || value.length > 500)) invalid();
      return value as String?;
    }

    return MemberMembershipVerification._(
        d['status'] as String,
        admits,
        d['verifiedAtMillis'] as int,
        entitlement,
        field('displayName'),
        field('email'));
  }
}
