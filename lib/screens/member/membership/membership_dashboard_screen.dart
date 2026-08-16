import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';
import 'billing_history_screen.dart';
import 'browse_plans_screen.dart';
import 'refund_request_screen.dart';
import 'renew_screen.dart';

/// AD-M4.2 — View Membership Dashboard. The hub for this module: current
/// plan status and auto-renew control up top, then quick entry points into
/// the three screens that used to be crammed into this same page (browse
/// plans, billing history, refunds) — each now has room to be designed
/// properly instead of fighting for space on one long scroll.
class MembershipDashboardScreen extends StatefulWidget {
  const MembershipDashboardScreen({super.key});

  @override
  State<MembershipDashboardScreen> createState() => _MembershipDashboardScreenState();
}

class _MembershipDashboardScreenState extends State<MembershipDashboardScreen> {
  bool _autoRenew = true;

  MembershipPlan get _plan =>
      MockData.membershipPlans.firstWhere((p) => p.id == MockData.currentPlanId);

  Future<void> _toggleAutoRenew(bool value) async {
    if (!value) {
      final ok = await confirmSheet(
        context,
        title: 'Turn off auto-renewal?',
        message:
            'You keep full access until your renewal date. After that your plan will not renew automatically.',
        confirmLabel: 'Turn off',
        destructive: true,
      );
      if (!ok) return;
    }
    setState(() => _autoRenew = value);
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final recent = MockData.transactions.take(2).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Membership')),
      body: PageBody(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: AppColors.primary.withValues(alpha: 0.28), blurRadius: 22, offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CURRENT PLAN',
                    style: TextStyle(
                        fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w700, color: Colors.white70)),
                const SizedBox(height: 6),
                Text(plan.name,
                    style: const TextStyle(
                        fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1)),
                const SizedBox(height: 4),
                Text('RM ${plan.price.toStringAsFixed(0)} per month  ·  renews 12 Oct',
                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.autorenew_rounded, size: 18, color: Colors.white),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('Auto-renew', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                      Switch(
                        value: _autoRenew,
                        onChanged: _toggleAutoRenew,
                        activeThumbColor: Colors.white,
                        activeTrackColor: Colors.white.withValues(alpha: 0.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 42),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                        ),
                        onPressed: () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => const RenewScreen())),
                        child: const _ActionButtonLabel('Renew now'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 42),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primaryDark,
                        ),
                        onPressed: () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => const BrowsePlansScreen())),
                        child: const _ActionButtonLabel('Change plan'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('Recent billing'),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ...recent.asMap().entries.map((entry) {
                  final t = entry.value;
                  return Column(
                    children: [
                      if (entry.key > 0) const Divider(height: 1, indent: 16),
                      ListTile(
                        title: Text(t.type, style: Theme.of(context).textTheme.titleMedium),
                        subtitle: Text(t.id, style: Theme.of(context).textTheme.bodyMedium),
                        trailing: Text('RM ${t.amount.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  );
                }),
                const Divider(height: 1, indent: 16),
                ListTile(
                  title: const Text('View all billing history',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.primary),
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const BillingHistoryScreen())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const RefundRequestScreen())),
              icon: const Icon(Icons.receipt_long_rounded, size: 18),
              label: const Text('Request a refund'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Button label that shrinks to fit a single line rather than wrapping —
/// so "Renew now" and "Change plan" always render at the same height next
/// to each other, on any screen width, without ever clipping text.
class _ActionButtonLabel extends StatelessWidget {
  final String text;
  const _ActionButtonLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        maxLines: 1,
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}
