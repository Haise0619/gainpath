import 'package:gainpath_domain/recommendation.dart';
import '../../workout/in_memory/workout_seed.dart';

/// In-memory seed data for the recommendation feature (frontend prototype).
class RecommendationSeed {
  RecommendationSeed({WorkoutSeed? workout})
      : _workout = workout ?? WorkoutSeed();

  final WorkoutSeed _workout;

  /// `[name, avgScorePct including '%', category]`. The tier ("High" /
  /// "Moderate" / "Low") used to be a 3rd stored field, but that made it
  /// impossible to actually implement AD-M13.1's "Configure Risk
  /// Threshold" — a stored tier can't react to an admin moving a
  /// threshold slider. Tier is now always computed from [postureRiskThreshold]
  /// via [riskTierFor] instead.
  final riskExercises = <List<String>>[
    ['Romanian Deadlift', '61%', 'Lower Body'],
    ['Barbell Squat', '68%', 'Lower Body'],
    ['Overhead Press', '74%', 'Upper Body'],
    ['Lunges', '76%', 'Lower Body'],
    ['Dumbbell Row', '86%', 'Upper Body'],
    ['Plank', '82%', 'Core'],
  ];

  /// AD-M13.1 — `RiskThresholdConfig.postureRiskThresholdPercent`. Mutable
  /// so the admin's slider genuinely reclassifies exercises live rather
  /// than just changing a label.
  int postureRiskThreshold = 70;

  final atRiskLeads = <RiskLead>[
    RiskLead('Nurul Huda', 'Romanian Deadlift', 58, 'Priya Menon'),
    RiskLead('Daniel Wong', 'Barbell Squat', 62, 'Jason Lim'),
    RiskLead('Wei Ling Tan', 'Overhead Press', 65, 'Hafiz Aziz'),
  ];

  /// AD-M13.2 — leads not yet surfaced. Tapping "Refresh queue" reveals
  /// the next one, simulating the `LeadEvaluator` background job the
  /// sequence diagram describes generating new leads over time, since
  /// there's no real background job here to generate them.
  final trainerLeadsPool = <RiskLead>[
    RiskLead('Farid Zainal', 'Lunges', 66, 'Michelle Chan'),
    RiskLead('Kavitha Raj', 'Dumbbell Row', 63, 'Priya Menon'),
  ];

  final contentLeads = <RiskLead>[
    RiskLead('Nurul Huda', 'Romanian Deadlift', 58, 'RDL Form Basics'),
    RiskLead('Daniel Wong', 'Barbell Squat', 62, 'Fixing Knee Valgus'),
  ];

  final contentLeadsPool = <RiskLead>[
    RiskLead('Chong Wei Ming', 'Lunges', 66, 'Lunge Mechanics Explained'),
  ];

  /// AD-M13.1 — "compare leaderboard against tutorial library, filter to
  /// missing exercise videos." Computed live from [riskExercises] and
  /// [_workout.tutorials] rather than a separately hand-curated list, so it can
  /// never drift out of sync with either — the old static version listed
  /// "Bulgarian Split Squat", which isn't even a tracked exercise.
  List<List<String>> get contentGaps {
    final covered = _workout.tutorials
        .map((t) => t.coversExercise)
        .where((name) => name.isNotEmpty)
        .toSet();
    return riskExercises
        .where((e) => !covered.contains(e[0]))
        .map((e) => [e[0], e[1], 'No tutorial linked'])
        .toList();
  }
}
