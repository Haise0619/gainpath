enum RefundStatus {
  pendingReview('Pending'),
  approved('Approved'),
  rejected('Rejected');

  const RefundStatus(this.label);
  final String label;

  static RefundStatus fromLabel(String label) =>
      values.firstWhere((v) => v.label == label);
}
