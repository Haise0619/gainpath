import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../widgets/shared.dart';

/// AD-M9.3 — View Performance Metrics Dashboard.
class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Earnings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Export statement',
            onPressed: () =>
                showToast(context, 'Statement saved to your device.'),
          ),
        ],
      ),
      body: PageBody(
        children: [
          Panel(
            background: AppColors.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('THIS MONTH',
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70)),
                const SizedBox(height: 6),
                const Text('RM 2,880',
                    style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -1)),
                const SizedBox(height: 4),
                const Text('24 sessions completed',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              Expanded(
                  child: StatTile('4.8', 'Avg rating',
                      valueColor: AppColors.accent)),
              SizedBox(width: 10),
              Expanded(child: StatTile('47', 'Reviews')),
              SizedBox(width: 10),
              Expanded(child: StatTile('92%', 'Fill rate')),
            ],
          ),
          const SizedBox(height: 20),
          const Eyebrow('Weekly earnings'),
          Panel(
            child: BarChart(
              const [520, 610, 480, 720, 660, 590, 780],
              labels: const ['W1', 'W2', 'W3', 'W4', 'W5', 'W6', 'W7'],
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('Recent sessions'),
          ...MockData.coachRoster
              .where((b) => b.status == 'Completed')
              .map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Panel(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(b.memberName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                Text('Completed session',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium),
                              ],
                            ),
                          ),
                          Text('RM ${b.fee.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.success)),
                        ],
                      ),
                    ),
                  )),
          const SizedBox(height: 6),
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
                    'Figures reflect completed and cleared sessions only. Payouts are '
                    'settled by the facility on their usual schedule.',
                    style: Theme.of(context).textTheme.bodyMedium,
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
