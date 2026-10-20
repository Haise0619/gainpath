import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show SessionScope, BookingException;
import 'firebase_booking_repository.dart';
import 'firebase_app_check_readiness.dart';

class FirebaseClientPostureRepository implements ClientPostureRepository {
  FirebaseClientPostureRepository({
    required SessionScope scope,
    required bool Function() isCurrent,
    BookingCallable? call,
    String? Function()? currentUid,
    FirebaseAppCheckReadiness? readiness,
  })  : _scope = scope,
        _readiness = readiness ?? FirebaseAppCheckReadiness.instance,
        _transport = BookingTransport(
            scope: scope,
            isCurrent: isCurrent,
            call: call,
            currentUid: currentUid);

  final SessionScope _scope;
  final FirebaseAppCheckReadiness _readiness;
  final BookingTransport _transport;

  @override
  Future<ClientPostureResult> loadPostureHistory(String memberId) async {
    _transport.check();
    if (!await _readiness.ensureReady(check: _transport.check)) {
      throw const BookingException('app-check-unavailable');
    }
    final raw = await _transport.call('getClientPostureHistoryCommand', {
      'schemaVersion': 1,
      'organizationId': _scope.organizationId,
      'memberId': memberId,
    });
    try {
      return ClientPostureResult.fromJson(
        raw,
        expectedMemberId: memberId,
      );
    } catch (_) {
      throw const BookingException('unsupported-payload');
    }
  }
}
