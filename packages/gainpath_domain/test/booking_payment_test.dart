import 'package:test/test.dart';
import 'package:gainpath_domain/coaching.dart';

void main() {
  test('payment status exposes refunds without treating them as booking confirmation', () {
    final json = <String, dynamic>{'schemaVersion':1,'bookingId':'booking','status':'reconciliation_required','amountMinor':100,'currency':'MYR','durationMinutes':60,'coachName':'Coach','branchName':'Branch','startLabel':'10:00','endLabel':'11:00','localDate':'2026-10-20','holdExpiresAtMillis':100,'paymentStatus':'cleared','refundStatus':'completed'};
    final p=BookingPaymentView.fromJson(json,bookingId:'booking');
    expect(p.paymentStatus,'cleared'); expect(p.refundStatus,'completed');expect(p.confirmed,isFalse);
    json['refundStatus']='invented';expect(()=>BookingPaymentView.fromJson(json,bookingId:'booking'),throwsFormatException);
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
