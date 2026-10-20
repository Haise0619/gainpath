import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show SessionScope, BookingException;
import 'firebase_booking_repository.dart';
import 'firebase_app_check_readiness.dart';

class FirebaseBookingPaymentRepository implements BookingPaymentRepository {
  FirebaseBookingPaymentRepository(
      {required this.scope,
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
  @override
  final SessionScope scope;
  final BookingTransport _transport;
  final FirebaseAppCheckReadiness _readiness;
  Future<Map<String, dynamic>> _call(
      String name, Map<String, dynamic> input) async {
    _transport.check();
    if (!await _readiness.ensureReady(check: _transport.check)) {
      throw const BookingException('app-check-unavailable');
    }
    _transport.check();
    return _transport.call(name,
        {'schemaVersion': 1, 'organizationId': scope.organizationId, ...input});
  }

  @override
  Future<BookingPaymentQuote> loadQuote(
      {required String coachId,
      required String branchId,
      required int durationMinutes}) async {
    try {
      final quote = BookingPaymentQuote.fromJson(await _call(
          'getBookingPaymentQuoteCommand', {
        'coachId': coachId,
        'branchId': branchId,
        'durationMinutes': durationMinutes
      }));
      if (quote.durationMinutes != durationMinutes) {
        throw const FormatException();
      }
      return quote;
    } on FormatException {
      throw const BookingException('invalid-response');
    }
  }

  Future<BookingPaymentView> _payment(String name, String id) async {
    try {
      return BookingPaymentView.fromJson(await _call(name, {'bookingId': id}),
          bookingId: id);
    } on FormatException {
      throw const BookingException('invalid-response');
    }
  }

  @override
  Future<BookingPaymentView> create(String bookingId) =>
      _payment('createBookingPaymentCommand', bookingId);
  @override
  Future<BookingPaymentView> get(String bookingId) =>
      _payment('getBookingPaymentCommand', bookingId);
}
