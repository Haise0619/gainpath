import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show SessionScope, BookingException;
import 'firebase_booking_repository.dart';
import 'firebase_app_check_readiness.dart';
import '../local/membership_cache.dart';

class FirebaseMembershipRepository implements MembershipCommerceRepository {
  FirebaseMembershipRepository(
      {required SessionScope scope,
      required bool Function() isCurrent,
      String? Function()? currentUid,
      BookingCallable? call,
      MembershipCache? cache,
      FirebaseAppCheckReadiness? readiness})
      : _transport = BookingTransport(
            scope: scope,
            isCurrent: isCurrent,
            currentUid: currentUid,
            call: call),
        _readiness = readiness ?? FirebaseAppCheckReadiness.instance,
        _cache = cache ?? MembershipCache(scope);
  final BookingTransport _transport;
  final FirebaseAppCheckReadiness _readiness;
  final MembershipCache _cache;
  @override
  bool get sandbox => true;
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
      String name, Map<String, dynamic> data) async {
    _transport.check();
    if (!await _readiness.ensureReady(check: _transport.check)) {
      throw const BookingException('app-check-unavailable');
    }
    return _transport.call(name, {
      'schemaVersion': 1,
      'organizationId': _transport.scope.organizationId,
      ...data
    });
  }

  @override
  Future<Map<String, dynamic>> load() async {
    Map<String, dynamic> result;
    try {
      result = await _call('getMembershipOverviewCommand', {});
    } on BookingException catch (e) {
      // Authorization failures must never fall back to financial cache data.
      if (![
        'unavailable',
        'deadline-exceeded',
        'unknown',
        'app-check-unavailable'
      ].contains(e.code)) {
        rethrow;
      }
      final saved = await _cache.read();
      _transport.check();
      if (saved == null) rethrow;
      _validateOverview(saved);
      return saved;
    }
    _validateOverview(result);
    try {
      await _cache.save(result);
    } catch (_) {/* Display cache is optional. */}
    _transport.check();
    return result;
  }

  void _validateOverview(Map<String, dynamic> result) {
    if (result['organizationId'] != _transport.scope.organizationId ||
        result['memberId'] != _transport.scope.userId) {
      throw const BookingException('invalid-response');
    }
    if (result['entitlement'] != null) {
      try {
        MembershipEntitlement.fromJson(
            Map<String, dynamic>.from(result['entitlement'] as Map),
            expectedOrganizationId: _transport.scope.organizationId,
            expectedMemberId: _transport.scope.userId);
      } on FormatException {
        throw const BookingException('invalid-response');
      } on TypeError {
        throw const BookingException('invalid-response');
      }
    }
  }

  @override
  Future<Map<String, dynamic>> quote(String planId, String promoCode) => _call(
      'getMembershipQuoteCommand', {'planId': planId, 'promoCode': promoCode});
  @override
  Future<Map<String, dynamic>> checkout(
          String planId, String promoCode, String requestId,
          {required bool renewal, String? quoteId}) =>
      _call('createMembershipPaymentCommand', {
        'planId': planId,
        'promoCode': promoCode,
        'requestId': requestId,
        if (quoteId != null) 'quoteId': quoteId,
        'intent': renewal ? 'renewal' : 'purchase'
      });
  @override
  Future<Map<String, dynamic>> payment(String transactionId) =>
      _call('getMembershipPaymentCommand', {'transactionId': transactionId});
  @override
  Future<Map<String, dynamic>> refund(
          String transactionId, String reason, String notes) =>
      _call('requestMembershipRefundCommand',
          {'transactionId': transactionId, 'reason': reason, 'notes': notes});
}
