import '../analytics/in_memory/analytics_seed.dart';
import '../chatbot/in_memory/chatbot_seed.dart';
import '../coaching/in_memory/coaching_seed.dart';
import '../content/in_memory/content_seed.dart';
import '../gamification/in_memory/gamification_seed.dart';
import '../identity/in_memory/identity_seed.dart';
import '../membership/in_memory/membership_seed.dart';
import '../recommendation/in_memory/recommendation_seed.dart';
import '../workout/in_memory/workout_seed.dart';

/// Owns one independent graph of mutable prototype data.
///
/// The composition root creates one session per user/organization scope and
/// explicitly injects it into repositories that should see the same changes.
/// Create a new session when changing scopes to start with fresh seed data.
/// Repositories constructed without a session each create their own graph.
class MockDataSession {
  MockDataSession();

  final IdentitySeed identity = IdentitySeed();
  final AnalyticsSeed analytics = AnalyticsSeed();
  final WorkoutSeed workout = WorkoutSeed();
  final ContentSeed content = ContentSeed();
  final GamificationSeed gamification = GamificationSeed();
  final MembershipSeed membership = MembershipSeed();

  late final CoachingSeed coaching = CoachingSeed(identity: identity);
  late final RecommendationSeed recommendation =
      RecommendationSeed(workout: workout);
  late final ChatbotSeed chatbot =
      ChatbotSeed(analytics: analytics, workout: workout);
}
