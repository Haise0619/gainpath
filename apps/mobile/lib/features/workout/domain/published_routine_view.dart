import 'package:gainpath_domain/workout.dart';
import 'tutorial_media.dart';

/// Identity and target data retained from a published row, with the existing
/// Exercise display API so member Workout components keep their layout.
class PublishedRoutineExercise extends Exercise {
  const PublishedRoutineExercise({
    required this.exerciseId,
    required this.dayNumber,
    required String name,
    required String category,
    required int sets,
    required int? reps,
    required String cue,
    required String imageUrl,
    required String muscleGroup,
    this.videoUrl,
    this.restSeconds = 60,
    this.tutorial = const ExerciseTutorialDetails(),
    this.entryId = '',
    this.executionMode,
    this.durationSeconds,
    this.mediaRevision,
    this.mediaGeneration,
    this.mediaValidation,
  }) : super(name, category, sets, reps, cue, imageUrl, muscleGroup);

  final String exerciseId;
  final int dayNumber;
  final int restSeconds;
  final String? videoUrl;
  final ExerciseTutorialDetails tutorial;
  final String entryId;
  final ExerciseExecutionMode? executionMode;
  final int? durationSeconds;
  final int? mediaRevision;
  final String? mediaGeneration;
  final Map<String, dynamic>? mediaValidation;
  RepetitionPrescription get repetitionTarget {
    if (durationSeconds != null ||
        reps == null ||
        executionMode == ExerciseExecutionMode.videoGuidedTimed) {
      throw StateError('A measured workout requires a repetition prescription');
    }
    final target = RepetitionPrescription(
        sets: sets, repetitions: reps!, restSeconds: restSeconds);
    target.validate();
    return target;
  }

  ExercisePrescription get prescription => durationSeconds != null
      ? TimedPrescription(
          sets: sets,
          durationSeconds: durationSeconds!,
          restSeconds: restSeconds)
      : RepetitionPrescription(
          sets: sets,
          repetitions: reps ??
              (throw const FormatException('Missing repetition target')),
          restSeconds: restSeconds);
}

/// Published organization content, never a member assignment or session.
class PublishedRoutine {
  const PublishedRoutine({
    required this.id,
    required this.sourceBlueprintId,
    required this.title,
    required this.estimatedMinutes,
    required this.exercises,
    this.difficulty,
    this.schemaVersion = 1,
  });

  final String id;
  final String sourceBlueprintId;
  final String title;
  final int estimatedMinutes;
  final List<PublishedRoutineExercise> exercises;
  final String? difficulty;
  final int schemaVersion;

  static PublishedRoutine fromDocument(String id, Map<String, dynamic> data) {
    final version = data['schemaVersion'];
    if (!(version == 1 && data['kind'] == 'routine' ||
            version == 2 && data['kind'] == 'routine_v2') ||
        data['status'] != 'published' ||
        data['sourceBlueprintId'] is! String ||
        (data['sourceBlueprintId'] as String).trim().isEmpty ||
        data['title'] is! String ||
        (data['title'] as String).trim().isEmpty ||
        data['estimatedMinutes'] is! int ||
        (data['estimatedMinutes'] as int) <= 0 ||
        data['exercises'] is! List ||
        (data['difficulty'] != null &&
            !['Beginner', 'Intermediate', 'Advanced']
                .contains(data['difficulty']))) {
      throw const FormatException('Invalid published routine');
    }
    final raw = data['exercises'] as List;
    if (raw.isEmpty || raw.length > 50) {
      throw const FormatException('Invalid routine exercises');
    }
    final exercises = raw.map((item) {
      if (item is! Map<String, dynamic> ||
          item['exerciseId'] is! String ||
          (item['exerciseId'] as String).trim().isEmpty ||
          item['name'] is! String ||
          (item['name'] as String).trim().isEmpty ||
          item['sets'] is! int ||
          (item['sets'] as int) <= 0 ||
          (version == 1 &&
              (item['reps'] is! int || (item['reps'] as int) <= 0))) {
        throw const FormatException('Invalid routine exercise');
      }
      final day = item['dayNumber'] ?? 1;
      final rest = item['restSeconds'] ?? 60;
      if (rest is! int || rest < 0 || rest > 600) {
        throw const FormatException('Invalid exercise rest target');
      }
      if (day is! int || day < 1) {
        throw const FormatException('Invalid routine day');
      }
      ExerciseExecutionMode? mode;
      if (version == 2) {
        mode = ExerciseExecutionMode.fromJson(item['executionMode']);
        if (item['entryId'] is! String ||
            (item['entryId'] as String).trim().isEmpty) {
          throw const FormatException('Missing stable routine entry identity');
        }
        final target = ExercisePrescription.fromJson(item);
        if ((mode == ExerciseExecutionMode.videoGuidedTimed) !=
            (target is TimedPrescription)) {
          throw const FormatException(
              'Execution mode conflicts with exercise target');
        }
      }
      ExerciseTutorialDetails tutorial;
      try {
        tutorial =
            ExerciseTutorialDetails.fromJson(item, tolerateInvalidImages: true);
      } on FormatException {
        tutorial = const ExerciseTutorialDetails();
      }
      return PublishedRoutineExercise(
        exerciseId: item['exerciseId'] as String,
        entryId: version == 2 ? item['entryId'] as String : '',
        executionMode: mode,
        durationSeconds: version == 2 ? item['durationSeconds'] as int? : null,
        mediaRevision: version == 2
            ? (item['mediaRevision'] ??
                (item['mediaValidation'] as Map?)?['sourceRevision']) as int?
            : null,
        mediaGeneration: version == 2
            ? (item['mediaGeneration'] ??
                (item['mediaValidation'] as Map?)?['generation']) as String?
            : null,
        mediaValidation: item['mediaValidation'] is Map
            ? Map<String, dynamic>.unmodifiable(
                Map<String, dynamic>.from(item['mediaValidation'] as Map))
            : null,
        dayNumber: day,
        restSeconds: rest,
        videoUrl: tutorialMediaUri(item['videoUrl'])?.toString(),
        tutorial: tutorial,
        name: item['name'] as String,
        category: item['category'] is String ? item['category'] as String : '',
        sets: item['sets'] as int,
        reps: item['reps'] as int?,
        cue: item['cue'] is String ? item['cue'] as String : '',
        imageUrl: tutorial.coverImageUrl.isNotEmpty
            ? tutorial.coverImageUrl
            : exerciseImageUri(item['imageUrl'])?.toString() ?? '',
        muscleGroup:
            item['muscleGroup'] is String ? item['muscleGroup'] as String : '',
      );
    }).toList(growable: false);
    if (version == 2 &&
        exercises.map((e) => e.entryId).toSet().length != exercises.length) {
      throw const FormatException('Duplicate routine entry identity');
    }
    return PublishedRoutine(
      id: id,
      sourceBlueprintId: data['sourceBlueprintId'] as String,
      title: (data['title'] as String).trim(),
      estimatedMinutes: data['estimatedMinutes'] as int,
      exercises: exercises,
      difficulty: data['difficulty'] as String?,
      schemaVersion: version as int,
    );
  }
}
