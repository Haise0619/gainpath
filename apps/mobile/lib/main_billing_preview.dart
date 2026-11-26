import 'package:flutter/material.dart';
import 'package:gainpath_data/membership.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'features/membership/application/membership_billing_repository.dart';
import 'features/membership/domain/membership_payment_preview.dart';
import 'features/membership/presentation/shared/membership_dashboard_screen.dart';
import 'infrastructure/local/mock_membership_commerce.dart';
import 'presentation/shared/payment_status_heading.dart';

void main() => runApp(MaterialApp(
      theme: AppTheme.build(),
      home: const _BillingPreview(),
    ));

class _BillingPreview extends StatelessWidget {
  const _BillingPreview();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('FYP Membership Billing Preview')),
        body: PageBody(children: [
          const Text('Local fixtures · no Firebase or Xendit requests'),
          for (final state in ['Active', 'Payment Due', 'Past Due'])
            ListTile(
              title: Text(state),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                    builder: (_) => MembershipDashboardScreen(
                        repository: _PreviewRepository(state))),
              ),
            ),
          ListTile(
            title: const Text('Shared checkout states'),
            subtitle: const Text('Membership and Coach Booking'),
            onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Checkout preview')),
                    body: PageBody(children: [
                      for (final stage in PaymentStage.values)
                        Panel(
                            child: PaymentStatusHeading(
                                stage: stage,
                                title: switch (stage) {
                                  PaymentStage.loading =>
                                    'Preparing your payment',
                                  PaymentStage.pending => 'Confirming payment',
                                  PaymentStage.success => 'Payment successful',
                                  PaymentStage.failure =>
                                    'Payment unsuccessful',
                                })),
                    ]),
                  ),
                )),
          ),
        ]),
      );
}

class _PreviewRepository
    implements
        MembershipCommerceRepository,
        MembershipBillingRepository,
        MembershipPaymentPreview {
  _PreviewRepository(this.scenario)
      : delegate = MockMembershipCommerce.forRepository(
            InMemoryMembershipRepository());
  final String scenario;
  final MockMembershipCommerce delegate;
  final DateTime opened = DateTime.now();
  bool _cancelled = false;
  Map<String, dynamic>? _payment;
  @override
  bool get sandbox => false;
  @override
  bool get current => true;

  @override
  Future<Map<String, dynamic>> load() async {
    final base = await delegate.load();
    final now = DateTime.now().millisecondsSinceEpoch;
    final paid = _payment?['paymentStatus'] == 'cleared';
    final expiry = paid
        ? _payment!['expiresAtMillis'] as int
        : opened
            .add(Duration(
                days: switch (scenario) {
              'Active' => 12,
              'Payment Due' => -1,
              _ => -8,
            }))
            .millisecondsSinceEpoch;
    final active = now < expiry;
    return {
      ...base,
      'entitlement': {
        ...Map<String, dynamic>.from(base['entitlement'] as Map),
        'effectiveTier': active ? 'basic' : 'free',
        'paidTier': 'basic',
        'paidPlanId': 'basic',
        'paidPlanName': 'Basic',
        'paidStatus': active ? 'active' : 'expired',
        'paidExpiresAtMillis': expiry,
        'reason': active ? 'active_paid_membership' : 'paid_membership_expired',
      },
      'billingSupported': true,
      'billing': {
        'status': _cancelled
            ? 'cancelled'
            : paid
                ? 'paid'
                : switch (scenario) {
                    'Active' => 'active',
                    'Payment Due' => 'payment_due',
                    _ => 'past_due',
                  },
        'nextRenewal': !_cancelled,
        if (!_cancelled) ...{
          'id': 'preview-bill',
          'planId': 'basic',
          'amountMinor': 8900,
          'dueAtMillis': expiry,
          'graceEndsAtMillis': expiry + const Duration(days: 7).inMilliseconds,
        },
      },
      'transactions': [if (_payment != null) _payment],
    };
  }

  @override
  Future<void> cancelRenewal() async {
    _cancelled = true;
  }

  @override
  Future<Map<String, dynamic>> payRenewalBill(
          String billingId, String planId, String requestId) async =>
      _payment ??= {
        'billingId': billingId,
        'transactionId': requestId,
        'planId': planId,
        'planName': 'Basic',
        'amountMinor': 8900,
        'kind': 'MembershipRenewal',
        'createdAtMillis': DateTime.now().millisecondsSinceEpoch,
        'paymentStatus': 'pending',
        'fulfilmentStatus': 'awaiting_payment',
      };

  @override
  Future<void> simulate(String transactionId) async {
    if (_payment?['transactionId'] != transactionId ||
        _payment?['paymentStatus'] == 'cleared') {
      return;
    }
    _payment!.addAll({
      'paymentStatus': 'cleared',
      'fulfilmentStatus': 'confirmed',
      'expiresAtMillis':
          DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch,
    });
  }

  @override
  Future<Map<String, dynamic>> payment(String transactionId) =>
      _payment?['transactionId'] == transactionId
          ? Future.value(_payment!)
          : delegate.payment(transactionId);

  @override
  Future<Map<String, dynamic>> quote(String planId, String promoCode,
          {MembershipUpgradeMode? upgradeMode}) =>
      delegate.quote(planId, promoCode, upgradeMode: upgradeMode);

  @override
  Future<Map<String, dynamic>> checkout(
          String planId, String promoCode, String requestId,
          {required bool renewal,
          String? quoteId,
          MembershipUpgradeMode? upgradeMode}) =>
      delegate.checkout(planId, promoCode, requestId,
          renewal: renewal, quoteId: quoteId, upgradeMode: upgradeMode);

  @override
  Future<Map<String, dynamic>> refund(
          String transactionId, String reason, String notes) =>
      delegate.refund(transactionId, reason, notes);
}
