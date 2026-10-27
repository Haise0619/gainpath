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
    required int reps,
    required String cue,
    required String imageUrl,
    required String muscleGroup,
    this.videoUrl,
    this.tutorial = const ExerciseTutorialDetails(),
  }) : super(name, category, sets, reps, cue, imageUrl, muscleGroup);

  final String exerciseId;
  final int dayNumber;
  final String? videoUrl;
  final ExerciseTutorialDetails tutorial;
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
  });

  final String id;
  final String sourceBlueprintId;
  final String title;
  final int estimatedMinutes;
  final List<PublishedRoutineExercise> exercises;
  final String? difficulty;

  static PublishedRoutine fromDocument(String id, Map<String, dynamic> data) {
    if (data['schemaVersion'] != 1 ||
        data['kind'] != 'routine' ||
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
          item['reps'] is! int ||
          (item['reps'] as int) <= 0) {
        throw const FormatException('Invalid routine exercise');
      }
      final day = item['dayNumber'] ?? 1;
      if (day is! int || day < 1) {
        throw const FormatException('Invalid routine day');
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
        dayNumber: day,
        videoUrl: tutorialMediaUri(item['videoUrl'])?.toString(),
        tutorial: tutorial,
        name: item['name'] as String,
        category: item['category'] is String ? item['category'] as String : '',
        sets: item['sets'] as int,
        reps: item['reps'] as int,
        cue: item['cue'] is String ? item['cue'] as String : '',
        imageUrl: tutorial.coverImageUrl.isNotEmpty
            ? tutorial.coverImageUrl
            : exerciseImageUri(item['imageUrl'])?.toString() ?? '',
        muscleGroup:
            item['muscleGroup'] is String ? item['muscleGroup'] as String : '',
      );
    }).toList(growable: false);
    return PublishedRoutine(
      id: id,
      sourceBlueprintId: data['sourceBlueprintId'] as String,
      title: (data['title'] as String).trim(),
      estimatedMinutes: data['estimatedMinutes'] as int,
      exercises: exercises,
      difficulty: data['difficulty'] as String?,
    );
  }
}
