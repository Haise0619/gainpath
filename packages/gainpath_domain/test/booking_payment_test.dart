import 'package:test/test.dart';
import 'package:gainpath_domain/coaching.dart';

void main() {
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
