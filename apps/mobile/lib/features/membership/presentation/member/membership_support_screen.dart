import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/membership_feature_host.dart';
import '../shared/membership_data_view.dart';
import 'refund_request_screen.dart';

/// A factual assistance destination. No unconfigured contact channel is invented.
class MembershipSupportScreen extends StatelessWidget {
  const MembershipSupportScreen(
      {super.key, required this.repository, required this.payment});
  final MembershipCommerceRepository repository;
  final Map<String, dynamic> payment;
  @override
  Widget build(BuildContext context) => MembershipRepositoryGuard(
      repository: repository,
      child: Scaffold(
          appBar: AppBar(title: const Text('Payment assistance')),
          body: PageBody(children: [
            const Panel(
                child: Text(
                    'Keep this payment reference for your gym administrator. Do not pay again while the original payment is being reviewed.')),
            const SizedBox(height: 18),
            Text(
                '${payment['planName']} · ${membershipMoney(payment['amountMinor'])}',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(membershipPaymentLabel(payment)),
            const SizedBox(height: 16),
            const Text('Payment reference'),
            SelectableText('${payment['transactionId']}'),
            TextButton.icon(
                onPressed: () async {
                  if (!repository.current) return;
                  await Clipboard.setData(
                      ClipboardData(text: '${payment['transactionId']}'));
                  if (context.mounted && repository.current)
                    showToast(context, 'Payment reference copied.');
                },
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy reference')),
            const SizedBox(height: 16),
            const Text(
                'An in-app support conversation is not configured. Ask your gym administrator to review this reference in the payment management screen.'),
            if (payment['paymentStatus'] == 'cleared') ...[
              const SizedBox(height: 20),
              FilledButton.tonal(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) => RefundRequestScreen(
                              repository: repository,
                              preselectedTransactionId:
                                  payment['transactionId'] as String))),
                  child: const Text('Refund eligibility and status')),
            ],
          ])));
}
