/// Execution is a content contract; AI availability still comes from the registry.
enum ExerciseExecutionMode {
  aiTracked,
  videoGuidedTimed,
  legacyManual;

  static ExerciseExecutionMode fromJson(Object? value) =>
      values.where((v) => v.name == value).firstOrNull ??
      (throw const FormatException('Unknown exercise execution mode'));
}

sealed class ExercisePrescription {
  const ExercisePrescription({required this.sets, required this.restSeconds});
  final int sets;
  final int restSeconds;
  void validate() {
    if (sets < 1 || sets > 50 || restSeconds < 0 || restSeconds > 600) {
      throw const FormatException('Invalid exercise sets or rest');
    }
  }

  Map<String, dynamic> toJson();

  static ExercisePrescription fromJson(Map<String, dynamic> json) {
    if (json['sets'] is! int ||
        json['restSeconds'] is! int ||
        (json.containsKey('reps') == json.containsKey('durationSeconds'))) {
      throw const FormatException('Expected exactly one exercise target');
    }
    final ExercisePrescription target;
    if (json.containsKey('durationSeconds')) {
      if (json['durationSeconds'] is! int) {
        throw const FormatException('Invalid duration');
      }
      target = TimedPrescription(
          sets: json['sets'] as int,
          durationSeconds: json['durationSeconds'] as int,
          restSeconds: json['restSeconds'] as int);
    } else {
      if (json['reps'] is! int) {
        throw const FormatException('Invalid repetitions');
      }
      target = RepetitionPrescription(
          sets: json['sets'] as int,
          repetitions: json['reps'] as int,
          restSeconds: json['restSeconds'] as int);
    }
    target.validate();
    return target;
  }
}

final class RepetitionPrescription extends ExercisePrescription {
  const RepetitionPrescription(
      {required super.sets,
      required this.repetitions,
      required super.restSeconds});
  final int repetitions;
  @override
  void validate() {
    super.validate();
    if (repetitions < 1 || repetitions > 100) {
      throw const FormatException('Invalid repetition target');
    }
  }

  @override
  Map<String, dynamic> toJson() {
    validate();
    return {'sets': sets, 'reps': repetitions, 'restSeconds': restSeconds};
  }
}

final class TimedPrescription extends ExercisePrescription {
  const TimedPrescription(
      {required super.sets,
      required this.durationSeconds,
      required super.restSeconds});
  final int durationSeconds;
  int get totalSeconds => sets * durationSeconds + (sets - 1) * restSeconds;
  @override
  void validate() {
    super.validate();
    if (durationSeconds < 1 || durationSeconds > 3600 || totalSeconds > 86400) {
      throw const FormatException('Invalid timed exercise duration');
    }
  }

  @override
  Map<String, dynamic> toJson() {
    validate();
    return {
      'sets': sets,
      'durationSeconds': durationSeconds,
      'restSeconds': restSeconds
    };
  }
}
