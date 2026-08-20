import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';
import '../admin_reports_screens.dart' show AdminReportDetailScreen;

/// AD-M12.1 — Reports & Analytics. Sits directly in the sidebar (no back
/// button, no push) as the platform's data-analysis home: a real sales
/// and branch-performance picture computed from `MockData.allBookings`
/// and `MockData.branches`, plus the existing library of deep-dive
/// reports (usage, posture, retention, etc.) one level down.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  static const _reportCards = [
    ['Platform usage patterns', 'When members are actually training', 'usage', Icons.schedule_rounded],
    ['Posture accuracy trends', 'Which movements score worst', 'posture', Icons.accessibility_new_rounded],
    ['Coach booking utilization', 'How full the roster is', 'booking', Icons.event_available_rounded],
    ['Retention and dropout risk', 'Members going quiet', 'retention', Icons.trending_down_rounded],
    ['Reward redemptions', 'Voucher issue and clearance', 'rewards', Icons.card_giftcard_rounded],
    ['Membership and revenue', 'Income and tier split', 'revenue', Icons.payments_rounded],
    ['Gamification engagement', 'Points, badges, and streaks', 'gamification', Icons.emoji_events_rounded],
    ['Coach performance', 'Ratings across the roster', 'coaches', Icons.sports_rounded],
  ];

  @override
  Widget build(BuildContext context) {
    final completed = MockData.allBookings.where((b) => b.status == 'Completed').toList();
    final coachingRevenue = completed.fold<double>(0, (sum, b) => sum + b.fee);
    final avgSession = completed.isEmpty ? 0.0 : coachingRevenue / completed.length;

    final revenueByCoach = <String, double>{};
    final sessionsByCoach = <String, int>{};
    for (final b in completed) {
      revenueByCoach[b.coachName] = (revenueByCoach[b.coachName] ?? 0) + b.fee;
      sessionsByCoach[b.coachName] = (sessionsByCoach[b.coachName] ?? 0) + 1;
    }
    final topCoaches = revenueByCoach.keys.toList()
      ..sort((a, b) => revenueByCoach[b]!.compareTo(revenueByCoach[a]!));
    final maxCoachRevenue = topCoaches.isEmpty ? 1.0 : revenueByCoach[topCoaches.first]!;

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
                Text('Reports & analytics', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text('Sales, branch performance, and the full report library.',
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    const SizedBox(width: 220, child: StatTile('RM 24,180', 'Membership revenue / month')),
                    SizedBox(
                        width: 220,
                        child: StatTile('RM ${coachingRevenue.toStringAsFixed(0)}',
                            'Coaching revenue, all completed sessions')),
                    SizedBox(
                        width: 220,
                        child: StatTile('RM ${avgSession.toStringAsFixed(0)}', 'Avg. revenue per session')),
                    SizedBox(
                        width: 220,
                        child: StatTile('${completed.length}', 'Completed sessions tracked')),
                  ],
                ),
                const SizedBox(height: 24),
                wide
                    ? IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: _salesColumn(context, topCoaches, revenueByCoach, sessionsByCoach, maxCoachRevenue)),
                            const SizedBox(width: 20),
                            Expanded(flex: 2, child: _branchColumn(context)),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          _salesColumn(context, topCoaches, revenueByCoach, sessionsByCoach, maxCoachRevenue),
                          const SizedBox(height: 20),
                          _branchColumn(context),
                        ],
                      ),
                const SizedBox(height: 28),
                const Eyebrow('Detailed reports'),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: _reportCards.map((r) {
                    return SizedBox(
                      width: 258,
                      height: 130,
                      child: Panel(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => AdminReportDetailScreen(
                                  title: r[0] as String, type: r[2] as String)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryTint,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(r[3] as IconData, size: 18, color: AppColors.primary),
                                ),
                                const Spacer(),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.inkSoft),
                              ],
                            ),
                            const Spacer(),
                            Text(r[0] as String, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14.5)),
                            const SizedBox(height: 3),
                            Text(r[1] as String,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _salesColumn(BuildContext context, List<String> topCoaches, Map<String, double> revenueByCoach,
      Map<String, int> sessionsByCoach, double maxCoachRevenue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Membership revenue trend'),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('RM 24,180',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primary)),
              const SizedBox(height: 4),
              Text('Last 7 months', style: Theme.of(context).textTheme.bodyMedium),
              const TrendChart([18200, 19400, 21000, 20600, 22800, 23400, 24180]),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Eyebrow('Coaching revenue by coach'),
        Panel(
          child: topCoaches.isEmpty
              ? const Text('No completed sessions yet.')
              : Column(
                  children: topCoaches.map((name) {
                    final revenue = revenueByCoach[name]!;
                    final sessions = sessionsByCoach[name]!;
                    return ProgressRow(
                      name,
                      revenue / maxCoachRevenue,
                      'RM ${revenue.toStringAsFixed(0)} · $sessions sessions',
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _branchColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Branch performance'),
        ...MockData.branches.map((branch) {
          final branchCoaches = MockData.coaches.where((c) => c.branch == branch.name).toList();
          final branchBookings = MockData.allBookings
              .where((b) => b.branch == branch.name && b.status == 'Completed')
              .toList();
          final branchRevenue = branchBookings.fold<double>(0, (sum, b) => sum + b.fee);
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(branch.name, style: Theme.of(context).textTheme.titleMedium),
                      ),
                      statusPill(branch.isActive ? 'Active' : 'Suspended'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(branch.address, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text(branch.contactPhone, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                          child: StatTile('${branchCoaches.length}', 'Coaches assigned', compact: true)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: StatTile('${branchBookings.length}', 'Sessions completed', compact: true)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: StatTile('RM ${branchRevenue.toStringAsFixed(0)}', 'Revenue generated',
                              compact: true)),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
