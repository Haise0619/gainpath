import '../identity.dart';

bool isBillplzSandboxCheckoutUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      (!uri.hasPort || uri.port == 443) &&
      const {'billplz-sandbox.com', 'www.billplz-sandbox.com'}
          .contains(uri.host) &&
      uri.path.startsWith('/') &&
      uri.path.length > 1;
}

class PremiumCoachVoucherOffer {
  const PremiumCoachVoucherOffer({required this.status, this.discountMinor});
  final String status;
  final int? discountMinor;
  bool get available => status == 'available';
  factory PremiumCoachVoucherOffer.fromJson(Map<String, dynamic> json) {
    final status =
        json['status'] ?? (json['schemaVersion'] == 1 ? 'applied' : null);
    if (!const [
          'unavailable',
          'ineligible',
          'available',
          'reserved',
          'consumed',
          'applied'
        ].contains(status) ||
        (json['discountMinor'] != null &&
            (json['discountMinor'] is! int ||
                (json['discountMinor'] as int) < 1 ||
                (json['discountMinor'] as int) > 1500))) {
      throw const FormatException('Invalid voucher offer');
    }
    if (const ['available', 'reserved', 'consumed', 'applied']
            .contains(status) &&
        (json['voucherId'] is! String ||
            (json['voucherId'] as String).isEmpty ||
            json['discountMinor'] is! int ||
            json['cycleStartAtMillis'] is! int ||
            json['cycleEndAtMillis'] is! int ||
            (json['cycleStartAtMillis'] as int) < 1 ||
            (json['cycleEndAtMillis'] as int) -
                    (json['cycleStartAtMillis'] as int) !=
                30 * 86400000)) {
      throw const FormatException('Invalid voucher cycle');
    }
    return PremiumCoachVoucherOffer(
        status: status as String, discountMinor: json['discountMinor'] as int?);
  }
}

class BookingPaymentQuote {
  const BookingPaymentQuote(
      {required this.amountMinor,
      required this.coachName,
      required this.branchName,
      required this.durationMinutes,
      this.grossAmountMinor,
      this.discountMinor,
      this.voucher});
  final int amountMinor, durationMinutes;
  final String coachName, branchName;
  final int? grossAmountMinor, discountMinor;
  final PremiumCoachVoucherOffer? voucher;
  bool get voucherApplied => grossAmountMinor != null && discountMinor != null;
  String get formattedAmount => 'RM ${(amountMinor / 100).toStringAsFixed(2)}';
  factory BookingPaymentQuote.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1 ||
        json['currency'] != 'MYR' ||
        json['amountMinor'] is! int ||
        (json['amountMinor'] as int) <= 0 ||
        json['durationMinutes'] is! int ||
        !const [30, 60].contains(json['durationMinutes']) ||
        json['coachName'] is! String ||
        (json['coachName'] as String).trim().isEmpty ||
        json['branchName'] is! String ||
        (json['branchName'] as String).trim().isEmpty) {
      throw const FormatException('Invalid payment quote');
    }
    final rawVoucher = json['premiumVoucher'];
    if (rawVoucher != null && rawVoucher is! Map) {
      throw const FormatException('Invalid voucher');
    }
    final voucher = rawVoucher == null
        ? null
        : PremiumCoachVoucherOffer.fromJson(
            Map<String, dynamic>.from(rawVoucher as Map));
    final gross = json['grossAmountMinor'], discount = json['discountMinor'];
    if ((gross != null || discount != null) &&
        (gross is! int ||
            discount is! int ||
            discount < 1 ||
            discount > 1500 ||
            gross - discount != json['amountMinor'] ||
            voucher == null ||
            voucher.discountMinor != discount)) {
      throw const FormatException('Invalid discounted total');
    }
    return BookingPaymentQuote(
        amountMinor: json['amountMinor'] as int,
        coachName: json['coachName'] as String,
        branchName: json['branchName'] as String,
        durationMinutes: json['durationMinutes'] as int,
        grossAmountMinor: gross as int?,
        discountMinor: discount as int?,
        voucher: voucher);
  }
}

class BookingPaymentView {
  const BookingPaymentView(
      {required this.bookingId,
      required this.status,
      required this.quote,
      required this.startLabel,
      required this.endLabel,
      required this.localDate,
      required this.holdExpiresAtMillis,
      this.checkoutUrl,
      this.paymentStatus,
      this.refundStatus,
      this.resolutionReason});
  final String bookingId, status, startLabel, endLabel, localDate;
  final BookingPaymentQuote quote;
  final int holdExpiresAtMillis;
  final String? checkoutUrl, resolutionReason;
  final String? paymentStatus, refundStatus;
  bool get confirmed => status == 'confirmed';
  factory BookingPaymentView.fromJson(Map<String, dynamic> json,
      {required String bookingId}) {
    final quote = BookingPaymentQuote.fromJson(json);
    if (json['bookingId'] != bookingId ||
        !const [
          'creating',
          'awaiting_payment',
          'confirmed',
          'reconciliation_required'
        ].contains(json['status']) ||
        json['holdExpiresAtMillis'] is! int ||
        (json['paymentStatus'] != null &&
            !const ['pending', 'cleared'].contains(json['paymentStatus'])) ||
        (json['refundStatus'] != null &&
            !const [
              'approved',
              'rejected',
              'processing',
              'uncertain',
              'completed',
              'failed'
            ].contains(json['refundStatus'])) ||
        [
          'startLabel',
          'endLabel',
          'localDate'
        ].any((key) => json[key] is! String || (json[key] as String).isEmpty) ||
        (json['checkoutUrl'] != null &&
            (json['checkoutUrl'] is! String ||
                !isBillplzSandboxCheckoutUrl(json['checkoutUrl'] as String))) ||
        (json['resolutionReason'] != null &&
            json['resolutionReason'] is! String)) {
      throw const FormatException('Invalid payment status');
    }
    return BookingPaymentView(
        bookingId: bookingId,
        status: json['status'] as String,
        quote: quote,
        startLabel: json['startLabel'] as String,
        endLabel: json['endLabel'] as String,
        localDate: json['localDate'] as String,
        holdExpiresAtMillis: json['holdExpiresAtMillis'] as int,
        checkoutUrl: json['checkoutUrl'] as String?,
        paymentStatus: json['paymentStatus'] as String?,
        refundStatus: json['refundStatus'] as String?,
        resolutionReason: json['resolutionReason'] as String?);
  }
}

abstract interface class BookingPaymentRepository {
  SessionScope get scope;
  Future<BookingPaymentQuote> loadQuote(
      {required String coachId,
      required String branchId,
      required int durationMinutes});
  Future<BookingPaymentView> create(String bookingId);
  Future<BookingPaymentView> get(String bookingId);
}

/// Additive capability; repositories without trusted voucher support retain their existing contract.
abstract interface class PremiumVoucherBookingPaymentRepository {
  Future<BookingPaymentQuote> loadVoucherQuote(
      {required String coachId,
      required String branchId,
      required int durationMinutes,
      required bool usePremiumVoucher});
  Future<BookingPaymentView> createWithPremiumVoucher(String bookingId);
}
