import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show SessionScope, BookingException;
import 'firebase_booking_repository.dart';
import 'firebase_app_check_readiness.dart';

class FirebaseMembershipAccessRepository implements MembershipAccessRepository {
  FirebaseMembershipAccessRepository(
      {required SessionScope scope,
      required bool Function() isCurrent,
      String? Function()? currentUid,
      BookingCallable? call,
      FirebaseAppCheckReadiness? readiness})
      : _transport = BookingTransport(
            scope: scope,
            isCurrent: isCurrent,
            currentUid: currentUid,
            call: call),
        _readiness = readiness ?? FirebaseAppCheckReadiness.instance;
  final BookingTransport _transport;
  final FirebaseAppCheckReadiness _readiness;
  @override
  bool get current {
    try {
      _transport.check();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<MembershipAccessDecision> check(
      MembershipAccessFeature feature, String resourceId) async {
    _transport.check();
    if (!await _readiness.ensureReady(check: _transport.check)) {
      throw const BookingException('app-check-unavailable');
    }
    final data = await _transport.call('getMembershipAccessCommand', {
      'schemaVersion': 1,
      'organizationId': _transport.scope.organizationId,
      'feature': feature.name,
      'resourceId': resourceId
    });
    _transport.check();
    try {
      return MembershipAccessDecision.fromJson(data,
          organizationId: _transport.scope.organizationId,
          memberId: _transport.scope.userId,
          feature: feature,
          resourceId: resourceId);
    } on FormatException {
      throw const BookingException('invalid-response');
    } on TypeError {
      throw const BookingException('invalid-response');
    }
  }
}
