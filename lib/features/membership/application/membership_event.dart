part of 'membership_bloc.dart';

sealed class MembershipEvent extends Equatable {
  const MembershipEvent();
  @override
  List<Object?> get props => [];
}

class MembershipLoaded extends MembershipEvent {
  const MembershipLoaded();
}

/// Checkout succeeded for [planId] at [amount] (SD-M4.1).
class PlanPurchased extends MembershipEvent {
  const PlanPurchased(this.planId, this.amount);
  final String planId;
  final double amount;
  @override
  List<Object?> get props => [planId, amount];
}

/// Renewal checkout succeeded (SD-M4.3).
class MembershipRenewed extends MembershipEvent {
  const MembershipRenewed(this.amount);
  final double amount;
  @override
  List<Object?> get props => [amount];
}

/// Auto-renewal switch changed (SD-M4.2).
class AutoRenewToggled extends MembershipEvent {
  const AutoRenewToggled(this.enabled);
  final bool enabled;
  @override
  List<Object?> get props => [enabled];
}

/// Member filed a refund claim (SD-M4.4). Rejected outside the policy window.
class RefundRequested extends MembershipEvent {
  const RefundRequested({required this.transactionId, required this.reason, this.notes = ''});
  final String transactionId;
  final String reason;
  final String notes;
  @override
  List<Object?> get props => [transactionId, reason, notes];
}
