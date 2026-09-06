import 'package:gainpath/features/membership/data/in_memory/membership_seed.dart';
import 'package:gainpath/features/membership/domain/entities/membership_plan.dart';
import 'package:gainpath/features/membership/domain/entities/refund_claim.dart';
import 'package:gainpath/features/membership/domain/entities/transaction.dart';
import 'package:gainpath/features/membership/domain/repositories/membership_repository.dart';

/// Session-scoped in-memory [MembershipRepository] backed by [MembershipSeed].
class InMemoryMembershipRepository implements MembershipRepository {
  @override
  List<Transaction> get transactions => MembershipSeed.transactions;

  @override
  String get currentPlanId => MembershipSeed.currentPlanId;

  @override
  List<MembershipPlan> get membershipPlans => MembershipSeed.membershipPlans;

  @override
  List<RefundClaim> get refundClaims => MembershipSeed.refundClaims;

  @override
  set currentPlanId(String id) => MembershipSeed.currentPlanId = id;

  @override
  bool get autoRenew => MembershipSeed.autoRenew;

  @override
  set autoRenew(bool v) => MembershipSeed.autoRenew = v;

  @override
  void addTransaction(Transaction t) => MembershipSeed.transactions.insert(0, t);

  @override
  void addRefundClaim(RefundClaim c) => MembershipSeed.refundClaims.insert(0, c);
}
