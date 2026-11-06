import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/exercise_insights_repository.dart';
import '../../application/recommendation_queue_repository.dart';
import 'exercise_insights_panel.dart';
import 'recommendation_queue_panel.dart';

/// Original three-tab Module13 hub. Canonical sessions retain unavailable
/// repositories; verified FYP sessions inject their protected scoped services.
class RiskLeaderboardScreen extends StatefulWidget {
  const RiskLeaderboardScreen(
      {super.key,
      this.live = false,
      this.insightsRepository,
      this.insightsClock,
      this.queueRepository,
      this.queueClock});
  final bool live;
  final DateTime Function()? queueClock;
  final DateTime Function()? insightsClock;
  final ExerciseInsightsRepository? insightsRepository;
  final RecommendationQueueRepository? queueRepository;

  @override
  State<RiskLeaderboardScreen> createState() => _RiskLeaderboardScreenState();
}

class _RiskLeaderboardScreenState extends State<RiskLeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 3, vsync: this);
  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
              child: Text('AI Recommendations',
                  style: Theme.of(context).textTheme.headlineMedium)),
          const SizedBox(height: 4),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                  'Review exercise evidence and recommendations prepared for Admin review.',
                  style: Theme.of(context).textTheme.bodyLarge)),
          const SizedBox(height: 18),
          Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.hairline)),
              child: TabBar(
                  controller: _tabs,
                  isScrollable: MediaQuery.sizeOf(context).width < 900 ||
                      MediaQuery.textScalerOf(context).scale(13) > 16,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.inkSoft,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                  tabs: const [
                    Tab(text: 'Exercise Insights'),
                    Tab(text: 'Trainer Matching'),
                    Tab(text: 'Content Recommendations')
                  ])),
          Expanded(
              child: TabBarView(controller: _tabs, children: [
            ExerciseInsightsPanel(
                repository: widget.insightsRepository,
                clock: widget.insightsClock),
            RecommendationQueuePanel(
                trainer: true,
                repository: widget.queueRepository,
                clock: widget.queueClock),
            RecommendationQueuePanel(
                trainer: false,
                repository: widget.queueRepository,
                clock: widget.queueClock),
          ])),
        ]),
      );
}
