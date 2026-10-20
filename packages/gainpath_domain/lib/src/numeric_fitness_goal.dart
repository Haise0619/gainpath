import 'identity.dart';

/// UC-1.11 numeric targets, separate from the existing training-focus tags.
/// These describe intentions. They never imply measured progress or achievement.
enum NumericGoalCategory {
  trainingFrequency(
      'Weekly training frequency', 'sessions', 'calendarWeek', 1, 14),
  bodyWeight('Body weight', 'kg', 'latestMeasurement', 35, 160),
  repetitions('Repetitions per workout', 'repetitions', 'perSession', 1, 1000);

  const NumericGoalCategory(
      this.label, this.unit, this.evaluationPeriod, this.minimum, this.maximum);
  final String label;
  final String unit;
  final String evaluationPeriod;
  final double minimum;
  final double maximum;

  String get periodLabel => switch (this) {
        trainingFrequency =>
          'Workout sessions per calendar week (Monday–Sunday, UTC)',
        bodyWeight => 'Latest body-weight measurement',
        repetitions => 'Total repetitions in one workout session',
      };

  String? validate(num value) {
    if (!value.isFinite || value < minimum || value > maximum) {
      return 'Enter a value from ${minimum.toInt()} to ${maximum.toInt()} $unit.';
    }
    if (this != bodyWeight && value != value.roundToDouble()) {
      return 'Enter a whole number of $unit.';
    }
    if (this == bodyWeight &&
        (value * 10 - (value * 10).round()).abs() > 0.0000001) {
      return 'Use at most one decimal place for kilograms.';
    }
    return null;
  }
}

enum NumericGoalStatus { active, archived }

class NumericFitnessGoal {
  NumericFitnessGoal({
    required this.id,
    required this.category,
    required this.targetValue,
    required this.status,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    this.editBaseline,
  }) {
    validateGoalId(id);
    if (category.validate(targetValue) != null ||
        revision < 1 ||
        updatedAt.isBefore(createdAt)) {
      throw ArgumentError('Invalid saved fitness target.');
    }
  }

  final String id;
  final NumericGoalCategory category;
  final double targetValue;
  final NumericGoalStatus status;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Object? editBaseline;
  String get unit => category.unit;
  String get evaluationPeriod => category.evaluationPeriod;
  String get targetLabel =>
      '${targetValue == targetValue.roundToDouble() ? targetValue.toInt() : targetValue} $unit';
}

void validateGoalId(String id) {
  if (!RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(id)) {
    throw ArgumentError('A fitness target needs a valid document ID.');
  }
}

abstract interface class NumericFitnessGoalRepository {
  SessionScope get scope;

  /// Allocated once per create form and retained across retry attempts.
  String allocateId();
  Future<List<NumericFitnessGoal>> loadActive();
  Future<void> create(
      {required String id,
      required NumericGoalCategory category,
      required double targetValue});
  Future<void> update(NumericFitnessGoal original,
      {required double targetValue});
  Future<void> archive(NumericFitnessGoal original);
}

class NumericGoalException implements Exception {
  const NumericGoalException(this.message, {this.reloadRequired = false});
  final String message;
  final bool reloadRequired;
  @override
  String toString() => message;
}
