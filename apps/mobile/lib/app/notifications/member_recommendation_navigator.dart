import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show AuthSession, AppRole;
import '../../features/recommendation/application/member_recommendation_repository.dart';
import '../../features/workout/domain/published_routine_catalog_repository.dart';
import '../../features/workout/domain/published_routine_view.dart';
import '../../features/workout/domain/tutorial_player.dart';
import '../../features/workout/domain/tutorial_media.dart';
import '../../features/coaching/presentation/shared/live_coach_directory_views.dart';
import '../../features/coaching/presentation/shared/live_coach_schedule_view.dart';
import '../../navigation/session_host.dart';
import '../di/booking_factory.dart';
import '../di/coach_profile_factory.dart';
import '../routing/exercise_tutorial_route.dart';
import '../routing/routine_journey_route.dart';
import '../di/program_store_factory.dart';
import '../../features/workout/presentation/member/routine_screen.dart';
import '../../features/recommendation/application/published_recommendation_suggestion.dart';

/// Rechecks the server-owned recommendation and resolves complete current models.
/// Opening never reserves a slot or invokes the booking writer.
class MemberRecommendationNavigator {
  const MemberRecommendationNavigator(
      {required this.session,
      required this.repository,
      required this.isCurrent,
      required this.coachDirectory,
      required this.catalog,
      this.bookingFactory,
      this.bookingListFactory,
      this.availabilityFactory,
      this.bookingNavigationEnabled = true,
      this.tutorialPlayerFactory,
      this.loadPublishedCovers});
  final Future<Map<String, String>> Function(List<String>)? loadPublishedCovers;
  final AuthSession session;
  final MemberRecommendationRepository repository;
  final bool Function() isCurrent;
  final CoachDirectoryRepository coachDirectory;
  final PublishedRoutineCatalogRepository catalog;
  final BookingServicesFactory? bookingFactory;
  final BookingListFactory? bookingListFactory;
  final CoachAvailabilityFactory? availabilityFactory;
  final TutorialPlayerFactory? tutorialPlayerFactory;
  final bool bookingNavigationEnabled;
  Widget buildCoachPhoto(
          BuildContext context, MemberRecommendationDetail detail) =>
      _RecommendationCoachPhoto(
          detail: detail,
          directory: coachDirectory,
          isCurrent: () =>
              isCurrent() &&
              repository.isCurrent &&
              repository.scope == session.scope &&
              coachDirectory.scope == session.scope &&
              detail.organizationId == session.organizationId);
  void _check() {
    _checkPublic();
    if (!repository.isCurrent || repository.scope != session.scope) {
      throw const MemberRecommendationUnavailable();
    }
  }

  void _checkPublic() {
    if (!isCurrent() ||
        session.role != AppRole.member ||
        coachDirectory.scope != session.scope ||
        catalog.scope != session.scope) {
      throw const MemberRecommendationUnavailable();
    }
  }

  Future<PublishedRoutineExercise> resolveExercise(
      ContentRecommendationTarget target) async {
    _checkPublic();
    if (target.organizationId != session.organizationId) {
      throw const MemberRecommendationUnavailable();
    }
    final routine = await catalog.loadById(target.routineId);
    _checkPublic();
    if (routine == null ||
        routine.id != target.routineId ||
        target.exerciseIndex >= routine.exercises.length) {
      throw const MemberRecommendationUnavailable();
    }
    final exercise = routine.exercises[target.exerciseIndex];
    if (exercise.exerciseId != target.exerciseId ||
        exercise.dayNumber != target.dayNumber ||
        (exercise.tutorial.steps.isEmpty &&
            tutorialMediaUri(exercise.videoUrl) == null) ||
        exercise.tutorial.steps.any(
            (s) => s.title.trim().isEmpty || s.description.trim().isEmpty)) {
      throw const MemberRecommendationUnavailable();
    }
    return exercise;
  }

  Future<PublishedRoutine> resolveRoutine(
      RoutineRecommendationTarget target) async {
    _checkPublic();
    if (target.organizationId != session.organizationId) {
      throw const MemberRecommendationUnavailable();
    }
    final routine = await catalog.loadById(target.routineId);
    _checkPublic();
    if (routine == null ||
        routine.id != target.routineId ||
        routine.exercises.isEmpty) {
      throw const MemberRecommendationUnavailable();
    }
    return routine;
  }

  Future<List<PublishedRecommendationSuggestion>> loadDiscovery() async {
    _checkPublic();
    final page = await catalog.loadPage();
    _checkPublic();
    final routines = page.items.take(3).toList();
    final missing = routines
        .where((r) => r.coverImageUrl == null)
        .map((r) => r.id)
        .toList();
    Map<String, String> covers = {};
    if (missing.isNotEmpty && loadPublishedCovers != null) {
      try {
        covers = await loadPublishedCovers!(missing);
      } catch (_) {}
    }
    _checkPublic();
    final items = <PublishedRecommendationSuggestion>[];
    for (final routine in routines) {
      items.add(PublishedRecommendationSuggestion(
          kind: RecommendationKind.routine,
          target:
              RoutineRecommendationTarget(session.organizationId, routine.id),
          title: routine.title,
          difficulty: routine.difficulty,
          imageUrl: routine.coverImageUrl ?? covers[routine.id],
          exerciseCount: routine.exercises.length,
          durationMinutes: routine.estimatedMinutes));
      final index = routine.exercises.indexWhere((e) =>
          e.tutorial.steps.isNotEmpty || tutorialMediaUri(e.videoUrl) != null);
      if (index >= 0) {
        final exercise = routine.exercises[index];
        items.add(PublishedRecommendationSuggestion(
            kind: RecommendationKind.content,
            target: ContentRecommendationTarget(session.organizationId,
                routine.id, index, exercise.exerciseId, exercise.dayNumber),
            title: exercise.name,
            imageUrl: exercise.imageUrl,
            difficulty: exercise.tutorial.difficulty));
      }
    }
    return List.unmodifiable(items);
  }

  Future<void> openDiscovery(
      BuildContext context, PublishedRecommendationSuggestion item) async {
    _checkPublic();
    final target = item.target;
    if (target is RoutineRecommendationTarget) {
      await _openRoutine(context, await resolveRoutine(target));
    } else if (target is ContentRecommendationTarget) {
      final exercise = await resolveExercise(target);
      if (!context.mounted) return;
      await Navigator.push<void>(
          context,
          MaterialPageRoute(
              builder: (_) => tutorialPlayerFactory == null
                  ? ExerciseTutorialRoute(
                      scope: session.scope, exercise: exercise)
                  : ExerciseTutorialRoute(
                      scope: session.scope,
                      exercise: exercise,
                      playerFactory: tutorialPlayerFactory!)));
    } else {
      throw const MemberRecommendationUnavailable();
    }
  }

  Future<void> _openRoutine(
      BuildContext context, PublishedRoutine routine) async {
    _checkPublic();
    if (!context.mounted) return;
    await Navigator.push<void>(
        context,
        MaterialPageRoute(
            builder: (previewContext) => RoutineScreen(
                organizationId: session.organizationId,
                publishedRoutine: routine,
                tutorialBuilder: (_, exercise) => ExerciseTutorialRoute(
                    scope: session.scope, exercise: exercise),
                onStartWorkout: () async {
                  try {
                    final current = await resolveRoutine(
                        RoutineRecommendationTarget(
                            session.organizationId, routine.id));
                    if (!context.mounted || !previewContext.mounted) return;
                    final auth = context.read<AuthBloc>();
                    await Navigator.push<void>(
                        previewContext,
                        MaterialPageRoute(
                            builder: (_) => BlocProvider.value(
                                value: auth,
                                child: RoutineJourneyRoute(
                                    scope: session.scope,
                                    routine: current,
                                    programStoreFactory:
                                        createProgramEnrollmentStore))));
                  } catch (_) {
                    if (previewContext.mounted) {
                      ScaffoldMessenger.of(previewContext).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'This routine is currently unavailable. Refresh and try again.')));
                    }
                  }
                })));
  }

  Future<void> open(
      BuildContext context, MemberRecommendationDetail previous) async {
    _check();
    if (previous.organizationId != session.organizationId) {
      throw const MemberRecommendationUnavailable();
    }
    final detail = await repository.resolve(previous.recommendationId);
    _check();
    if (!context.mounted || !detail.available) {
      throw const MemberRecommendationUnavailable();
    }
    final target = detail.target;
    if (target is TrainerRecommendationTarget) {
      final coach = await coachDirectory.loadPublished(target.coachId);
      _check();
      if (!context.mounted ||
          coach == null ||
          !coach.isPublished ||
          !coach.certificationVerified ||
          !coach.branchIds.contains(target.branchId) ||
          !session.branchIds.contains(target.branchId)) {
        throw const MemberRecommendationUnavailable();
      }
      await Navigator.push<void>(
          context,
          MaterialPageRoute(
              builder: (_) => CoachSessionHost(
                  session: session,
                  builder: (routeContext, current) {
                    bool active() =>
                        current() && isCurrent() && repository.isCurrent;
                    return LiveCoachDetailView(
                        coachId: target.coachId,
                        repository: coachDirectory,
                        isCurrent: active,
                        onOpenBooking: () {
                          if (!bookingNavigationEnabled) {
                            ScaffoldMessenger.of(routeContext).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Booking is currently unavailable. Please contact the gym.')));
                            return;
                          }
                          if (active()) {
                            openMemberBooking(
                                routeContext, session, target.coachId,
                                factory: bookingFactory,
                                listFactory: bookingListFactory);
                          }
                        },
                        onOpenSchedule: availabilityFactory == null
                            ? null
                            : () {
                                if (!active()) return;
                                Navigator.push<void>(
                                    routeContext,
                                    MaterialPageRoute(
                                        builder: (_) => CoachSessionHost(
                                            session: session,
                                            builder: (scheduleContext,
                                                    scheduleCurrent) =>
                                                LiveCoachScheduleView(
                                                    coachId: target.coachId,
                                                    repository:
                                                        availabilityFactory!(
                                                            session.scope,
                                                            scheduleCurrent),
                                                    isCurrent: () =>
                                                        scheduleCurrent() &&
                                                        active(),
                                                    onOpenBooking: () {
                                                      if (scheduleCurrent() &&
                                                          active()) {
                                                        openMemberBooking(
                                                            scheduleContext,
                                                            session,
                                                            target.coachId,
                                                            factory:
                                                                bookingFactory,
                                                            listFactory:
                                                                bookingListFactory);
                                                      }
                                                    }))));
                              });
                  })));
    } else if (target is ContentRecommendationTarget) {
      final exercise = await resolveExercise(target);
      _check();
      if (!context.mounted) return;
      await Navigator.push<void>(
          context,
          MaterialPageRoute(
              builder: (_) => tutorialPlayerFactory == null
                  ? ExerciseTutorialRoute(
                      scope: session.scope, exercise: exercise)
                  : ExerciseTutorialRoute(
                      scope: session.scope,
                      exercise: exercise,
                      playerFactory: tutorialPlayerFactory!)));
    } else if (target is RoutineRecommendationTarget) {
      final routine = await resolveRoutine(target);
      _check();
      if (!context.mounted) return;
      await _openRoutine(context, routine);
    } else {
      throw const MemberRecommendationUnavailable();
    }
  }
}

/// Uses the existing private-photo callable through PublishedCoachPhoto. No
/// public Storage URL is constructed from a recommendation path.
class _RecommendationCoachPhoto extends StatefulWidget {
  const _RecommendationCoachPhoto(
      {required this.detail, required this.directory, required this.isCurrent});
  final MemberRecommendationDetail detail;
  final CoachDirectoryRepository directory;
  final bool Function() isCurrent;
  @override
  State<_RecommendationCoachPhoto> createState() =>
      _RecommendationCoachPhotoState();
}

class _RecommendationCoachPhotoState extends State<_RecommendationCoachPhoto> {
  Future<Uint8List?>? _bytes;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _RecommendationCoachPhoto old) {
    super.didUpdateWidget(old);
    if (old.detail.photoPath != widget.detail.photoPath ||
        old.detail.target != widget.detail.target) {
      _load();
    }
  }

  void _load() {
    final target = widget.detail.target, path = widget.detail.photoPath;
    _bytes = widget.isCurrent() &&
            widget.directory.scope.organizationId ==
                widget.detail.organizationId &&
            target is TrainerRecommendationTarget &&
            path != null
        ? loadPublishedCoachPhotoBytes(
            organizationId: widget.detail.organizationId,
            coachId: target.coachId,
            photoPath: path,
            isCurrent: widget.isCurrent)
        : null;
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final avatar =
            constraints.maxWidth <= 110 && constraints.maxHeight <= 110;
        final size = avatar && constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 96.0;
        Widget fallback() => Container(
            color: AppColors.primaryTint,
            alignment: Alignment.center,
            child: Icon(Icons.person_rounded,
                color: AppColors.primary, size: size * .5));
        return SizedBox(
            width: avatar ? size : double.infinity,
            height: avatar ? size : 144,
            child: ClipRRect(
                borderRadius: BorderRadius.circular(avatar ? size / 2 : 16),
                child: FutureBuilder<Uint8List?>(
                    future: _bytes,
                    builder: (context, snapshot) => widget.isCurrent() &&
                            snapshot.connectionState == ConnectionState.done &&
                            snapshot.data != null
                        ? Image.memory(snapshot.data!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => fallback())
                        : fallback())));
      });
}
