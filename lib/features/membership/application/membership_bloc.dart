import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath/features/membership/domain/entities/refund_claim.dart';
import 'package:gainpath/features/membership/domain/entities/transaction.dart';
import 'package:gainpath/features/membership/domain/enums/refund_status.dart';
import 'package:gainpath/features/membership/domain/enums/transaction_status.dart';
import 'package:gainpath/features/membership/domain/policies/refund_policy.dart';
import 'package:gainpath/features/membership/domain/repositories/membership_repository.dart';

part 'membership_event.dart';
part 'membership_state.dart';

/// Membership and payment state (M4): current plan, auto-renewal, the
/// transaction ledger and refund claims. Payment itself happens on the
/// Billplz page; the Bloc records the outcome (SD-M4.1, M4.2, M4.3, M4.4).
class MembershipBloc extends Bloc<MembershipEvent, MembershipState> {
  MembershipBloc(this._repo, {this.memberName = 'Member', RefundPolicy refundPolicy = const RefundPolicy()})
      : _refundPolicy = refundPolicy,
        super(MembershipState.from(_repo)) {
    on<MembershipLoaded>((_, emit) => emit(_snapshot()));
    on<PlanPurchased>(_onPlanPurchased);
    on<MembershipRenewed>(_onRenewed);
    on<AutoRenewToggled>(_onAutoRenewToggled);
    on<RefundRequested>(_onRefundRequested);
  }

  final MembershipRepository _repo;
  final RefundPolicy _refundPolicy;
  final String memberName;

  static const refundWindowError = 'This charge is outside the refund window.';

  MembershipState _snapshot({String? error}) => MembershipState(
        currentPlanId: _repo.currentPlanId,
        autoRenew: _repo.autoRenew,
        transactions: List.unmodifiable(_repo.transactions),
        refundClaims: List.unmodifiable(_repo.refundClaims),
        error: error,
        revision: state.revision + 1,
      );

  String _txnId() => 'TXN-${DateTime.now().millisecondsSinceEpoch % 100000}';

  void _onPlanPurchased(PlanPurchased e, Emitter<MembershipState> emit) {
    _repo.currentPlanId = e.planId;
    _repo.addTransaction(Transaction(_txnId(), 'Membership purchase', e.amount, DateTime.now(), TransactionStatus.cleared));
    emit(_snapshot());
  }

  void _onRenewed(MembershipRenewed e, Emitter<MembershipState> emit) {
    _repo.addTransaction(Transaction(_txnId(), 'Membership renewal', e.amount, DateTime.now(), TransactionStatus.cleared));
    emit(_snapshot());
  }

  void _onAutoRenewToggled(AutoRenewToggled e, Emitter<MembershipState> emit) {
    _repo.autoRenew = e.enabled;
    emit(_snapshot());
  }

  void _onRefundRequested(RefundRequested e, Emitter<MembershipState> emit) {
    Transaction? txn;
    for (final t in _repo.transactions) {
      if (t.id == e.transactionId) txn = t;
    }
    if (txn == null || !_refundPolicy.isEligible(txn.date)) {
      emit(_snapshot(error: refundWindowError));
      return;
    }
    _repo.addRefundClaim(RefundClaim('RF-${_repo.refundClaims.length + 1}', memberName, txn.id, txn.type,
        txn.amount, e.reason, e.notes, DateTime.now(), RefundStatus.pendingReview));
    emit(_snapshot());
  }
}
