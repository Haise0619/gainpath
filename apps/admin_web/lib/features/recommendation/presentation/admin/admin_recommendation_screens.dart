import '../../application/canonical_admin_recommendation_repository.dart';
import 'canonical_admin_recommendation_panel.dart';
import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/exercise_insights_repository.dart';
import '../../application/recommendation_queue_repository.dart';
import 'exercise_insights_panel.dart';
import 'recommendation_queue_panel.dart';

/// Recommendations share the existing protected queue and session scope.
class RiskLeaderboardScreen extends StatefulWidget {
  const RiskLeaderboardScreen(
      {super.key,
      this.live = false,
      this.insightsRepository,
      this.insightsClock,
      this.queueRepository,
      this.queueClock,
      this.canonicalRepository});
  final CanonicalAdminRecommendationRepository? canonicalRepository;
  final bool live;
  final DateTime Function()? queueClock, insightsClock;
  final ExerciseInsightsRepository? insightsRepository;
  final RecommendationQueueRepository? queueRepository;
  @override
  State<RiskLeaderboardScreen> createState() => _RiskLeaderboardScreenState();
}

class _RiskLeaderboardScreenState extends State<RiskLeaderboardScreen> {
  bool _history = false, _insights = false;
  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 8,
                children: [
                  Text('Recommendations',
                      style: Theme.of(context).textTheme.headlineMedium),
                  TextButton.icon(
                      onPressed: () => setState(() => _insights = !_insights),
                      icon: Icon(_insights
                          ? Icons.arrow_back
                          : Icons.insights_outlined),
                      label: Text(_insights
                          ? 'Back to recommendations'
                          : 'Exercise Guidance Insights')),
                ])),
        if (!_insights)
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                ChoiceChip(
                    selectedColor: AppColors.primaryTint,
                    checkmarkColor: AppColors.primary,
                    labelStyle: const TextStyle(color: AppColors.primary),
                    label: const Text('Needs Review'),
                    selected: !_history,
                    onSelected: (_) => setState(() => _history = false)),
                ChoiceChip(
                    selectedColor: AppColors.primaryTint,
                    checkmarkColor: AppColors.primary,
                    labelStyle: const TextStyle(color: AppColors.primary),
                    label: const Text('History'),
                    selected: _history,
                    onSelected: (_) => setState(() => _history = true)),
              ])),
        Expanded(
            child: _insights
                ? ExerciseInsightsPanel(
                    repository: widget.insightsRepository,
                    clock: widget.insightsClock)
                : widget.canonicalRepository != null
                    ? CanonicalAdminRecommendationPanel(
                        repository: widget.canonicalRepository!,
                        history: _history,
                        clock: widget.queueClock)
                    : RecommendationQueuePanel(
                        history: _history,
                        repository: widget.queueRepository,
                        clock: widget.queueClock)),
      ]));
}
