import 'booking_payment.dart';

class BookingPaymentMethod {
  const BookingPaymentMethod(
      {required this.code, required this.name, required this.category});
  final String code, name, category;
  factory BookingPaymentMethod.fromJson(Map<String, dynamic> json) {
    if (json['code'] is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(json['code'] as String) ||
        json['name'] is! String ||
        (json['name'] as String).trim().isEmpty ||
        (json['name'] as String).length > 80 ||
        !const ['fpx', 'billplz'].contains(json['category'])) {
      throw const FormatException('Invalid payment method');
    }
    return BookingPaymentMethod(
        code: json['code'] as String,
        name: json['name'] as String,
        category: json['category'] as String);
  }
}

class BookingPaymentMethods {
  const BookingPaymentMethods(
      {required this.methods,
      required this.serverNowMillis,
      this.existingPayment,
      this.quote,
      this.localDate,
      this.startLabel,
      this.endLabel,
      this.holdExpiresAtMillis});
  final List<BookingPaymentMethod> methods;
  final int serverNowMillis;
  final BookingPaymentView? existingPayment;
  final BookingPaymentQuote? quote;
  final String? localDate, startLabel, endLabel;
  final int? holdExpiresAtMillis;
  factory BookingPaymentMethods.fromJson(Map<String, dynamic> json,
      {required String bookingId}) {
    if (json['schemaVersion'] != 1 ||
        json['serverNowMillis'] is! int ||
        (json['serverNowMillis'] as int) < 1 ||
        json['methods'] is! List ||
        (json['methods'] as List).length > 100) {
      throw const FormatException('Invalid payment methods');
    }
    final methods = (json['methods'] as List).map((m) {
      if (m is! Map) throw const FormatException('Invalid payment method');
      return BookingPaymentMethod.fromJson(Map<String, dynamic>.from(m));
    }).toList(growable: false);
    if (methods.map((m) => m.code).toSet().length != methods.length) {
      throw const FormatException('Duplicate payment methods');
    }
    final old = json['existingPayment'];
    if (old != null) {
      if (methods.isNotEmpty || old is! Map) {
        throw const FormatException('Existing checkout is immutable');
      }
      return BookingPaymentMethods(
          methods: const [],
          serverNowMillis: json['serverNowMillis'] as int,
          existingPayment: BookingPaymentView.fromJson(
              Map<String, dynamic>.from(old),
              bookingId: bookingId));
    }
    if (json['session'] is! Map) {
      throw const FormatException('Missing checkout session');
    }
    final session = Map<String, dynamic>.from(json['session'] as Map);
    final quote = BookingPaymentQuote.fromJson(session);
    if (session['holdExpiresAtMillis'] is! int ||
        [
          'localDate',
          'startLabel',
          'endLabel'
        ].any((k) => session[k] is! String || (session[k] as String).isEmpty)) {
      throw const FormatException('Invalid checkout session');
    }
    return BookingPaymentMethods(
        methods: List.unmodifiable(methods),
        serverNowMillis: json['serverNowMillis'] as int,
        quote: quote,
        localDate: session['localDate'] as String,
        startLabel: session['startLabel'] as String,
        endLabel: session['endLabel'] as String,
        holdExpiresAtMillis: session['holdExpiresAtMillis'] as int);
  }
}

/// Optional capability: choose a server-enabled method before creating a bill.
abstract interface class BookingPaymentMethodRepository {
  Future<BookingPaymentMethods> loadPaymentMethods(String bookingId);
  Future<BookingPaymentView> createWithPaymentMethod(String bookingId,
      {required String gatewayCode,
      String? quoteToken,
      bool usePremiumVoucher = false});
}
