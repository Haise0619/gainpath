import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show SessionScope, BookingException;
import 'firebase_booking_repository.dart';
import 'firebase_app_check_readiness.dart';

class FirebaseConsultationNotesRepository
    implements ConsultationNotesRepository {
  FirebaseConsultationNotesRepository(
      {required SessionScope scope,
      required bool Function() isCurrent,
      BookingCallable? call,
      String? Function()? currentUid,
      FirebaseAppCheckReadiness? readiness})
      : _scope = scope,
        _readiness = readiness ?? FirebaseAppCheckReadiness.instance,
        _transport = BookingTransport(
            scope: scope,
            isCurrent: isCurrent,
            call: call,
            currentUid: currentUid);
  final SessionScope _scope;
  final FirebaseAppCheckReadiness _readiness;
  final BookingTransport _transport;
  Future<ConsultationNotesResult> _call(
      String id, Map<String, dynamic> fields) async {
    _transport.check();
    if (!await _readiness.ensureReady(check: _transport.check)) {
      throw const BookingException('app-check-unavailable');
    }
    final raw = await _transport.call('bookingConsultationNotesCommand', {
      'schemaVersion': 1,
      'organizationId': _scope.organizationId,
      'bookingId': id,
      ...fields,
    });
    try {
      return ConsultationNotesResult.fromJson(raw, expectedBookingId: id);
    } catch (_) {
      throw const BookingException('invalid-response');
    }
  }

  @override
  Future<ConsultationNotesResult> load(String bookingId) =>
      _call(bookingId, {});
  @override
  Future<ConsultationNotesResult> publish(
          String bookingId, String requestId, String text) =>
      _call(bookingId, {'requestId': requestId, 'text': text});
}
