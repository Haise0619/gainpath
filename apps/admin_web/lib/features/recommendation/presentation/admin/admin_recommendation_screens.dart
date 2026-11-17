import '../../application/canonical_admin_recommendation_repository.dart';
import 'canonical_admin_recommendation_panel.dart';
import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
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
  var _tab = RecommendationMonitorTab.overview;
  bool _insights = false;
  bool _earlier = false;
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
                  if (widget.canonicalRepository != null &&
                      widget.queueRepository != null)
                    TextButton(
                        onPressed: () => setState(() => _earlier = !_earlier),
                        child: Text(
                            _earlier ? 'Workout records' : 'Earlier records')),
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
                for (final (tab, label) in const [
                  (RecommendationMonitorTab.overview, 'Overview'),
                  (RecommendationMonitorTab.history, 'History'),
                  (RecommendationMonitorTab.attention, 'Delivery Issues'),
                ])
                  ChoiceChip(
                    selectedColor: AppColors.primaryTint,
                    checkmarkColor: AppColors.primary,
                    labelStyle: const TextStyle(color: AppColors.primary),
                    label: Text(label),
                    selected: _tab == tab,
                    onSelected: (_) => setState(() => _tab = tab),
                  ),
              ])),
        Expanded(
            child: _insights
                ? ExerciseInsightsPanel(
                    repository: widget.insightsRepository,
                    clock: widget.insightsClock)
                : widget.canonicalRepository != null && !_earlier
                    ? CanonicalAdminRecommendationPanel(
                        repository: widget.canonicalRepository!,
                        onUnavailable: widget.queueRepository == null
                            ? null
                            : () {
                                if (mounted) setState(() => _earlier = true);
                              },
                        tab: _tab,
                        clock: widget.queueClock)
                    : RecommendationQueuePanel(
                        readOnly: true,
                        tab: _tab,
                        repository: widget.queueRepository,
                        clock: widget.queueClock)),
      ]));
}
