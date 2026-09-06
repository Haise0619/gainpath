import 'package:gainpath/features/analytics/domain/entities/analytics_points.dart';

/// In-memory seed data for the analytics feature (frontend prototype).
class AnalyticsSeed {
  static const postureTrend = <int>[64, 68, 71, 69, 76, 79, 84];

  static const volumeTrend = <int>[2400, 2650, 2580, 2900, 3100, 3050, 3400];

  static final weightHistory = <WeightEntry>[
    WeightEntry(DateTime.now().subtract(const Duration(days: 49)), 60.4),
    WeightEntry(DateTime.now().subtract(const Duration(days: 42)), 60.1),
    WeightEntry(DateTime.now().subtract(const Duration(days: 35)), 59.6),
    WeightEntry(DateTime.now().subtract(const Duration(days: 28)), 59.3),
    WeightEntry(DateTime.now().subtract(const Duration(days: 21)), 58.9),
    WeightEntry(DateTime.now().subtract(const Duration(days: 14)), 58.6),
    WeightEntry(DateTime.now().subtract(const Duration(days: 7)), 58.3),
    WeightEntry(DateTime.now(), 58.0),
  ];

  static const muscleGroupSplit = <MuscleGroupShare>[
    MuscleGroupShare('Legs', 0.42),
    MuscleGroupShare('Back', 0.24),
    MuscleGroupShare('Chest', 0.18),
    MuscleGroupShare('Shoulders', 0.16),
  ];

  static const sessionsPerWeek = <int>[3, 4, 3, 5, 4, 4, 5];

  static const sessionWeekLabels = <String>['W1', 'W2', 'W3', 'W4', 'W5', 'W6', 'W7'];

  static const pointsHistory = <int>[180, 220, 195, 260, 240, 310, 275, 290];

  static const pointsWeekLabels = <String>['W1', 'W2', 'W3', 'W4', 'W5', 'W6', 'W7', 'W8'];

  static const adminStats = <List<String>>[
    ['Active members', '284', '+12 this month'],
    ['Verified IdentitySeed.coaches', '9', '1 pending review'],
    ['Sessions this week', '1,206', '+8% vs last week'],
    ['Revenue this month', 'RM 24,180', '+5% vs last month'],
  ];

  static const usageByHour = <int>[
    2, 1, 1, 0, 1, 4, 12, 22, 26, 18, 14, 16,
    19, 17, 15, 20, 28, 42, 48, 39, 26, 15, 8, 4,
  ];

  /// Illustrative — the platform doesn't snapshot a historical form-score
  /// series anywhere, so this is a plausible 8-week trend for the
  /// Posture Accuracy Trend report's line chart, not derived data.
  static const postureWeeklyTrend = <int>[71, 73, 72, 75, 77, 76, 79, 81];

  /// Illustrative distribution of the full member base by dropout-risk
  /// tier, sized against the same ~284-member figure the Revenue report
  /// already quotes elsewhere — the 3 `atRiskLeads` above are a sample
  /// of the "High risk" slice, not the whole picture.
  static const retentionRiskMix = <ChartSlice>[
    ChartSlice('Low risk', 214),
    ChartSlice('Medium risk', 47),
    ChartSlice('High risk', 23),
  ];

  /// Illustrative weekly redemption counts for the Reward Redemptions
  /// trend chart.
  static const rewardWeeklyRedemptions = <int>[9, 11, 14, 10, 16, 19, 17, 22];

  /// Real counts behind the "Most claimed rewards" breakdown — matches
  /// the 118 total redeemed figure already shown in the Rewards report.
  static const rewardRedemptionMix = <ChartSlice>[
    ChartSlice('Protein Shake Voucher', 61),
    ChartSlice('Gym Towel', 33),
    ChartSlice('Free Day Pass', 17),
    ChartSlice('Water Bottle', 7),
  ];

  /// Illustrative — how many members currently sit in each workout-streak
  /// bucket, for the Gamification Engagement donut.
  static const streakDistribution = <ChartSlice>[
    ChartSlice('0-3 days', 89),
    ChartSlice('4-7 days', 62),
    ChartSlice('1-2 weeks', 41),
    ChartSlice('2+ weeks', 24),
  ];
}
