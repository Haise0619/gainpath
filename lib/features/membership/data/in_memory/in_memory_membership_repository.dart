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
}
