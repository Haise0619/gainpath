import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/chatbot.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import '../../features/chatbot/presentation/member/chatbot_screen.dart';
import '../../infrastructure/firebase/firebase_chat_repository.dart';
import 'local_member_progress_factory.dart';
import 'booking_factory.dart';
import 'package:gainpath_data/gainpath_data.dart';
import '../../features/chatbot/application/fitness_assistant_context.dart';
import '../../features/recommendation/application/member_recommendation_page_cache.dart';
import '../../features/recommendation/application/member_recommendation_repository.dart';
import '../../infrastructure/firebase/firebase_member_recommendations.dart';
import '../../infrastructure/firebase/firebase_demo_recommendation.dart';
import '../../infrastructure/firebase/firebase_fyp_dataset.dart';
import '../../infrastructure/firebase/firebase_fitness_profile_gateway.dart';
import '../../infrastructure/firebase/firebase_published_routine_repository.dart';
import '../../infrastructure/firebase/firebase_membership_repository.dart';
import '../../infrastructure/firebase/firebase_coach_directory_repository.dart';
import '../notifications/member_recommendation_navigator.dart';
import '../routing/member_workout_report_route.dart';
import '../routing/exercise_tutorial_route.dart';
import '../routing/routine_journey_route.dart';
import '../../features/membership/presentation/shared/membership_dashboard_screen.dart';
import 'coach_profile_factory.dart';

/// The route owns one account-bound repository; auth changes dispose its Bloc.
Widget buildMemberChatbot(AuthSession expected,
        {bool openSavedAdvice = false}) =>
    _MemberChatHost(expected: expected, openSavedAdvice: openSavedAdvice);

class _MemberChatHost extends StatefulWidget {
  const _MemberChatHost(
      {required this.expected, required this.openSavedAdvice});
  final AuthSession expected;
  final bool openSavedAdvice;
  @override
  State<_MemberChatHost> createState() => _MemberChatHostState();
}

class _MemberChatHostState extends State<_MemberChatHost> {
  bool _reviewing = false;
  FirebaseChatRepository? _repository;
  AuthBloc? _auth;
  FitnessAssistantContext? _facts;
  FirebasePublishedRoutineRepository? _catalog;
  MemberRecommendationNavigator? _recommendationNavigator;
  SessionScope? _active() => mounted &&
          _auth?.state.session?.scope == widget.expected.scope &&
          AuthRolePolicy.canEnter(_auth!.state, allowed: const {AppRole.member})
      ? widget.expected.scope
      : null;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _auth ??= context.read<AuthBloc>();
    if (_facts == null) {
      final scope = widget.expected.scope;
      bool current() => _active() == scope;
      _catalog = FirebasePublishedRoutineRepository(
          scope: scope, activeScope: _active);
      final scoped = scope.datasetScope == null
          ? null
          : FirebaseDemoMemberRepositories(
              firebaseFypDatasetTransport(scope, current));
      final canonical = scope.datasetScope == null
          ? FirebaseMemberRecommendations(scope: scope, isCurrent: current)
          : null;
      final recommendation =
          canonical?.recommendation ?? scoped!.recommendation;
      final cache = MemberRecommendationPageCache(
          canonical?.loadPage ?? scoped!.loadRecommendations, current);
      _recommendationNavigator = MemberRecommendationNavigator(
          session: widget.expected,
          repository: recommendation,
          isCurrent: current,
          coachDirectory: scoped?.directory ??
              FirebaseCoachDirectoryRepository(
                  scope: scope, isCurrent: current),
          catalog: _catalog!);
      _facts = FitnessAssistantContext(
          scope: scope,
          isCurrent: current,
          loadProgress: () async =>
              (await createLocalMemberProgressRepository(scope, _active))
                  .load(),
          loadProfile: FirebaseFitnessProfileRepository(
                  scope: scope,
                  gateway:
                      FlutterFitnessProfileGateway(isSessionCurrent: current))
              .load,
          loadRoutines: () async => (await _catalog!.loadPage()).items,
          loadRecommendations: () => cache.load(history: true),
          loadMembership:
              FirebaseMembershipRepository(scope: scope, isCurrent: current)
                  .load);
    }
    _repository ??= FirebaseChatRepository(
        scope: widget.expected.scope,
        activeScope: _active,
        contextualReply: _facts!.reply);
  }

  Future<void> _openFact(FitnessFactAction action) async {
    if (_active() != widget.expected.scope || _reviewing) return;
    _reviewing = true;
    try {
      Widget? page;
      switch (action.target) {
        case FitnessFactTarget.progress:
        case FitnessFactTarget.workoutReport:
          page = MemberWorkoutReportRoute(scope: widget.expected.scope);
        case FitnessFactTarget.membership:
          page = const MembershipDashboardScreen(connected: true);
        case FitnessFactTarget.coaches:
          page = buildFirebaseCoachDirectory(widget.expected);
        case FitnessFactTarget.recommendation:
          final detail = _facts!.recommendationTargets[action.id];
          if (detail == null) throw const MemberRecommendationUnavailable();
          await _recommendationNavigator!.open(context, detail);
        case FitnessFactTarget.tutorial:
          final key = action.id;
          if (key == null || !_facts!.tutorialTargets.containsKey(key)) {
            throw const MemberRecommendationUnavailable();
          }
          final segments = key.split(':');
          if (segments.length != 3) {
            throw const MemberRecommendationUnavailable();
          }
          final routine = await _catalog!.loadById(segments[0]);
          final index = int.tryParse(segments[2]);
          if (_active() != widget.expected.scope || !mounted) return;
          if (routine == null ||
              index == null ||
              index < 0 ||
              index >= routine.exercises.length) {
            throw const MemberRecommendationUnavailable();
          }
          final exercise = routine.exercises[index];
          if (exercise.exerciseId != _facts!.tutorialTargets[key]!.exerciseId ||
              exercise.dayNumber.toString() != segments[1]) {
            throw const MemberRecommendationUnavailable();
          }
          page = ExerciseTutorialRoute(
              scope: widget.expected.scope, exercise: exercise);
        case FitnessFactTarget.routine:
          if (!_facts!.routineTargets.containsKey(action.id)) {
            throw const MemberRecommendationUnavailable();
          }
          final routine = await _catalog!.loadById(action.id!);
          if (!mounted || _active() != widget.expected.scope) return;
          if (routine == null) throw const MemberRecommendationUnavailable();
          page = RoutineJourneyRoute(
              scope: widget.expected.scope, routine: routine);
      }
      if (page != null && mounted && _active() == widget.expected.scope) {
        await Navigator.push<void>(
            context, MaterialPageRoute(builder: (_) => page!));
      }
    } catch (_) {
      if (mounted && _active() == widget.expected.scope) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'This destination is unavailable. Refresh your records and try again.')));
      }
    } finally {
      _reviewing = false;
    }
  }

  @override
  Widget build(BuildContext context) =>
      RepositoryProvider<ChatRepository>.value(
          value: _repository!,
          child: BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) => _active() == widget.expected.scope
                  ? ChatbotScreen(
                      onOpenFact: _openFact,
                      onReviewBooking: (suggestion) async {
                        if (_active() != widget.expected.scope || _reviewing) {
                          return;
                        }
                        if (suggestion.expired) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  'This suggestion expired. Ask for current available times.')));
                          return;
                        }
                        _reviewing = true;
                        try {
                          await openMemberBooking(
                              context, widget.expected, suggestion.coachId,
                              suggestion: suggestion);
                        } finally {
                          _reviewing = false;
                        }
                      },
                      connected: true,
                      openSavedAdvice: widget.openSavedAdvice)
                  : const Scaffold(
                      body: Center(
                          child: Text('Sign in to reopen the assistant.')))));
}
