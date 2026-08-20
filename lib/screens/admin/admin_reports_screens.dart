import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../widgets/shared.dart';

// The report-list hub (AD-M12.1) now lives at reports/reports_screen.dart
// as an in-place sidebar pane, alongside the new sales/branch analysis.
// AdminReportDetailScreen below is unchanged and reused from there.

/// AD-M12.2 — View Deep-Dive Report, parameterised by report type.
class AdminReportDetailScreen extends StatelessWidget {
  final String title;
  final String type;
  const AdminReportDetailScreen(
      {super.key, required this.title, required this.type});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Filter',
            onPressed: () => showToast(context, 'Filter options.'),
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Export',
            onPressed: () => showToast(context, 'Report exported.'),
          ),
        ],
      ),
      body: PageBody(children: _body(context)),
    );
  }

  List<Widget> _body(BuildContext context) {
    switch (type) {
      case 'usage':
        return [
          const Eyebrow('Sessions started, by hour'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BarChart(MockData.usageByHour, height: 160),
                const SizedBox(height: 12),
                Text('Peak demand sits between 5pm and 8pm on weekdays.',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Panel(
            background: AppColors.surfaceAlt,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 18, color: AppColors.inkSoft),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This shows app usage across all locations. It does not track '
                    'whether a session happened at the gym or at home.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ];
      case 'posture':
        return [
          const Eyebrow('Average form score by exercise'),
          Panel(
            child: Column(
              children: MockData.riskExercises.map((e) {
                final pct = int.parse(e[1].replaceAll('%', ''));
                return ProgressRow(
                  e[0],
                  pct / 100,
                  e[1],
                  color: pct < 70
                      ? AppColors.danger
                      : pct < 80
                          ? AppColors.warning
                          : AppColors.success,
                );
              }).toList(),
            ),
          ),
        ];
      case 'retention':
        return [
          const Eyebrow('Members at risk'),
          ...MockData.atRiskLeads.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Panel(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.memberName,
                                style:
                                    Theme.of(context).textTheme.titleMedium),
                            Text('Weakest: ${l.weakCategory}',
                                style:
                                    Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                      statusPill('High'),
                    ],
                  ),
                ),
              )),
        ];
      case 'revenue':
        return [
          Row(
            children: const [
              Expanded(child: StatTile('RM 24,180', 'This month')),
              SizedBox(width: 10),
              Expanded(child: StatTile('284', 'Paying members')),
            ],
          ),
          const SizedBox(height: 16),
          const Eyebrow('Revenue by month'),
          Panel(
            child: BarChart(
              const [18200, 19400, 21000, 20600, 22800, 23400, 24180],
              labels: const ['Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep'],
            ),
          ),
          const SizedBox(height: 16),
          const Eyebrow('Tier split'),
          Panel(
            child: Column(
              children: const [
                ProgressRow('Premium', 0.62, '176 members'),
                ProgressRow('Basic', 0.38, '108 members',
                    color: AppColors.accent),
              ],
            ),
          ),
        ];
      case 'coaches':
        return [
          const Eyebrow('Coach ratings'),
          ...MockData.coaches.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Panel(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name,
                                style:
                                    Theme.of(context).textTheme.titleMedium),
                            Text('${c.reviews} reviews',
                                style:
                                    Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                      const Icon(Icons.star_rounded,
                          size: 17, color: AppColors.accent),
                      const SizedBox(width: 4),
                      Text('${c.rating}',
                          style: const TextStyle(
                              fontSize: 15.5, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              )),
        ];
      case 'booking':
        return [
          const Eyebrow('Roster fill rate'),
          Panel(
            child: Column(
              children: const [
                ProgressRow('Jason Lim', 0.92, '92%'),
                ProgressRow('Priya Menon', 0.78, '78%'),
                ProgressRow('Hafiz Aziz', 0.64, '64%',
                    color: AppColors.warning),
                ProgressRow('Michelle Chan', 0.41, '41%',
                    color: AppColors.danger),
              ],
            ),
          ),
        ];
      case 'rewards':
        return [
          Row(
            children: const [
              Expanded(child: StatTile('142', 'Vouchers issued')),
              SizedBox(width: 10),
              Expanded(child: StatTile('118', 'Redeemed')),
            ],
          ),
          const SizedBox(height: 16),
          const Eyebrow('Most claimed rewards'),
          Panel(
            child: Column(
              children: const [
                ProgressRow('Protein Shake Voucher', 0.52, '61'),
                ProgressRow('Gym Towel', 0.28, '33'),
                ProgressRow('Free Day Pass', 0.14, '17'),
                ProgressRow('Water Bottle', 0.06, '7'),
              ],
            ),
          ),
        ];
      case 'gamification':
      default:
        return [
          Row(
            children: const [
              Expanded(child: StatTile('62%', 'Members with a streak')),
              SizedBox(width: 10),
              Expanded(child: StatTile('418', 'Badges earned')),
            ],
          ),
          const SizedBox(height: 16),
          const Eyebrow('Points earned per week'),
          Panel(
            child: BarChart(
              const [12400, 13800, 12900, 15200, 16100, 15600, 17400],
              labels: const ['W1', 'W2', 'W3', 'W4', 'W5', 'W6', 'W7'],
            ),
          ),
        ];
    }
  }
}
