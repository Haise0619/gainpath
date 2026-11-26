abstract interface class MembershipBillingRepository {
  Future<Map<String, dynamic>> payRenewalBill(
      String billingId, String planId, String requestId);
  Future<void> cancelRenewal();
}
