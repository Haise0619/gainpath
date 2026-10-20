import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show SessionScope, BookingException;
import 'firebase_booking_repository.dart';
import 'firebase_app_check_readiness.dart';

class FirebaseCoachBookingCancellationRepository
    implements CoachBookingCancellationRepository {
  FirebaseCoachBookingCancellationRepository({
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
  Future<CancelAssignedBookingResult> cancel({
    required String bookingId,
    required String requestId,
    required String reason,
  }) async {
    _transport.check();
    if (!await _readiness.ensureReady(check: _transport.check)) {
      throw const BookingException('app-check-unavailable');
    }
    final raw = await _transport.call('cancelAssignedBookingCommand', {
      'schemaVersion': 1,
      'organizationId': _scope.organizationId,
      'bookingId': bookingId,
      'requestId': requestId,
      'reason': reason,
    });
    try {
      return CancelAssignedBookingResult.fromJson(
        raw,
        expectedBookingId: bookingId,
        expectedRequestId: requestId,
      );
    } catch (_) {
      throw const BookingException('invalid-response');
    }
  }
}
