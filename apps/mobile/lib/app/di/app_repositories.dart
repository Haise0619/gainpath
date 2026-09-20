import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_data/gainpath_data.dart'
    show BackendConfig, BackendMode, MockDataSession;
import 'package:gainpath_data/analytics.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_data/chatbot.dart';
import 'package:gainpath_domain/chatbot.dart';
import 'package:gainpath_data/coaching.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_data/content.dart';
import 'package:gainpath_domain/content.dart';
import 'package:gainpath_data/gamification.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_data/identity.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_data/membership.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_data/recommendation.dart';
import 'package:gainpath_domain/recommendation.dart';
import 'package:gainpath_data/workout.dart';
import 'package:gainpath_domain/workout.dart';

/// Composition root for data access. Swap the in-memory implementations for
/// Firebase-backed ones here without touching any screen.
class AppRepositories extends StatefulWidget {
  const AppRepositories({
    super.key,
    required this.child,
    this.config = const BackendConfig(BackendMode.mock),
  });
  final Widget child;
  final BackendConfig config;

  @override
  State<AppRepositories> createState() => _AppRepositoriesState();
}

class _AppRepositoriesState extends State<AppRepositories> {
  final MockDataSession session = MockDataSession();

  @override
  Widget build(BuildContext context) {
    widget.config.validate();
    if (widget.config.isFirebase) {
      throw UnsupportedError(
        'Firebase backend adapters are not connected yet. '
        'Run with --dart-define=BACKEND=mock until Phase 7 adapters are enabled.',
      );
    }
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<MemberProfileRepository>(
            create: (_) => InMemoryMemberProfileRepository(session: session)),
        RepositoryProvider<CoachRepository>(
            create: (_) => InMemoryCoachRepository(session: session)),
        RepositoryProvider<UserAccountRepository>(
            create: (_) => InMemoryUserAccountRepository(session: session)),
        RepositoryProvider<WorkoutRepository>(
            create: (_) => InMemoryWorkoutRepository(session: session)),
        RepositoryProvider<EquipmentRepository>(
            create: (_) => InMemoryEquipmentRepository(session: session)),
        RepositoryProvider<TutorialRepository>(
            create: (_) => InMemoryTutorialRepository(session: session)),
        RepositoryProvider<RoutineTemplateRepository>(
            create: (_) => InMemoryRoutineTemplateRepository(session: session)),
        RepositoryProvider<GamificationRepository>(
            create: (_) => InMemoryGamificationRepository(session: session)),
        RepositoryProvider<BookingRepository>(
            create: (_) => InMemoryBookingRepository(session: session)),
        RepositoryProvider<AvailabilityRepository>(
            create: (_) => InMemoryAvailabilityRepository(session: session)),
        RepositoryProvider<MembershipRepository>(
            create: (_) => InMemoryMembershipRepository(session: session)),
        RepositoryProvider<ChatRepository>(
            create: (_) => InMemoryChatRepository(session: session)),
        RepositoryProvider<AnalyticsRepository>(
            create: (_) => InMemoryAnalyticsRepository(session: session)),
        RepositoryProvider<RecommendationRepository>(
            create: (_) => InMemoryRecommendationRepository(session: session)),
        RepositoryProvider<ContentRepository>(
            create: (_) => InMemoryContentRepository(session: session)),
      ],
      child: widget.child,
    );
  }
}
