import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../../app/di/membership_factory.dart';
import '../shared/membership_data_view.dart';
import 'purchase_plan_screen.dart';
import 'refund_request_screen.dart';

class BillingHistoryScreen extends StatelessWidget {
  const BillingHistoryScreen(
      {super.key, this.connected = false, this.repository});
  final bool connected;
  final MembershipCommerceRepository? repository;
  @override
  Widget build(BuildContext context) => repository != null
      ? MembershipRepositoryGuard(
          repository: repository!, child: _body(repository!))
      : MembershipFeatureHost(connected: connected, builder: _body);
  Widget _body(MembershipCommerceRepository repo) => MembershipDataView(
      repository: repo,
      title: 'Billing history',
      builder: (context, data, refresh) {
        final payments = membershipRows(data['transactions']);
        Future<void> open(Widget page) async {
          await Navigator.push(
              context, MaterialPageRoute<void>(builder: (_) => page));
          if (context.mounted) refresh();
        }

        return [
          const Text(
              'Membership payments only. Coaching payments remain in your bookings.'),
          const SizedBox(height: 16),
          if (payments.isEmpty)
            const Panel(child: Text('No membership transactions yet.')),
          ...payments.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Panel(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        '${p['planName']} · ${membershipMoney(p['amountMinor'])}',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                        '${p['kind']} · ${membershipDate(p['createdAtMillis'])}'),
                    Text(membershipPaymentLabel(p)),
                    Text('${p['transactionId']}'),
                    if (p['reviewReason'] != null)
                      Text('Admin: ${p['reviewReason']}'),
                    if (p['refundStatus'] != null)
                      const Text(
                          'Refund approval records a decision. Money is returned only after confirmed provider completion.'),
                    Wrap(spacing: 8, children: [
                      TextButton(
                          onPressed: () => open(MembershipPaymentScreen(
                              repository: repo, initial: p)),
                          child: const Text('Payment details / recover')),
                      if (p['paymentStatus'] == 'cleared' && repo.sandbox)
                        TextButton(
                            onPressed: () async {
                              if (!repo.current) return;
                              try {
                                final saved = await const MethodChannel(
                                        'gainpath/coach_statement')
                                    .invokeMethod<bool>(
                                        'saveInvoice', membershipInvoice(p));
                                if (context.mounted && repo.current) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: Text(saved == true
                                        ? 'Invoice saved to your chosen location.'
                                        : 'Invoice save cancelled.'),
                                    action: saved != true
                                        ? null
                                        : SnackBarAction(
                                            label: 'Open PDF',
                                            onPressed: () async {
                                              if (!repo.current) return;
                                              try {
                                                await const MethodChannel(
                                                        'gainpath/coach_statement')
                                                    .invokeMethod<bool>(
                                                        'openInvoice');
                                              } catch (_) {
                                                if (context.mounted) {
                                                  showToast(context,
                                                      'Open the saved invoice from your Files app.');
                                                }
                                              }
                                            }),
                                  ));
                                }
                              } catch (_) {
                                if (context.mounted) {
                                  showToast(context,
                                      'Invoice could not be saved. Retry on Android.');
                                }
                              }
                            },
                            child: const Text('Download PDF invoice')),
                      if (p['paymentStatus'] == 'cleared')
                        TextButton(
                            onPressed: () => open(RefundRequestScreen(
                                repository: repo,
                                preselectedTransactionId:
                                    p['transactionId'] as String)),
                            child: const Text('Request / track refund')),
                    ]),
                  ])))),
        ];
      });
}
