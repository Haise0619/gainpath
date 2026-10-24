/// Server-owned membership commerce, separate from the legacy mock ledger.
abstract class MembershipCommerceRepository {
  bool get sandbox;
  bool get current;
  Future<Map<String, dynamic>> load();
  Future<Map<String, dynamic>> quote(String planId, String promoCode);
  Future<Map<String, dynamic>> checkout(
      String planId, String promoCode, String requestId,
      {required bool renewal, String? quoteId});
  Future<Map<String, dynamic>> payment(String transactionId);
  Future<Map<String, dynamic>> refund(
      String transactionId, String reason, String notes);
}

String membershipMoney(Object? minor) =>
    'RM ${((minor as num? ?? 0) / 100).toStringAsFixed(2)}';

List<String> membershipInvoice(Map<String, dynamic> transaction) {
  if (transaction['paymentStatus'] != 'cleared' ||
      transaction['transactionId'] is! String ||
      transaction['amountMinor'] is! int ||
      transaction['currency'] != 'MYR') {
    throw StateError('A verified cleared membership payment is required.');
  }
  return [
    'GainPath — Sandbox payment invoice',
    'Test payment. No real money collected.',
    'Invoice: ${transaction['transactionId']}',
    'Organization: ${transaction['organizationId']}',
    'Member: ${transaction['memberId']}',
    'Type: ${transaction['kind']}',
    'Plan: ${transaction['planName']}',
    'Billplz bill: ${transaction['billId']}',
    'Paid: ${DateTime.fromMillisecondsSinceEpoch(transaction['clearedAtMillis'] as int).toUtc().toIso8601String()}',
    'Amount: ${membershipMoney(transaction['amountMinor'])}',
    'Invoice status: ${transaction['invoiceStatus']}',
    if (transaction['refundStatus'] != null)
      'Refund: ${transaction['refundStatus']} — approval is not money returned.',
  ];
}
