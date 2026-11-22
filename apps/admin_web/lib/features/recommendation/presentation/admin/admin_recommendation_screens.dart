import '../../application/canonical_admin_recommendation_repository.dart';
import 'canonical_admin_recommendation_panel.dart';
import 'package:flutter/material.dart';
import '../../application/exercise_insights_repository.dart';
import '../../application/recommendation_queue_repository.dart';
import 'exercise_insights_panel.dart';
import 'recommendation_queue_panel.dart';
import 'recommendation_monitor.dart';

/// Recommendations share the existing protected queue and session scope.
class RiskLeaderboardScreen extends StatefulWidget {
  const RiskLeaderboardScreen(
      {super.key,
      this.live = false,
      this.insightsRepository,
      this.insightsClock,
      this.queueRepository,
      this.queueClock,
      this.canonicalRepository,
      this.relatedLinks = const {},
      this.initialInsights = false,
      this.initialTab = RecommendationMonitorTab.overview});
  final Map<String, VoidCallback> relatedLinks;
  final bool initialInsights;
  final RecommendationMonitorTab initialTab;
  final CanonicalAdminRecommendationRepository? canonicalRepository;
  final bool live;
  final DateTime Function()? queueClock, insightsClock;
  final ExerciseInsightsRepository? insightsRepository;
  final RecommendationQueueRepository? queueRepository;
  @override
  State<RiskLeaderboardScreen> createState() => _RiskLeaderboardScreenState();
}

class _RiskLeaderboardScreenState extends State<RiskLeaderboardScreen> {
  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: widget.initialInsights
                ? ExerciseInsightsPanel(
                    repository: widget.insightsRepository,
                    clock: widget.insightsClock)
                : widget.canonicalRepository != null
                    ? CanonicalAdminRecommendationPanel(
                        repository: widget.canonicalRepository!,
                        tab: widget.initialTab,
                        clock: widget.queueClock,
                        relatedLinks: widget.relatedLinks)
                    : RecommendationQueuePanel(
                        readOnly: true,
                        tab: widget.initialTab,
                        repository: widget.queueRepository,
                        clock: widget.queueClock)),
      ]));
}
