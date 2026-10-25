/// Optional preview action, deliberately absent from connected repositories.
abstract interface class MembershipPaymentPreview {
  Future<void> simulate(String transactionId);
}
