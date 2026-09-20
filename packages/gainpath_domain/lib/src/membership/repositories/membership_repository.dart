import '../entities/membership_plan.dart';
import '../entities/refund_claim.dart';
import '../entities/transaction.dart';

/// Data access contract for the membership feature. Implemented in-memory for the
/// prototype; a Firebase implementation will sit behind the same interface.
abstract class MembershipRepository {
  List<Transaction> get transactions;
  String get currentPlanId;
  List<MembershipPlan> get membershipPlans;
  List<RefundClaim> get refundClaims;

  set currentPlanId(String id);
  bool get autoRenew;
  set autoRenew(bool v);
  void addTransaction(Transaction t);
  void addRefundClaim(RefundClaim c);
}
