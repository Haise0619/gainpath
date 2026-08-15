import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../widgets/shared.dart';

/// AD-M5.1 — View Personalized Progress Dashboard.
class ProgressDashboardScreen extends StatelessWidget {
  const ProgressDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your progress')),
      body: PageBody(
        children: [
          Row(
            children: const [
              Expanded(child: StatTile('18', 'Sessions this month')),
              SizedBox(width: 10),
              Expanded(
                  child: StatTile('84%', 'Avg form',
                      valueColor: AppColors.success)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: const [
              Expanded(child: StatTile('3,400', 'kg lifted this week')),
              SizedBox(width: 10),
              Expanded(child: StatTile('12', 'Day streak')),
            ],
          ),
          const SizedBox(height: 20),
          const Eyebrow('Deep dives'),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _link(context, Icons.bar_chart_rounded,
                    'Workout performance', 'Volume and muscle group split',
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const _DeepDiveScreen(
                                title: 'Workout performance',
                                type: _ReportType.volume)))),
                const Divider(height: 1, indent: 62),
                _link(context, Icons.show_chart_rounded,
                    'Posture accuracy trend', 'How your form is changing',
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const _DeepDiveScreen(
                                title: 'Posture accuracy',
                                type: _ReportType.posture)))),
                const Divider(height: 1, indent: 62),
                _link(context, Icons.history_rounded, 'Activity timeline',
                    'Everything you have logged',
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const _DeepDiveScreen(
                                title: 'Activity timeline',
                                type: _ReportType.timeline)))),
                const Divider(height: 1, indent: 62),
                _link(context, Icons.flag_rounded, 'Goal progress',
                    'How you are tracking against your targets',
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const GoalProgressScreen()))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _link(BuildContext context, IconData icon, String title,
      String subtitle, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 19, color: AppColors.primary),
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
    );
  }
}

enum _ReportType { volume, posture, timeline }

/// AD-M5.2 — View Deep-Dive Report (parameterised by report type).
class _DeepDiveScreen extends StatelessWidget {
  final String title;
  final _ReportType type;
  const _DeepDiveScreen({required this.title, required this.type});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Filter',
            onPressed: () => _filter(context),
          ),
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Export',
            onPressed: () => showToast(context, 'Report saved to your device.'),
          ),
        ],
      ),
      body: PageBody(children: _content(context)),
    );
  }

  List<Widget> _content(BuildContext context) {
    switch (type) {
      case _ReportType.volume:
        return [
          const Eyebrow('Weekly volume (kg)'),
          Panel(
            child: BarChart(MockData.volumeTrend,
                labels: const ['W1', 'W2', 'W3', 'W4', 'W5', 'W6', 'W7']),
          ),
          const SizedBox(height: 20),
          const Eyebrow('Muscle group split'),
          Panel(
            child: Column(
              children: const [
                ProgressRow('Legs', 0.42, '42%'),
                ProgressRow('Back', 0.24, '24%'),
                ProgressRow('Chest', 0.18, '18%'),
                ProgressRow('Shoulders', 0.16, '16%'),
              ],
            ),
          ),
        ];
      case _ReportType.posture:
        return [
          const Eyebrow('Form accuracy over time'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrendChart(MockData.postureTrend),
                const SizedBox(height: 12),
                Text('Up 20 points over the last 7 sessions.',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('By exercise'),
          Panel(
            child: Column(
              children: const [
                ProgressRow('Dumbbell Row', 0.88, '88%',
                    color: AppColors.success),
                ProgressRow('Barbell Squat', 0.84, '84%',
                    color: AppColors.success),
                ProgressRow('Overhead Press', 0.79, '79%',
                    color: AppColors.warning),
                ProgressRow('Romanian Deadlift', 0.71, '71%',
                    color: AppColors.warning),
              ],
            ),
          ),
        ];
      case _ReportType.timeline:
        return [
          ...MockData.history.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Panel(
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.fitness_center_rounded,
                            size: 19, color: AppColors.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.exercise,
                                style:
                                    Theme.of(context).textTheme.titleMedium),
                            Text(
                                '${_ago(r.date)}  ·  ${r.reps} reps  ·  ${r.durationMin} min',
                                style:
                                    Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                      Text('${r.accuracy}%',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: r.accuracy >= 80
                                  ? AppColors.success
                                  : AppColors.warning)),
                    ],
                  ),
                ),
              )),
        ];
    }
  }

  String _ago(DateTime d) {
    final days = DateTime.now().difference(d).inDays;
    if (days == 0) return 'Today';
    if (days == 1) return 'Yesterday';
    return '$days days ago';
  }

  void _filter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.of(ctx).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            const Eyebrow('Date range'),
            Wrap(
              spacing: 8,
              children: const [
                Chip(label: Text('Last 7 days')),
                Chip(label: Text('Last 30 days')),
                Chip(label: Text('All time')),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                showToast(context, 'Filters applied.');
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}

/// AD-M5.3 — View Goal Progress Comparison.
class GoalProgressScreen extends StatelessWidget {
  const GoalProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Goal progress')),
      body: PageBody(
        children: [
          Text('How you are tracking against the goals you set.',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 18),
          Panel(
            child: Column(
              children: const [
                ProgressRow('Train 4x per week', 0.75, '3 of 4'),
                Divider(height: 24),
                ProgressRow('Hit 85% average form', 0.99, '84 of 85',
                    color: AppColors.accent),
                Divider(height: 24),
                ProgressRow('Squat 70kg for 8 reps', 0.86, '60 of 70 kg'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Panel(
            background: AppColors.primaryTint,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.emoji_objects_rounded,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'One more session this week and you hit your frequency goal.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
