import '../../fakes/mock_data_session.dart';
import 'membership_seed.dart';
import 'package:gainpath_domain/membership.dart';

/// Session-scoped in-memory [MembershipRepository] backed by [MembershipSeed].
class InMemoryMembershipRepository implements MembershipRepository {
  InMemoryMembershipRepository({MockDataSession? session})
      : _seed = (session ?? MockDataSession()).membership;

  final MembershipSeed _seed;

  @override
  List<Transaction> get transactions => _seed.transactions;

  @override
  String get currentPlanId => _seed.currentPlanId;

  @override
  List<MembershipPlan> get membershipPlans => _seed.membershipPlans;

  @override
  List<RefundClaim> get refundClaims => _seed.refundClaims;

  @override
  set currentPlanId(String id) => _seed.currentPlanId = id;

  @override
  bool get autoRenew => _seed.autoRenew;

  @override
  set autoRenew(bool v) => _seed.autoRenew = v;

  @override
  void addTransaction(Transaction t) => _seed.transactions.insert(0, t);

  @override
  void addRefundClaim(RefundClaim c) => _seed.refundClaims.insert(0, c);
}
