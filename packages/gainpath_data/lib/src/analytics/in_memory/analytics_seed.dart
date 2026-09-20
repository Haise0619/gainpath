import 'package:gainpath_domain/analytics.dart';

/// In-memory seed data for the analytics feature (frontend prototype).
class AnalyticsSeed {
  final postureTrend = <int>[64, 68, 71, 69, 76, 79, 84];

  final volumeTrend = <int>[2400, 2650, 2580, 2900, 3100, 3050, 3400];

  final weightHistory = <WeightEntry>[
    WeightEntry(DateTime.now().subtract(const Duration(days: 49)), 60.4),
    WeightEntry(DateTime.now().subtract(const Duration(days: 42)), 60.1),
    WeightEntry(DateTime.now().subtract(const Duration(days: 35)), 59.6),
    WeightEntry(DateTime.now().subtract(const Duration(days: 28)), 59.3),
    WeightEntry(DateTime.now().subtract(const Duration(days: 21)), 58.9),
    WeightEntry(DateTime.now().subtract(const Duration(days: 14)), 58.6),
    WeightEntry(DateTime.now().subtract(const Duration(days: 7)), 58.3),
    WeightEntry(DateTime.now(), 58.0),
  ];

  final muscleGroupSplit = <MuscleGroupShare>[
    MuscleGroupShare('Legs', 0.42),
    MuscleGroupShare('Back', 0.24),
    MuscleGroupShare('Chest', 0.18),
    MuscleGroupShare('Shoulders', 0.16),
  ];

  final sessionsPerWeek = <int>[3, 4, 3, 5, 4, 4, 5];

  final sessionWeekLabels = <String>['W1', 'W2', 'W3', 'W4', 'W5', 'W6', 'W7'];

  final pointsHistory = <int>[180, 220, 195, 260, 240, 310, 275, 290];

  final pointsWeekLabels = <String>[
    'W1',
    'W2',
    'W3',
    'W4',
    'W5',
    'W6',
    'W7',
    'W8'
  ];

  final adminStats = <List<String>>[
    ['Active members', '284', '+12 this month'],
    ['Verified coaches', '9', '1 pending review'],
    ['Sessions this week', '1,206', '+8% vs last week'],
    ['Revenue this month', 'RM 24,180', '+5% vs last month'],
  ];

  final usageByHour = <int>[
    2,
    1,
    1,
    0,
    1,
    4,
    12,
    22,
    26,
    18,
    14,
    16,
    19,
    17,
    15,
    20,
    28,
    42,
    48,
    39,
    26,
    15,
    8,
    4,
  ];

  /// Illustrative — the platform doesn't snapshot a historical form-score
  /// series anywhere, so this is a plausible 8-week trend for the
  /// Posture Accuracy Trend report's line chart, not derived data.
  final postureWeeklyTrend = <int>[71, 73, 72, 75, 77, 76, 79, 81];

  /// Illustrative distribution of the full member base by dropout-risk
  /// tier, sized against the same ~284-member figure the Revenue report
  /// already quotes elsewhere — the 3 `atRiskLeads` above are a sample
  /// of the "High risk" slice, not the whole picture.
  final retentionRiskMix = <ChartSlice>[
    ChartSlice('Low risk', 214),
    ChartSlice('Medium risk', 47),
    ChartSlice('High risk', 23),
  ];

  /// Illustrative weekly redemption counts for the Reward Redemptions
  /// trend chart.
  final rewardWeeklyRedemptions = <int>[9, 11, 14, 10, 16, 19, 17, 22];

  /// Real counts behind the "Most claimed rewards" breakdown — matches
  /// the 118 total redeemed figure already shown in the Rewards report.
  final rewardRedemptionMix = <ChartSlice>[
    ChartSlice('Protein Shake Voucher', 61),
    ChartSlice('Gym Towel', 33),
    ChartSlice('Free Day Pass', 17),
    ChartSlice('Water Bottle', 7),
  ];

  /// Illustrative — how many members currently sit in each workout-streak
  /// bucket, for the Gamification Engagement donut.
  final streakDistribution = <ChartSlice>[
    ChartSlice('0-3 days', 89),
    ChartSlice('4-7 days', 62),
    ChartSlice('1-2 weeks', 41),
    ChartSlice('2+ weeks', 24),
  ];
}
