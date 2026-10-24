import 'package:test/test.dart';
import 'package:gainpath_domain/membership.dart';

void main() {
  test('invoice rejects pending payment and renders cleared minor units', () {
    expect(() => membershipInvoice({'paymentStatus': 'pending'}),
        throwsStateError);
    final lines = membershipInvoice({
      'paymentStatus': 'cleared',
      'transactionId': 'm1',
      'amountMinor': 12345,
      'currency': 'MYR',
      'clearedAtMillis': 1800000000000,
      'organizationId': 'gainpath',
      'memberId': 'member',
      'kind': 'MembershipPurchase',
      'planName': 'Configured',
      'billId': 'bill',
      'invoiceStatus': 'disputed',
      'refundStatus': 'approved'
    });
    expect(lines.join('\n'), contains('RM 123.45'));
    expect(lines.join('\n'), contains('approval is not money returned'));
    expect(lines.join('\n'), contains('Sandbox'));
  });
}
