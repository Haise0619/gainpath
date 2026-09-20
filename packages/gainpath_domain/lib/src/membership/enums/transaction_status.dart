enum TransactionStatus {
  pending('Pending'),
  cleared('Cleared'),
  failed('Failed'),
  disputed('Disputed'),
  refunded('Refunded');

  const TransactionStatus(this.label);
  final String label;

  static TransactionStatus fromLabel(String label) =>
      values.firstWhere((v) => v.label == label);
}
