import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show SessionScope, BookingException;
import 'firebase_booking_repository.dart';
import 'firebase_app_check_readiness.dart';

class FirebaseBookingPaymentRepository
    implements
        BookingPaymentRepository,
        PremiumVoucherBookingPaymentRepository,
        ReviewedBookingPaymentRepository,
        BookingPaymentMethodRepository {
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
      final quote = BookingPaymentQuote.fromJson(
          await _call('getBookingPaymentQuoteCommand', {
        'coachId': coachId,
        'branchId': branchId,
        'includeQuoteToken': true,
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

  @override
  Future<BookingPaymentQuote> loadVoucherQuote(
      {required String coachId,
      required String branchId,
      required int durationMinutes,
      required bool usePremiumVoucher}) async {
    try {
      final quote = BookingPaymentQuote.fromJson(
          await _call('getBookingPaymentQuoteCommand', {
        'coachId': coachId,
        'branchId': branchId,
        'includeQuoteToken': true,
        'durationMinutes': durationMinutes,
        'includePremiumVoucher': true,
        if (usePremiumVoucher) 'usePremiumVoucher': true,
      }));
      if (quote.durationMinutes != durationMinutes ||
          (usePremiumVoucher && !quote.voucherApplied)) {
        throw const FormatException();
      }
      return quote;
    } on FormatException {
      throw const BookingException('invalid-response');
    }
  }

  Future<BookingPaymentView> _payment(String name, String id,
      {bool usePremiumVoucher = false,
      String? quoteToken,
      String? gatewayCode}) async {
    try {
      return BookingPaymentView.fromJson(
          await _call(name, {
            'bookingId': id,
            if (gatewayCode != null) 'gatewayCode': gatewayCode,
            if (quoteToken != null) 'quoteToken': quoteToken,
            if (usePremiumVoucher) 'usePremiumVoucher': true
          }),
          bookingId: id);
    } on FormatException {
      throw const BookingException('invalid-response');
    }
  }

  @override
  Future<BookingPaymentView> createReviewed(String bookingId,
          {required String quoteToken, bool usePremiumVoucher = false}) =>
      _payment('createBookingPaymentCommand', bookingId,
          quoteToken: quoteToken, usePremiumVoucher: usePremiumVoucher);
  @override
  Future<BookingPaymentView> create(String bookingId) =>
      _payment('createBookingPaymentCommand', bookingId);
  @override
  Future<BookingPaymentView> createWithPremiumVoucher(String bookingId) =>
      _payment('createBookingPaymentCommand', bookingId,
          usePremiumVoucher: true);
  @override
  Future<BookingPaymentView> get(String bookingId) =>
      _payment('getBookingPaymentCommand', bookingId);
  @override
  Future<BookingPaymentView> createWithPaymentMethod(String bookingId,
          {required String gatewayCode,
          String? quoteToken,
          bool usePremiumVoucher = false}) =>
      _payment('createBookingPaymentCommand', bookingId,
          gatewayCode: gatewayCode,
          quoteToken: quoteToken,
          usePremiumVoucher: usePremiumVoucher);
  @override
  Future<BookingPaymentMethods> loadPaymentMethods(String bookingId) async {
    try {
      return BookingPaymentMethods.fromJson(
          await _call(
              'getBookingPaymentMethodsCommand', {'bookingId': bookingId}),
          bookingId: bookingId);
    } on FormatException {
      throw const BookingException('invalid-response');
    }
  }
}
