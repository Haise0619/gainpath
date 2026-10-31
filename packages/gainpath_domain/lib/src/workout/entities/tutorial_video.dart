import '../enums/tutorial_status.dart';
import '../exercise_tracking.dart';
import '../exercise_tutorial_details.dart';

/// Opaque immutable edit token supplied by a repository, never authored by UI.
abstract class TutorialEditBaseline {
  const TutorialEditBaseline();
}

/// AD-M11.4 — one video in the Exercise Tutorial Library.
/// [coversExercise] names which `riskExercises` entry (if any) this
/// tutorial actually addresses, empty string if none — that link is
/// what makes `contentGaps` real instead of guessed from title
/// text. Fields are mutable so the admin Edit form can update a video
/// in place.
class TutorialVideo {
  final String id;
  final bool archived;
  final TutorialEditBaseline? editBaseline;
  final ExerciseTrackingCapability trackingCapability;
  String title;
  String category;
  TutorialStatus status;
  ExerciseCatalogStatus get catalogStatus => archived
      ? ExerciseCatalogStatus.archived
      : status == TutorialStatus.active
          ? ExerciseCatalogStatus.active
          : ExerciseCatalogStatus.inactive;
  String coversExercise;
  String difficulty;
  int durationMin;
  String videoUrl;
  String thumbnailUrl;
  String description;
  String equipment;
  List<ExerciseTutorialStep> tutorialSteps;
  ExerciseTutorialDetails get tutorialDetails => ExerciseTutorialDetails(
      description: description,
      coverImageUrl: thumbnailUrl,
      difficulty: difficulty,
      equipment: equipment,
      steps: tutorialSteps);
  TutorialVideo({
    this.id = '',
    this.archived = false,
    this.editBaseline,
    this.trackingCapability = ExerciseTrackingCapability.guidedOnly,
    required this.title,
    required this.category,
    required this.status,
    this.coversExercise = '',
    this.difficulty = 'Beginner',
    this.durationMin = 5,
    this.videoUrl = '',
    this.thumbnailUrl = '',
    this.description = '',
    this.equipment = '',
    this.tutorialSteps = const [],
  });
}
