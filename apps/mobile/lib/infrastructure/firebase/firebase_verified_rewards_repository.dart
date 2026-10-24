import 'package:gainpath_domain/gamification.dart';
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
            call: call),
        _readiness = readiness ?? FirebaseAppCheckReadiness.instance,
        _intents = intents ?? RewardRedemptionIntents(scope);
  final BookingTransport _transport;
  final FirebaseAppCheckReadiness _readiness;
  final RewardRedemptionIntents _intents;
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
  Future<VerifiedRewardRedemption> redeem(
      {required String itemId, required String requestId}) async {
    _transport.check();
    final stableRequestId = await _intents.reserve(itemId, requestId);
    _transport.check();
    final result =
        await _call('redeem', {'itemId': itemId, 'requestId': stableRequestId});
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
