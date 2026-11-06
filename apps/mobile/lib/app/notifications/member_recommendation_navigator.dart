import 'package:flutter/material.dart';
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
      this.tutorialPlayerFactory});
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
    if (!isCurrent() ||
        !repository.isCurrent ||
        session.role != AppRole.member ||
        repository.scope != session.scope ||
        coachDirectory.scope != session.scope ||
        catalog.scope != session.scope) {
      throw const MemberRecommendationUnavailable();
    }
  }

  Future<PublishedRoutineExercise> resolveExercise(
      ContentRecommendationTarget target) async {
    _check();
    if (target.organizationId != session.organizationId) {
      throw const MemberRecommendationUnavailable();
    }
    final routine = await catalog.loadById(target.routineId);
    _check();
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
                                const SnackBar(content: Text('Booking and payment are outside this controlled demonstration.')));
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
  late final Future<PublishedCoachProfile?> _profile = _load();
  Future<PublishedCoachProfile?> _load() async {
    final target = widget.detail.target;
    if (!widget.isCurrent() ||
        target is! TrainerRecommendationTarget ||
        widget.directory.scope.organizationId != widget.detail.organizationId) {
      return null;
    }
    return widget.directory.loadPublished(target.coachId);
  }

  @override
  Widget build(BuildContext context) => Container(
      height: 144,
      width: double.infinity,
      decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(16)),
      alignment: Alignment.center,
      child: FutureBuilder<PublishedCoachProfile?>(
          future: _profile,
          builder: (context, snapshot) {
            final profile = snapshot.data;
            final target = widget.detail.target;
            final valid = widget.isCurrent() &&
                target is TrainerRecommendationTarget &&
                profile != null &&
                profile.id == target.coachId &&
                profile.isPublished &&
                profile.certificationVerified &&
                profile.branchIds.contains(target.branchId) &&
                profile.fields.photoPath == widget.detail.photoPath &&
                profile.fields.photoPath != null &&
                profile.fields.photoPath!.startsWith(
                    'orgs/${widget.detail.organizationId}/coachProfilePhotos/${target.coachId}/');
            return valid
                ? PublishedCoachPhoto(
                    coach: profile,
                    repository: widget.directory,
                    isCurrent: widget.isCurrent,
                    size: 120)
                : const Icon(Icons.person_outline_rounded,
                    size: 48, color: AppColors.primary);
          }));
}
