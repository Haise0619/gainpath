import 'package:gainpath/features/membership/domain/entities/membership_plan.dart';
import 'package:gainpath/features/membership/domain/entities/refund_claim.dart';
import 'package:gainpath/features/membership/domain/entities/transaction.dart';

/// Data access contract for the membership feature. Implemented in-memory for the
/// prototype; a Firebase implementation will sit behind the same interface.
abstract class MembershipRepository {
  List<Transaction> get transactions;
  String get currentPlanId;
  List<MembershipPlan> get membershipPlans;
  List<RefundClaim> get refundClaims;
}
