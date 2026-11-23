enum MembershipUpgradeMode {
  immediate('immediate'),
  nextTerm('next_term');

  const MembershipUpgradeMode(this.wireValue);
  final String wireValue;
}

/// Server-owned membership commerce, separate from the legacy mock ledger.
abstract class MembershipCommerceRepository {
  bool get sandbox;
  bool get current;
  Future<Map<String, dynamic>> load();
  Future<Map<String, dynamic>> quote(String planId, String promoCode,
      {MembershipUpgradeMode? upgradeMode});
  Future<Map<String, dynamic>> checkout(
      String planId, String promoCode, String requestId,
      {required bool renewal,
      String? quoteId,
      MembershipUpgradeMode? upgradeMode});
  Future<Map<String, dynamic>> payment(String transactionId);
  Future<Map<String, dynamic>> refund(
      String transactionId, String reason, String notes);
}

String membershipMoney(Object? minor) =>
    'RM ${((minor as num? ?? 0) / 100).toStringAsFixed(2)}';

String membershipOrderLabel(Map<String, dynamic> transaction) =>
    switch (transaction['upgradeMode']) {
      'immediate' => 'Immediate upgrade and extension',
      'next_term' => 'Premium after Basic expiry',
      _ when transaction['upgradeExpiresAtMillis'] != null => 'Prorated upgrade',
      _ => transaction['kind'] == 'MembershipRenewal' ? 'Renewal' : 'Purchase',
    };

List<String> membershipInvoice(Map<String, dynamic> transaction) {
  if (transaction['paymentStatus'] != 'cleared' ||
      transaction['transactionId'] is! String ||
      transaction['amountMinor'] is! int ||
      transaction['currency'] != 'MYR') {
    throw StateError('A verified cleared membership payment is required.');
  }
  final order = membershipOrderLabel(transaction);
  return [
    'GainPath membership receipt',
    'Payment environment: Billplz Sandbox. No real funds were transferred.',
    'Invoice: ${transaction['transactionId']}',
    'Organization: ${transaction['organizationId']}',
    'Member: ${transaction['memberId']}',
    'Order: ${order == 'Purchase' || order == 'Renewal' ? 'Membership ${order.toLowerCase()}' : order}',
    if (transaction['upgradeChargeMinor'] != null &&
        transaction['upgradeMode'] == 'immediate')
      'Remaining Basic time upgrade: ${membershipMoney(transaction['upgradeChargeMinor'])}',
    if (transaction['premiumTermAmountMinor'] != null)
      '30-day Premium term: ${membershipMoney(transaction['premiumTermAmountMinor'])}',
    'Plan: ${transaction['planName']}',
    'Billplz bill: ${transaction['billId']}',
    'Paid: ${DateTime.fromMillisecondsSinceEpoch(transaction['clearedAtMillis'] as int).toUtc().toIso8601String()}',
    'Amount: ${membershipMoney(transaction['amountMinor'])}',
    'Invoice status: ${transaction['invoiceStatus']}',
    if (transaction['refundStatus'] != null)
      'Refund: ${transaction['refundStatus']} — approval is not money returned.',
  ];
}
