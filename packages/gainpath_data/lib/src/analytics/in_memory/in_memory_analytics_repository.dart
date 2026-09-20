import '../../fakes/mock_data_session.dart';
import 'analytics_seed.dart';
import 'package:gainpath_domain/analytics.dart';

/// Session-scoped in-memory [AnalyticsRepository] backed by [AnalyticsSeed].
class InMemoryAnalyticsRepository implements AnalyticsRepository {
  InMemoryAnalyticsRepository({MockDataSession? session})
      : _seed = (session ?? MockDataSession()).analytics;

  final AnalyticsSeed _seed;

  @override
  List<int> get postureTrend => _seed.postureTrend;

  @override
  List<int> get volumeTrend => _seed.volumeTrend;

  @override
  List<WeightEntry> get weightHistory => _seed.weightHistory;

  @override
  List<MuscleGroupShare> get muscleGroupSplit => _seed.muscleGroupSplit;

  @override
  List<int> get sessionsPerWeek => _seed.sessionsPerWeek;

  @override
  List<String> get sessionWeekLabels => _seed.sessionWeekLabels;

  @override
  List<int> get pointsHistory => _seed.pointsHistory;

  @override
  List<String> get pointsWeekLabels => _seed.pointsWeekLabels;

  @override
  List<List<String>> get adminStats => _seed.adminStats;

  @override
  List<int> get usageByHour => _seed.usageByHour;

  @override
  List<int> get postureWeeklyTrend => _seed.postureWeeklyTrend;

  @override
  List<ChartSlice> get retentionRiskMix => _seed.retentionRiskMix;

  @override
  List<int> get rewardWeeklyRedemptions => _seed.rewardWeeklyRedemptions;

  @override
  List<ChartSlice> get rewardRedemptionMix => _seed.rewardRedemptionMix;

  @override
  List<ChartSlice> get streakDistribution => _seed.streakDistribution;
}
