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
import 'package:gainpath_domain/gainpath_domain.dart'
    show AuthSession, SessionScope;
import '../../infrastructure/firebase/firebase_exercise_catalog_repository.dart';
import '../../infrastructure/firebase/firebase_routine_template_repository.dart';
import '../../infrastructure/firebase/firebase_coach_profile_admin_repository.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'catalog_edit_session_guard.dart';

/// Composition root for data access. Swap the in-memory implementations for
/// Firebase-backed ones here without touching any screen.
class AppRepositories extends StatefulWidget {
  const AppRepositories({
    super.key,
    required this.child,
    this.config = const BackendConfig(BackendMode.mock),
    this.session,
    this.tutorialRepositoryFactory,
    this.routineRepositoryFactory,
    this.coachRepositoryFactory,
  });
  final Widget child;
  final BackendConfig config;
  final AuthSession? session;
  final TutorialRepository Function(SessionScope)? tutorialRepositoryFactory;
  final RoutineTemplateRepository Function(SessionScope, TutorialRepository)?
      routineRepositoryFactory;
  final CoachProfileAdminRepository Function(SessionScope, bool Function())?
      coachRepositoryFactory;

  @override
  State<AppRepositories> createState() => _AppRepositoriesState();
}

class _AppRepositoriesState extends State<AppRepositories> {
  late final MockDataSession session = MockDataSession();
  CatalogEditSessionGuard? _catalogGuard;
  CatalogEditSessionGuard? _coachGuard;
  CoachProfileAdminRepository _createCoachDirectory(SessionScope scope) {
    final auth = context.read<AuthBloc>();
    _coachGuard = CatalogEditSessionGuard(
        expected: widget.session!,
        current: () => auth.state,
        changes: auth.stream);
    return widget.coachRepositoryFactory?.call(scope, _coachGuard!.isCurrent) ??
        FirebaseCoachProfileAdminRepository(
            scope: scope, isCurrent: _coachGuard!.isCurrent);
  }

  TutorialRepository _createCatalog(SessionScope scope) {
    final factory = widget.tutorialRepositoryFactory;
    if (factory != null) return factory(scope);
    final auth = context.read<AuthBloc>();
    _catalogGuard = CatalogEditSessionGuard(
        expected: widget.session!,
        current: () => auth.state,
        changes: auth.stream);
    return FirebaseExerciseCatalogRepository(
        scope: scope, isSessionCurrent: _catalogGuard!.isCurrent);
  }

  @override
  void dispose() {
    _catalogGuard?.dispose();
    _coachGuard?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widget.config.validate();
    if (widget.config.isFirebase && widget.session == null) return widget.child;
    final scope = widget.session?.scope;
    if (widget.config.isFirebase) {
      return MultiRepositoryProvider(providers: [
        RepositoryProvider<CoachProfileAdminRepository>(
            create: (_) => _createCoachDirectory(scope!)),
        RepositoryProvider<TutorialRepository>(
            create: (_) => _createCatalog(scope!)),
        RepositoryProvider<RoutineTemplateRepository>(
            create: (context) =>
                widget.routineRepositoryFactory
                    ?.call(scope!, context.read<TutorialRepository>()) ??
                FirebaseRoutineTemplateRepository(
                    scope: scope!,
                    exerciseCatalog: context.read<TutorialRepository>())),
      ], child: widget.child);
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
            create: (_) => widget.config.isFirebase
                ? FirebaseExerciseCatalogRepository(scope: scope!)
                : InMemoryTutorialRepository(session: session)),
        RepositoryProvider<RoutineTemplateRepository>(
            create: (context) => widget.config.isFirebase
                ? FirebaseRoutineTemplateRepository(
                    scope: scope!,
                    exerciseCatalog: context.read<TutorialRepository>())
                : InMemoryRoutineTemplateRepository(session: session)),
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
