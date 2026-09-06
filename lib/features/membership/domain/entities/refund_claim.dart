class RefundClaim {
  final String id;
  final String memberName;
  final String transactionId;
  final String transactionType;
  final double amount;
  final String reason;
  final String notes;
  final DateTime submitted;
  final String status;
  const RefundClaim(this.id, this.memberName, this.transactionId, this.transactionType,
      this.amount, this.reason, this.notes, this.submitted, this.status);
}
