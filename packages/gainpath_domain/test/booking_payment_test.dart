import 'package:test/test.dart';
import 'package:gainpath_domain/coaching.dart';

void main() {
  test(
      'voucher quote validates server discount math and retains unavailable state',
      () {
    final json = <String, dynamic>{
      'schemaVersion': 1,
      'amountMinor': 10800,
      'grossAmountMinor': 12000,
      'discountMinor': 1200,
      'currency': 'MYR',
      'durationMinutes': 60,
      'coachName': 'Coach',
      'branchName': 'Branch',
      'premiumVoucher': {
        'status': 'available',
        'voucherId': 'voucher',
        'discountMinor': 1200,
        'cycleStartAtMillis': 1,
        'cycleEndAtMillis': 2592000001
      }
    };
    final q = BookingPaymentQuote.fromJson(json);
    expect(q.voucherApplied, isTrue);
    expect(q.discountMinor, 1200);
    expect(q.voucher?.status, 'available');
    json['discountMinor'] = 1199;
    expect(() => BookingPaymentQuote.fromJson(json), throwsFormatException);
    json.remove('discountMinor');
    json.remove('grossAmountMinor');
    json['amountMinor'] = 12000;
    json['premiumVoucher'] = {'status': 'unavailable'};
    expect(BookingPaymentQuote.fromJson(json).voucher?.status, 'unavailable');
    expect(BookingPaymentQuote.fromJson(json).voucherApplied, isFalse);
  });
  test(
      'payment status exposes refunds without treating them as booking confirmation',
      () {
    final json = <String, dynamic>{
      'schemaVersion': 1,
      'bookingId': 'booking',
      'status': 'reconciliation_required',
      'amountMinor': 100,
      'currency': 'MYR',
      'durationMinutes': 60,
      'coachName': 'Coach',
      'branchName': 'Branch',
      'startLabel': '10:00',
      'endLabel': '11:00',
      'localDate': '2026-10-20',
      'holdExpiresAtMillis': 100,
      'paymentStatus': 'cleared',
      'refundStatus': 'completed'
    };
    final p = BookingPaymentView.fromJson(json, bookingId: 'booking');
    expect(p.paymentStatus, 'cleared');
    expect(p.refundStatus, 'completed');
    expect(p.confirmed, isFalse);
    json['refundStatus'] = 'invented';
    expect(() => BookingPaymentView.fromJson(json, bookingId: 'booking'),
        throwsFormatException);
  });
  test('sandbox checkout accepts exact HTTPS hosts only', () {
    expect(
        isBillplzSandboxCheckoutUrl(
            'https://www.billplz-sandbox.com/bills/abc'),
        isTrue);
    for (final url in [
      'http://billplz-sandbox.com/a',
      'https://billplz-sandbox.com.evil.test/a',
      'https://x@billplz-sandbox.com/a',
      'https://billplz-sandbox.com:444/a'
    ]) {
      expect(isBillplzSandboxCheckoutUrl(url), isFalse);
    }
  });
  test('quote preserves fixed amount and rejects missing fee', () {
    final json = <String, dynamic>{
      'schemaVersion': 1,
      'amountMinor': 12500,
      'currency': 'MYR',
      'coachName': 'Coach',
      'branchName': 'Studio',
      'durationMinutes': 30
    };
    expect(BookingPaymentQuote.fromJson(json).amountMinor, 12500);
    json.remove('amountMinor');
    expect(() => BookingPaymentQuote.fromJson(json), throwsFormatException);
  });
}
