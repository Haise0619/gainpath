import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../widgets/shared.dart';
import 'admin_recommendation_screens.dart';
import 'admin_refunds_screens.dart';

/// AD-M12.1 — View Admin Dashboard.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const _ranges = ['Today', 'This week', 'This month'];
  String _range = 'Today';

  static const _revenueTrend = [18200, 19400, 21000, 20600, 22800, 23400, 24180];

  static const _activity = [
    ['Hafiz Aziz uploaded a certification document', '2h ago', Icons.workspace_premium_rounded, AppColors.warning],
    ['Farid Zainal requested a refund on TXN-2041', '3h ago', Icons.receipt_long_rounded, AppColors.danger],
    ['New booking — Priya Menon with Daniel Wong', '5h ago', Icons.event_available_rounded, AppColors.primary],
    ['Voucher GP-4K7M-92XA redeemed at the desk', '6h ago', Icons.card_giftcard_rounded, AppColors.success],
    ['12 members completed a tracked workout', '8h ago', Icons.fitness_center_rounded, AppColors.primary],
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1100;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Fury Fitness, Kulim', style: Theme.of(context).textTheme.headlineMedium),
                          const SizedBox(height: 4),
                          Text('Here is how the platform is doing.',
                              style: Theme.of(context).textTheme.bodyLarge),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      offset: const Offset(0, 42),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      onSelected: (v) => setState(() => _range = v),
                      itemBuilder: (context) =>
                          _ranges.map((r) => PopupMenuItem(value: r, child: Text(r))).toList(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.hairline),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 15, color: AppColors.inkSoft),
                            const SizedBox(width: 8),
                            Text(_range,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 6),
                            const Icon(Icons.expand_more_rounded, size: 17, color: AppColors.inkSoft),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: MockData.adminStats
                      .map((s) => _KpiCard(label: s[0], value: s[1], delta: s[2]))
                      .toList(),
                ),
                const SizedBox(height: 24),
                wide
                    ? IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 2, child: _leftColumn(context)),
                            const SizedBox(width: 20),
                            Expanded(flex: 1, child: _rightColumn(context)),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          _leftColumn(context),
                          const SizedBox(height: 20),
                          _rightColumn(context),
                        ],
                      ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _leftColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Sessions today, by hour'),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BarChart(MockData.usageByHour, height: 150),
              const SizedBox(height: 10),
              Text('Peak demand sits between 5pm and 8pm on weekdays.',
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Eyebrow('Revenue trend'),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('RM ${_revenueTrend.last}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  const SizedBox(width: 8),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: _DeltaTag(delta: '+5% vs last month', positive: true),
                  ),
                ],
              ),
              TrendChart(_revenueTrend),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Eyebrow('Recent activity'),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            children: List.generate(_activity.length, (i) {
              final a = _activity[i];
              return Column(
                children: [
                  if (i > 0) const Divider(height: 1, indent: 62),
                  ListTile(
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: (a[3] as Color).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(a[2] as IconData, size: 18, color: a[3] as Color),
                    ),
                    title: Text(a[0] as String,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            )),
                    trailing: Text(a[1] as String,
                        style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
                  ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _rightColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Needs attention'),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _alert(context, Icons.workspace_premium_rounded, AppColors.warning,
                  '1 coach awaiting verification', 'Hafiz Aziz uploaded a certificate 2 days ago'),
              const Divider(height: 1, indent: 62),
              _alert(context, Icons.receipt_long_rounded, AppColors.danger, '2 refund requests pending',
                  'Oldest submitted 3 days ago',
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const RefundDisputeDeskScreen()))),
              const Divider(height: 1, indent: 62),
              _alert(context, Icons.warning_amber_rounded, AppColors.warning, '3 members flagged at risk',
                  'Low form scores across recent sessions'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Eyebrow('Quick actions'),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _action(
                  context,
                  Icons.qr_code_scanner_rounded,
                  'Process a voucher',
                  'Redeem a member reward at the desk',
                  () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const ProcessVoucherScreen()))),
              const Divider(height: 1, indent: 62),
              _action(
                  context,
                  Icons.auto_awesome_rounded,
                  'Recommendation queue',
                  'Match at-risk members to coaches',
                  () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const RecommendationQueueScreen()))),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.groups_rounded, color: Colors.white, size: 22),
              const SizedBox(height: 12),
              Text('9 coaches, 284 members',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Facility is trending 12% above last month\'s active member count.',
                  style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.85), height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _alert(BuildContext context, IconData icon, Color color, String title, String subtitle,
      {VoidCallback? onTap}) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color == AppColors.danger ? AppColors.dangerTint : AppColors.accentTint,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 19, color: color),
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
      onTap: onTap ?? () => showToast(context, 'Opening item.'),
    );
  }

  Widget _action(
      BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(11)),
        child: Icon(icon, size: 19, color: AppColors.primary),
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String delta;
  const _KpiCard({required this.label, required this.value, required this.delta});

  bool get _positive => delta.trim().startsWith('+');

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 258,
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 8),
            _DeltaTag(delta: delta, positive: _positive),
          ],
        ),
      ),
    );
  }
}

class _DeltaTag extends StatelessWidget {
  final String delta;
  final bool positive;
  const _DeltaTag({required this.delta, required this.positive});

  @override
  Widget build(BuildContext context) {
    final color = positive ? AppColors.success : AppColors.inkSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: positive ? AppColors.successTint : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (positive) const Icon(Icons.arrow_upward_rounded, size: 12, color: AppColors.success),
          if (positive) const SizedBox(width: 3),
          Text(delta, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

/// AD-M11.5 — Process Reward Redemption Voucher.
class ProcessVoucherScreen extends StatefulWidget {
  const ProcessVoucherScreen({super.key});

  @override
  State<ProcessVoucherScreen> createState() => _ProcessVoucherScreenState();
}

class _ProcessVoucherScreenState extends State<ProcessVoucherScreen> {
  final _code = TextEditingController();
  bool _found = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Process voucher')),
      body: PageBody(
        children: [
          Text('Enter or scan the code the member is showing you.',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 18),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Voucher code',
              hintText: 'GP-XXXX-XXXX',
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner_rounded),
                onPressed: () {
                  _code.text = 'GP-4K7M-92XA';
                  setState(() => _found = true);
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () {
              if (_code.text.trim().isEmpty) {
                showToast(context, 'Enter a code first.');
                return;
              }
              setState(() => _found = true);
            },
            child: const Text('Look up code'),
          ),
          if (_found) ...[
            const SizedBox(height: 24),
            Panel(
              background: AppColors.primaryTint,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.success),
                      const SizedBox(width: 10),
                      Text('Valid voucher', style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const DetailRow('Member', 'Aisyah Rahman'),
                  const Divider(height: 18),
                  const DetailRow('Reward', 'Protein Shake Voucher'),
                  const Divider(height: 18),
                  const DetailRow('Points used', '400'),
                  const Divider(height: 18),
                  const DetailRow('Issued', '2 days ago'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                showToast(context, 'Voucher redeemed. Hand over the reward.');
              },
              child: const Text('Confirm and hand over reward'),
            ),
          ],
        ],
      ),
    );
  }
}
