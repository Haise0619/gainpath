import 'points_history.dart';
import 'earned_points_leaderboard.dart';

/// Verified physical rewards are separate from local games and coach discounts.
abstract class VerifiedRewardsRepository {
  bool get connected => true;
  bool get current;
  Future<VerifiedRewardsSnapshot> overview();
  Future<VerifiedRewardRedemption> redeem(
      {required String itemId,
      required String requestId,
      int? expectedPointCost,
      int? expectedItemRevision});
  Future<void> award(String eventId);
  Future<PointsHistorySnapshot> pointsHistory() =>
      Future.error(const FormatException('Points history unavailable.'));
  Future<EarnedPointsLeaderboard> leaderboard({String period = 'week'}) =>
      Future.error(const FormatException('Leaderboard unavailable.'));
  Future<VerifiedRewardRedemption> voucher(String redemptionId) async {
    final rows = (await overview())
        .redemptions
        .where((r) => r.redemptionId == redemptionId);
    if (rows.length != 1) {
      throw const FormatException('Reward voucher unavailable.');
    }
    return rows.single;
  }

  Future<VerifiedRewardHistoryPage> history({String? afterId}) async {
    if (afterId != null) {
      throw const FormatException('Reward history unavailable.');
    }
    return VerifiedRewardHistoryPage((await overview()).redemptions);
  }
}

class RewardVoucherCode {
  static String encode(String organizationId, String redemptionId) =>
      'gainpath-reward:v1:$organizationId:$redemptionId';
  static String reference(String raw, {required String organizationId}) {
    final text = raw.trim(), pattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
    if (pattern.hasMatch(text)) return text;
    final parts = text.split(':');
    if (parts.length != 4 ||
        parts[0] != 'gainpath-reward' ||
        parts[1] != 'v1' ||
        parts[2] != organizationId ||
        !pattern.hasMatch(parts[3])) {
      throw const FormatException(
          'Scan a GainPath reward from this organization.');
    }
    return parts[3];
  }
}

String _detail(Map<String, dynamic> d, String key, int max,
    {bool required = false}) {
  final value = d[key];
  if (value is! String ||
      value.length > max ||
      value.contains('\u0000') ||
      (required && value.trim().isEmpty)) {
    throw const FormatException('Invalid reward details.');
  }
  return value;
}

String _image(Map<String, dynamic> d) {
  final value = _detail(d, 'imageUrl', 2048), uri = Uri.tryParse(value);
  if (value.isNotEmpty &&
      (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          RegExp(r'\s').hasMatch(value))) {
    throw const FormatException('Invalid reward image.');
  }
  return value;
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

String _identifier(Map<String, dynamic> d, String key) {
  final value = _string(d, key);
  if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(value)) {
    throw const FormatException('Invalid reward reference.');
  }
  return value;
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
      required this.premiumOnly,
      this.description = '',
      this.imageUrl = '',
      this.conditions = '',
      this.collectionInstructions = '',
      this.validityDays,
      this.revision});
  final String itemId,
      title,
      description,
      imageUrl,
      conditions,
      collectionInstructions;
  final int pointCost, stock;
  final int? validityDays, revision;
  final bool premiumOnly;
  factory VerifiedRewardItem.fromJson(Map<String, dynamic> d) {
    if (!_integer(d['pointCost'], 1) ||
        !_integer(d['stock']) ||
        d['premiumOnly'] is! bool) {
      throw const FormatException('Invalid reward item.');
    }
    final details = d['rewardDetailsVersion'] == 1;
    if (d.containsKey('rewardDetailsVersion') && !details) {
      throw const FormatException('Invalid reward detail version.');
    }
    if (details &&
        (!_integer(d['validityDays'], 1) ||
            d['validityDays'] > 365 ||
            !_integer(d['revision'], 1))) {
      throw const FormatException('Invalid reward validity.');
    }
    return VerifiedRewardItem(
        itemId: _identifier(d, 'itemId'),
        title: _string(d, 'title'),
        pointCost: d['pointCost'] as int,
        stock: d['stock'] as int,
        premiumOnly: d['premiumOnly'] as bool,
        description: details ? _detail(d, 'description', 2000) : '',
        imageUrl: details ? _image(d) : '',
        conditions:
            details ? _detail(d, 'conditions', 2000, required: true) : '',
        collectionInstructions: details
            ? _detail(d, 'collectionInstructions', 2000, required: true)
            : '',
        validityDays: details ? d['validityDays'] as int : null,
        revision: details ? d['revision'] as int : null);
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
      this.fulfilledAtMillis,
      this.organizationId = '',
      this.description = '',
      this.imageUrl = '',
      this.conditions = '',
      this.collectionInstructions = '',
      this.expiresAtMillis});
  final String redemptionId,
      itemId,
      title,
      status,
      organizationId,
      description,
      imageUrl,
      conditions,
      collectionInstructions;
  final int points, issuedAtMillis;
  final int? fulfilledAtMillis, expiresAtMillis;
  String get qrPayload => organizationId.isEmpty
      ? ''
      : RewardVoucherCode.encode(organizationId, redemptionId);
  String get statusLabel => status == 'fulfilled'
      ? 'Used'
      : status == 'expired'
          ? 'Expired'
          : 'Available';
  factory VerifiedRewardRedemption.fromJson(Map<String, dynamic> d,
      {required String organizationId, required String memberId}) {
    _owner(d, organizationId, memberId);
    if (!_integer(d['points'], 1) ||
        !_integer(d['issuedAtMillis'], 1) ||
        !['issued', 'fulfilled', 'expired'].contains(d['status']) ||
        (d['status'] == 'fulfilled' &&
            (!_integer(d['fulfilledAtMillis'], 1) ||
                d['fulfilledBy'] is! String))) {
      throw const FormatException('Invalid redemption.');
    }
    _string(d, 'policyVersion');
    _string(d, 'exchangeRateVersion');
    final details = d['rewardDetailsVersion'] == 1;
    if ((d.containsKey('rewardDetailsVersion') && !details) ||
        (!details &&
            (d.containsKey('expiresAtMillis') ||
                d.containsKey('expiredPointsPolicy')))) {
      throw const FormatException('Invalid voucher detail version.');
    }
    if ((details &&
            (!_integer(d['expiresAtMillis'], 1) ||
                d['expiresAtMillis'] > 8640000000000000 ||
                d['expiresAtMillis'] <= d['issuedAtMillis'] ||
                d['expiredPointsPolicy'] != 'remain_spent')) ||
        (d['status'] == 'expired' && !details)) {
      throw const FormatException('Invalid voucher expiry.');
    }
    return VerifiedRewardRedemption(
        redemptionId: _identifier(d, 'redemptionId'),
        itemId: _identifier(d, 'itemId'),
        title: _string(d, 'title'),
        points: d['points'] as int,
        status: d['status'] as String,
        issuedAtMillis: d['issuedAtMillis'] as int,
        fulfilledAtMillis: d['fulfilledAtMillis'] as int?,
        organizationId: organizationId,
        description: details ? _detail(d, 'description', 2000) : '',
        imageUrl: details ? _image(d) : '',
        conditions:
            details ? _detail(d, 'conditions', 2000, required: true) : '',
        collectionInstructions: details
            ? _detail(d, 'collectionInstructions', 2000, required: true)
            : '',
        expiresAtMillis: details ? d['expiresAtMillis'] as int : null);
  }
}

class VerifiedRewardHistoryPage {
  VerifiedRewardHistoryPage(List<VerifiedRewardRedemption> redemptions,
      {this.nextCursor, this.resolvedAtMillis = 0})
      : redemptions = List.unmodifiable(redemptions);
  final List<VerifiedRewardRedemption> redemptions;
  final String? nextCursor;
  final int resolvedAtMillis;
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
