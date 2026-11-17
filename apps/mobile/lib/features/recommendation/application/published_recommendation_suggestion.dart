import 'package:gainpath_domain/coaching.dart';

/// A real published catalog item for general discovery. It has no delivery,
/// recommendation identity, personal reason or member response state.
class PublishedRecommendationSuggestion {
  const PublishedRecommendationSuggestion({
    required this.kind,
    required this.target,
    required this.title,
    this.imageUrl,
    this.photoPath,
    this.difficulty,
    this.durationMinutes,
    this.exerciseCount,
    this.specialization,
    this.branchLabel,
    this.priceMinor,
    this.currency,
  });
  final RecommendationKind kind;
  final RecommendationTarget target;
  final String title;
  final String? imageUrl,
      photoPath,
      difficulty,
      specialization,
      branchLabel,
      currency;
  final int? durationMinutes, exerciseCount, priceMinor;
}

typedef PublishedRecommendationLoader
    = Future<List<PublishedRecommendationSuggestion>> Function();
