/// Verified physical rewards are separate from local games and coach discounts.
abstract class VerifiedRewardsRepository {
  bool get connected => true;
  bool get current;
  Future<VerifiedRewardsSnapshot> overview();
  Future<VerifiedRewardRedemption> redeem(
      {required String itemId, required String requestId});
  Future<void> award(String eventId);
}

bool _integer(Object? v, [int min = 0]) =>
    v is int && v >= min && v <= 9007199254740991;
String _string(Map<String, dynamic> d, String key) {
  final v = d[key];
  if (v is! String || v.trim().isEmpty) {
    throw const FormatException('Invalid reward response.');
  }
  return v;
}

void _owner(Map<String, dynamic> d, String org, String uid) {
  if (d['schemaVersion'] != 1 ||
      d['organizationId'] != org ||
      d['memberId'] != uid) {
    throw const FormatException('Invalid reward owner.');
  }
}

class VerifiedRewardItem {
  const VerifiedRewardItem(
      {required this.itemId,
      required this.title,
      required this.pointCost,
      required this.stock,
      required this.premiumOnly});
  final String itemId, title;
  final int pointCost, stock;
  final bool premiumOnly;
  factory VerifiedRewardItem.fromJson(Map<String, dynamic> d) {
    if (!_integer(d['pointCost'], 1) ||
        !_integer(d['stock']) ||
        d['premiumOnly'] is! bool) {
      throw const FormatException('Invalid reward item.');
    }
    return VerifiedRewardItem(
        itemId: _string(d, 'itemId'),
        title: _string(d, 'title'),
        pointCost: d['pointCost'] as int,
        stock: d['stock'] as int,
        premiumOnly: d['premiumOnly'] as bool);
  }
}

class VerifiedRewardRedemption {
  const VerifiedRewardRedemption(
      {required this.redemptionId,
      required this.itemId,
      required this.title,
      required this.points,
      required this.status,
      required this.issuedAtMillis,
      this.fulfilledAtMillis});
  final String redemptionId, itemId, title, status;
  final int points, issuedAtMillis;
  final int? fulfilledAtMillis;
  factory VerifiedRewardRedemption.fromJson(Map<String, dynamic> d,
      {required String organizationId, required String memberId}) {
    _owner(d, organizationId, memberId);
    if (!_integer(d['points'], 1) ||
        !_integer(d['issuedAtMillis'], 1) ||
        !['issued', 'fulfilled'].contains(d['status']) ||
        (d['status'] == 'fulfilled' &&
            (!_integer(d['fulfilledAtMillis'], 1) ||
                d['fulfilledBy'] is! String))) {
      throw const FormatException('Invalid redemption.');
    }
    _string(d, 'policyVersion');
    _string(d, 'exchangeRateVersion');
    return VerifiedRewardRedemption(
        redemptionId: _string(d, 'redemptionId'),
        itemId: _string(d, 'itemId'),
        title: _string(d, 'title'),
        points: d['points'] as int,
        status: d['status'] as String,
        issuedAtMillis: d['issuedAtMillis'] as int,
        fulfilledAtMillis: d['fulfilledAtMillis'] as int?);
  }
}

class VerifiedRewardsSnapshot {
  const VerifiedRewardsSnapshot(
      {required this.available,
      required this.balance,
      required this.effectiveTier,
      required this.canRedeem,
      required this.items,
      required this.redemptions});
  final bool available, canRedeem;
  final int? balance;
  final String? effectiveTier;
  final List<VerifiedRewardItem> items;
  final List<VerifiedRewardRedemption> redemptions;
  factory VerifiedRewardsSnapshot.fromJson(Map<String, dynamic> d,
      {required String organizationId, required String memberId}) {
    _owner(d, organizationId, memberId);
    if (d['available'] is! bool ||
        d['canRedeem'] is! bool ||
        (d['balance'] != null && !_integer(d['balance'])) ||
        ![null, 'free', 'basic', 'premium'].contains(d['effectiveTier']) ||
        d['items'] is! List ||
        d['redemptions'] is! List ||
        !_integer(d['resolvedAtMillis'], 1) ||
        (d['available'] == true && d['policyVersion'] is! String) ||
        (d['available'] == false &&
            (d['canRedeem'] == true || (d['items'] as List).isNotEmpty)) ||
        (d['canRedeem'] == true &&
            !['basic', 'premium'].contains(d['effectiveTier']))) {
      throw const FormatException('Invalid reward overview.');
    }
    return VerifiedRewardsSnapshot(
        available: d['available'] as bool,
        canRedeem: d['canRedeem'] as bool,
        balance: d['balance'] as int?,
        effectiveTier: d['effectiveTier'] as String?,
        items: List.unmodifiable((d['items'] as List).map((v) =>
            VerifiedRewardItem.fromJson(Map<String, dynamic>.from(v as Map)))),
        redemptions: List.unmodifiable((d['redemptions'] as List).map((v) =>
            VerifiedRewardRedemption.fromJson(
                Map<String, dynamic>.from(v as Map),
                organizationId: organizationId,
                memberId: memberId))));
  }
}
