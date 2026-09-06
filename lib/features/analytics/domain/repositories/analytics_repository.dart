import 'package:gainpath/features/analytics/domain/entities/analytics_points.dart';

/// Data access contract for the analytics feature. Implemented in-memory for the
/// prototype; a Firebase implementation will sit behind the same interface.
abstract class AnalyticsRepository {
  List<int> get postureTrend;
  List<int> get volumeTrend;
  List<WeightEntry> get weightHistory;
  List<MuscleGroupShare> get muscleGroupSplit;
  List<int> get sessionsPerWeek;
  List<String> get sessionWeekLabels;
  List<int> get pointsHistory;
  List<String> get pointsWeekLabels;
  List<List<String>> get adminStats;
  List<int> get usageByHour;
  List<int> get postureWeeklyTrend;
  List<ChartSlice> get retentionRiskMix;
  List<int> get rewardWeeklyRedemptions;
  List<ChartSlice> get rewardRedemptionMix;
  List<ChartSlice> get streakDistribution;
}
