import 'package:gainpath/features/identity/domain/entities/coach_review.dart';

/// [bio], [specializationTags], and [fee] are mutable so a coach editing
/// their own professional profile (coach-side) updates the very same
/// object members browse in the directory — the "mutate MockData in
/// place" pattern already used for savedAdvice and Booking.
class Coach {
  final String id;
  final String name;
  final String specialty;
  List<String> specializationTags;
  final double rating;
  final int reviews;
  String bio;
  final bool verified;
  final String imageUrl;
  final String branch;
  double fee;
  final int yearsExperience;
  final int sessionsCompleted;
  final String responseTime;
  final List<CoachReview> topReviews;
  Coach({
    required this.id,
    required this.name,
    required this.specialty,
    required this.specializationTags,
    required this.rating,
    required this.reviews,
    required this.bio,
    required this.verified,
    required this.imageUrl,
    required this.branch,
    required this.fee,
    required this.yearsExperience,
    required this.sessionsCompleted,
    required this.responseTime,
    required this.topReviews,
  });
}
