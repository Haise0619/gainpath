import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/membership_feature_host.dart';
import '../shared/membership_data_view.dart';
import 'purchase_plan_screen.dart';
import 'refund_request_screen.dart';
import 'widgets/membership_components.dart';

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
          const SizedBox(height: 8),
          const Text(
            'Membership payments only. Coaching payments remain in your bookings.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.inkSoft,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          if (payments.isEmpty)
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.hairline),
              ),
              padding: const EdgeInsets.all(20),
              child: const Center(
                child: Text(
                  'No membership transactions yet.',
                  style: TextStyle(color: AppColors.inkSoft, fontSize: 13.5),
                ),
              ),
            ),
          ...payments.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: BillingTransactionTile(
                  payment: p,
                  serverNowMillis: data['serverNowMillis'] as int?,
                  onOpenDetails: () => open(
                      MembershipPaymentScreen(repository: repo, initial: p)),
                  onViewReceipt:
                      p['paymentStatus'] == 'cleared' && repo.sandbox
                          ? () async {
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
                                        ? 'Receipt saved to your chosen location.'
                                        : 'Receipt save cancelled.'),
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
                                      'Receipt could not be saved. Retry on Android.');
                                }
                              }
                            }
                          : null,
                  onRequestRefund: p['paymentStatus'] == 'cleared'
                      ? () => open(RefundRequestScreen(
                          repository: repo,
                          preselectedTransactionId:
                              p['transactionId'] as String))
                      : null,
                ),
              )),
          const SizedBox(height: 16),
        ];
      });
}
