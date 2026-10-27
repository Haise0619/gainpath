import 'package:gainpath_domain/gamification.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show SessionScope, BookingException;
import 'firebase_booking_repository.dart';
import 'firebase_app_check_readiness.dart';
import '../local/reward_redemption_intents.dart';

/// No mock balance migration or financial cache fallback.
class FirebaseVerifiedRewardsRepository extends VerifiedRewardsRepository {
  FirebaseVerifiedRewardsRepository(
      {required SessionScope scope,
      required bool Function() isCurrent,
      String? Function()? currentUid,
      BookingCallable? call,
      RewardRedemptionIntents? intents,
      FirebaseAppCheckReadiness? readiness})
      : _transport = BookingTransport(
            scope: scope,
            isCurrent: isCurrent,
            currentUid: currentUid,
            call: call ?? _singaporeCall),
        _readiness = readiness ?? FirebaseAppCheckReadiness.instance,
        _intents = intents ?? RewardRedemptionIntents(scope);
  final BookingTransport _transport;
  final FirebaseAppCheckReadiness _readiness;
  final RewardRedemptionIntents _intents;

  // Reward rollout is independently scoped; the shared selector still holds
  // unrelated Stage B/C commands on their existing endpoints.
  static Future<Map<String, dynamic>> _singaporeCall(
      String name, Map<String, dynamic> input) async {
    final functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');
    if (const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) {
      functions.useFunctionsEmulator(
          const String.fromEnvironment('FIREBASE_EMULATOR_HOST',
              defaultValue: '10.0.2.2'),
          5001);
    }
    return (await functions
            .httpsCallable(name)
            .call<Map<String, dynamic>>(input))
        .data;
  }

  @override
  bool get current {
    try {
      _transport.check();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> _call(
      String action, Map<String, dynamic> fields) async {
    _transport.check();
    if (!await _readiness.ensureReady(check: _transport.check)) {
      throw const BookingException('app-check-unavailable');
    }
    return _transport.call('verifiedRewardsCommand', {
      'schemaVersion': 1,
      'organizationId': _transport.scope.organizationId,
      'action': action,
      ...fields
    });
  }

  T _parse<T>(T Function() parse) {
    try {
      return parse();
    } on FormatException {
      throw const BookingException('invalid-response');
    } on TypeError {
      throw const BookingException('invalid-response');
    }
  }

  @override
  Future<VerifiedRewardsSnapshot> overview() async {
    final result = await _call('overview', {});
    return _parse(() => VerifiedRewardsSnapshot.fromJson(result,
        organizationId: _transport.scope.organizationId,
        memberId: _transport.scope.userId));
  }

  @override
  Future<PointsHistorySnapshot> pointsHistory() async {
    final result = await _call('pointsHistoryAll', {});
    return _parse(() => PointsHistorySnapshot.fromJson(result,
        organizationId: _transport.scope.organizationId,
        memberId: _transport.scope.userId));
  }

  @override
  Future<EarnedPointsLeaderboard> leaderboard({String period = 'week'}) async {
    if (!['week', 'all_time'].contains(period)) {
      throw const BookingException('invalid-argument');
    }
    final result = await _call('leaderboard', {'period': period});
    return _parse(() => EarnedPointsLeaderboard.fromJson(result,
        organizationId: _transport.scope.organizationId,
        memberId: _transport.scope.userId,
        period: period));
  }

  static bool _reference(Object? value) =>
      value is String && RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(value);

  int _resolved(Map<String, dynamic> result) {
    final time = result['resolvedAtMillis'];
    if (result['schemaVersion'] != 1 ||
        time is! int ||
        time <= 0 ||
        time > 8640000000000000) {
      throw const FormatException('Invalid reward response.');
    }
    return time;
  }

  VerifiedRewardRedemption _voucher(Object? value, int resolved) {
    final row = VerifiedRewardRedemption.fromJson(
        Map<String, dynamic>.from(value as Map),
        organizationId: _transport.scope.organizationId,
        memberId: _transport.scope.userId);
    if (!_reference(row.redemptionId) ||
        row.issuedAtMillis > resolved ||
        (row.fulfilledAtMillis ?? 0) > resolved) {
      throw const FormatException('Invalid voucher reference.');
    }
    return row;
  }

  @override
  Future<VerifiedRewardRedemption> voucher(String redemptionId) async {
    _transport.check();
    if (!_reference(redemptionId)) {
      throw const BookingException('invalid-argument');
    }
    final result = await _call('voucher', {'redemptionId': redemptionId});
    return _parse(() {
      final row = _voucher(result['redemption'], _resolved(result));
      if (row.redemptionId != redemptionId) {
        throw const FormatException('Invalid voucher reference.');
      }
      return row;
    });
  }

  @override
  Future<VerifiedRewardHistoryPage> history({String? afterId}) async {
    _transport.check();
    if (afterId != null && !_reference(afterId)) {
      throw const BookingException('invalid-argument');
    }
    final result = await _call('history', {'afterId': afterId});
    return _parse(() {
      final resolved = _resolved(result), raw = result['redemptions'];
      final cursor = result['nextCursor'];
      if (result['organizationId'] != _transport.scope.organizationId ||
          result['memberId'] != _transport.scope.userId ||
          raw is! List ||
          raw.length > 25 ||
          (cursor != null && !_reference(cursor)) ||
          !result.containsKey('nextCursor')) {
        throw const FormatException('Invalid reward history.');
      }
      final rows = raw.map((v) => _voucher(v, resolved)).toList();
      var previous = afterId;
      for (final row in rows) {
        if (previous != null && row.redemptionId.compareTo(previous) <= 0) {
          throw const FormatException('Invalid reward history order.');
        }
        previous = row.redemptionId;
      }
      if (cursor != null &&
          (rows.isEmpty || cursor != rows.last.redemptionId)) {
        throw const FormatException('Invalid reward history cursor.');
      }
      return VerifiedRewardHistoryPage(rows,
          nextCursor: cursor as String?, resolvedAtMillis: resolved);
    });
  }

  @override
  Future<VerifiedRewardRedemption> redeem(
      {required String itemId,
      required String requestId,
      int? expectedPointCost,
      int? expectedItemRevision}) async {
    _transport.check();
    final stableRequestId = await _intents.reserve(itemId, requestId);
    _transport.check();
    final result = await _call('redeem', {
      'itemId': itemId,
      'requestId': stableRequestId,
      if (expectedPointCost != null) 'expectedPointCost': expectedPointCost,
      if (expectedItemRevision != null)
        'expectedItemRevision': expectedItemRevision,
    });
    final redemption = _parse(() {
      if (result['schemaVersion'] != 1) {
        throw const FormatException('Invalid response.');
      }
      final raw = Map<String, dynamic>.from(result['redemption'] as Map);
      if (raw['itemId'] != itemId || raw['requestId'] != stableRequestId) {
        throw const FormatException('Invalid request reference.');
      }
      return VerifiedRewardRedemption.fromJson(raw,
          organizationId: _transport.scope.organizationId,
          memberId: _transport.scope.userId);
    });
    _transport.check();
    await _intents.complete(itemId, stableRequestId);
    _transport.check();
    return redemption;
  }

  @override
  Future<void> award(String eventId) async {
    final result = await _call('award', {'eventId': eventId});
    _parse(() {
      final raw = Map<String, dynamic>.from(result['award'] as Map);
      if (result['schemaVersion'] != 1 ||
          raw['schemaVersion'] != 1 ||
          raw['organizationId'] != _transport.scope.organizationId ||
          raw['memberId'] != _transport.scope.userId ||
          raw['eventId'] != eventId ||
          raw['points'] is! int ||
          (raw['points'] as int) <= 0) {
        throw const FormatException('Invalid award.');
      }
    });
  }
}
