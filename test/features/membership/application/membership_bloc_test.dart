import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath/features/membership/application/membership_bloc.dart';
import 'package:gainpath/features/membership/domain/entities/membership_plan.dart';
import 'package:gainpath/features/membership/domain/entities/refund_claim.dart';
import 'package:gainpath/features/membership/domain/entities/transaction.dart';
import 'package:gainpath/features/membership/domain/enums/refund_status.dart';
import 'package:gainpath/features/membership/domain/enums/transaction_status.dart';
import 'package:gainpath/features/membership/domain/repositories/membership_repository.dart';

class _FakeMembershipRepository implements MembershipRepository {
  @override
  String currentPlanId = 'basic';
  @override
  bool autoRenew = true;
  @override
  final List<Transaction> transactions = [
    Transaction('T-recent', 'Membership renewal', 89, DateTime.now().subtract(const Duration(days: 2)), TransactionStatus.cleared),
    Transaction('T-old', 'Membership renewal', 89, DateTime.now().subtract(const Duration(days: 30)), TransactionStatus.cleared),
  ];
  @override
  final List<RefundClaim> refundClaims = [];
  @override
  List<MembershipPlan> get membershipPlans => const [];
  @override
  void addTransaction(Transaction t) => transactions.insert(0, t);
  @override
  void addRefundClaim(RefundClaim c) => refundClaims.insert(0, c);
}

void main() {
  late _FakeMembershipRepository repo;
  setUp(() => repo = _FakeMembershipRepository());

  blocTest<MembershipBloc, MembershipState>(
    'purchasing switches the plan and records a cleared transaction',
    build: () => MembershipBloc(repo),
    act: (b) => b.add(const PlanPurchased('premium', 129)),
    verify: (b) {
      expect(b.state.currentPlanId, 'premium');
      expect(b.state.transactions.first.amount, 129);
      expect(b.state.transactions.first.status, TransactionStatus.cleared);
      expect(repo.transactions.length, 3);
    },
  );

  blocTest<MembershipBloc, MembershipState>(
    'renewing appends a renewal transaction without changing the plan',
    build: () => MembershipBloc(repo),
    act: (b) => b.add(const MembershipRenewed(89)),
    verify: (b) {
      expect(b.state.currentPlanId, 'basic');
      expect(b.state.transactions.first.type, 'Membership renewal');
    },
  );

  blocTest<MembershipBloc, MembershipState>(
    'auto-renew toggle persists to the repository',
    build: () => MembershipBloc(repo),
    act: (b) => b.add(const AutoRenewToggled(false)),
    verify: (b) {
      expect(b.state.autoRenew, isFalse);
      expect(repo.autoRenew, isFalse);
    },
  );

  blocTest<MembershipBloc, MembershipState>(
    'a refund inside the window files a pending claim',
    build: () => MembershipBloc(repo, memberName: 'ZhengYang'),
    act: (b) => b.add(const RefundRequested(transactionId: 'T-recent', reason: 'Charged twice')),
    verify: (b) {
      expect(b.state.error, isNull);
      expect(b.state.refundClaims.single.status, RefundStatus.pendingReview);
      expect(b.state.refundClaims.single.memberName, 'ZhengYang');
    },
  );

  blocTest<MembershipBloc, MembershipState>(
    'a refund outside the window is rejected with an error',
    build: () => MembershipBloc(repo),
    act: (b) => b.add(const RefundRequested(transactionId: 'T-old', reason: 'Changed my mind')),
    verify: (b) {
      expect(b.state.error, MembershipBloc.refundWindowError);
      expect(b.state.refundClaims, isEmpty);
    },
  );
}
