import 'package:gainpath/features/analytics/data/in_memory/analytics_seed.dart';
import 'package:gainpath/features/analytics/domain/entities/analytics_points.dart';
import 'package:gainpath/features/analytics/domain/repositories/analytics_repository.dart';

/// Session-scoped in-memory [AnalyticsRepository] backed by [AnalyticsSeed].
class InMemoryAnalyticsRepository implements AnalyticsRepository {
  @override
  List<int> get postureTrend => AnalyticsSeed.postureTrend;

  @override
  List<int> get volumeTrend => AnalyticsSeed.volumeTrend;

  @override
  List<WeightEntry> get weightHistory => AnalyticsSeed.weightHistory;

  @override
  List<MuscleGroupShare> get muscleGroupSplit => AnalyticsSeed.muscleGroupSplit;

  @override
  List<int> get sessionsPerWeek => AnalyticsSeed.sessionsPerWeek;

  @override
  List<String> get sessionWeekLabels => AnalyticsSeed.sessionWeekLabels;

  @override
  List<int> get pointsHistory => AnalyticsSeed.pointsHistory;

  @override
  List<String> get pointsWeekLabels => AnalyticsSeed.pointsWeekLabels;

  @override
  List<List<String>> get adminStats => AnalyticsSeed.adminStats;

  @override
  List<int> get usageByHour => AnalyticsSeed.usageByHour;

  @override
  List<int> get postureWeeklyTrend => AnalyticsSeed.postureWeeklyTrend;

  @override
  List<ChartSlice> get retentionRiskMix => AnalyticsSeed.retentionRiskMix;

  @override
  List<int> get rewardWeeklyRedemptions => AnalyticsSeed.rewardWeeklyRedemptions;

  @override
  List<ChartSlice> get rewardRedemptionMix => AnalyticsSeed.rewardRedemptionMix;

  @override
  List<ChartSlice> get streakDistribution => AnalyticsSeed.streakDistribution;
}
