import 'package:test/test.dart';
import 'package:gainpath_data/src/analytics/in_memory/in_memory_analytics_repository.dart';

void main() {
  test('InMemoryAnalyticsRepository serves seed data', () {
    final repo = InMemoryAnalyticsRepository();
    expect(repo.postureTrend, isNotEmpty);
    expect(repo.volumeTrend, isNotEmpty);
    expect(repo.weightHistory, isNotEmpty);
    expect(repo.muscleGroupSplit, isNotEmpty);
    expect(repo.sessionsPerWeek, isNotEmpty);
    expect(repo.sessionWeekLabels, isNotEmpty);
    expect(repo.pointsHistory, isNotEmpty);
    expect(repo.pointsWeekLabels, isNotEmpty);
    expect(repo.adminStats, isNotEmpty);
    expect(repo.usageByHour, isNotEmpty);
    expect(repo.postureWeeklyTrend, isNotEmpty);
    expect(repo.retentionRiskMix, isNotEmpty);
    expect(repo.rewardWeeklyRedemptions, isNotEmpty);
    expect(repo.rewardRedemptionMix, isNotEmpty);
    expect(repo.streakDistribution, isNotEmpty);
  });
}
