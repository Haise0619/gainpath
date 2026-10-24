import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/coaching.dart';
import 'firebase_booking_repository.dart';
import 'firebase_app_check_readiness.dart';

class FirebaseMemberBookingChangeRepository
    implements MemberBookingChangeRepository {
  FirebaseMemberBookingChangeRepository(
      {required this.scope,
      required bool Function() isCurrent,
      FirebaseAppCheckReadiness? readiness,
      String? Function()? currentUid,
      BookingCallable? call})
      : _transport = BookingTransport(
            scope: scope,
            isCurrent: isCurrent,
            currentUid: currentUid,
            call: call),
        _readiness = readiness ?? FirebaseAppCheckReadiness.instance;
  @override
  final SessionScope scope;
  final BookingTransport _transport;
  final FirebaseAppCheckReadiness _readiness;
  Future<void> _ready(PersistedBookingRecord booking) async {
    _transport.check();
    if (booking.memberId != scope.userId ||
        booking.organizationId != scope.organizationId) {
      throw const BookingException('permission-denied');
    }
    if (!await _readiness.ensureReady(check: _transport.check)) {
      throw const BookingException('app-check-unavailable');
    }
    _transport.check();
  }

  @override
  Future<BookingOptionsContext> loadReplacementOptions(
      PersistedBookingRecord booking,
      {String? localDate}) async {
    await _ready(booking);
    try {
      final data = await _transport.call('memberBookingChangeCommand', {
        'schemaVersion': 1,
        'organizationId': scope.organizationId,
        'bookingId': booking.bookingId,
        'action': 'options',
        if (localDate != null) 'localDate': localDate
      });
      return BookingOptionsContext.fromJson(data,
          expectedCoachId: booking.coachId,
          expectedDurationMinutes: booking.durationMinutes,
          expectedLocalDate: localDate);
    } on FormatException {
      throw const BookingException('invalid-response');
    }
  }

  @override
  Future<MemberBookingChangeResult> change(
      MemberBookingChangeRequest request) async {
    await _ready(request.booking);
    try {
      return MemberBookingChangeResult.fromJson(
          await _transport.call('memberBookingChangeCommand', request.toJson()),
          request);
    } on FormatException {
      throw const BookingException('invalid-response');
    }
  }
}
