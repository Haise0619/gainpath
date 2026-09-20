import 'package:flutter/material.dart';
import '../../application/membership_bloc.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../shared/billplz_checkout_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/membership.dart';

/// AD-M4.3 — Renew Membership Subscription. Reads the member's actual
/// current plan rather than a fixed sample, so this stays correct however
/// many tiers exist or whichever one is active.
class RenewScreen extends StatelessWidget {
  const RenewScreen({super.key});

  MembershipPlan _plan(BuildContext context) {
    final repo = context.read<MembershipRepository>();
    return repo.membershipPlans.firstWhere((p) => p.id == repo.currentPlanId);
  }

  String get _newExpiry {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final d = DateTime.now().add(const Duration(days: 30));
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Renew membership')),
      body: PageBody(
        children: [
          Panel(
            child: Column(
              children: [
                DetailRow('Plan', plan.name),
                const Divider(height: 20),
                const DetailRow('Period', '1 month'),
                const Divider(height: 20),
                DetailRow('New expiry', _newExpiry),
                const Divider(height: 20),
                DetailRow('Total', 'RM ${plan.price.toStringAsFixed(2)}'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Panel(
            background: AppColors.surfaceAlt,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_outline_rounded,
                    size: 18, color: AppColors.inkSoft),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Payment is handled on the provider\'s secure page. GainPath never '
                    'sees or stores your card details.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () async {
              final success = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      BillplzCheckoutScreen(amount: plan.price, description: '${plan.name} renewal'),
                ),
              );
              if (success != true || !context.mounted) return;
              context.read<MembershipBloc>().add(MembershipRenewed(plan.price));
              Navigator.pop(context);
              showToast(context, 'Membership renewed until $_newExpiry.');
            },
            child: Text('Pay RM ${plan.price.toStringAsFixed(2)}'),
          ),
        ],
      ),
    );
  }
}
