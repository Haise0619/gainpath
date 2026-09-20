part of 'membership_bloc.dart';

class MembershipState extends Equatable {
  const MembershipState({
    required this.currentPlanId,
    required this.autoRenew,
    this.transactions = const [],
    this.refundClaims = const [],
    this.error,
    this.revision = 0,
  });

  factory MembershipState.from(MembershipRepository repo) => MembershipState(
        currentPlanId: repo.currentPlanId,
        autoRenew: repo.autoRenew,
        transactions: List.unmodifiable(repo.transactions),
        refundClaims: List.unmodifiable(repo.refundClaims),
      );

  final String currentPlanId;
  final bool autoRenew;
  final List<Transaction> transactions;
  final List<RefundClaim> refundClaims;

  /// Set when the last event was rejected (for example a refund outside the window).
  final String? error;
  final int revision;

  @override
  List<Object?> get props => [currentPlanId, autoRenew, transactions, refundClaims, error, revision];
}
