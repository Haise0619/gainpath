import 'package:gainpath/features/workout/domain/enums/tutorial_status.dart';

/// AD-M11.4 — one video in the Exercise Tutorial Library.
/// [coversExercise] names which `riskExercises` entry (if any) this
/// tutorial actually addresses, empty string if none — that link is
/// what makes `context.read<RecommendationRepository>().contentGaps` real instead of guessed from title
/// text. Fields are mutable so the admin Edit form can update a video
/// in place.
class TutorialVideo {
  String title;
  String category;
  TutorialStatus status;
  String coversExercise;
  String difficulty;
  int durationMin;
  String videoUrl;
  String thumbnailUrl;
  String description;
  TutorialVideo({
    required this.title,
    required this.category,
    required this.status,
    this.coversExercise = '',
    this.difficulty = 'Beginner',
    this.durationMin = 5,
    this.videoUrl = '',
    this.thumbnailUrl = '',
    this.description = '',
  });
}
