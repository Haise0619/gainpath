import 'dart:async';
import '../../../../app/di/workout_preferences_factory.dart';
import '../../application/workout_preferences_controller.dart';
import 'workout_privacy_settings_screen.dart';
import '../../domain/exercise_tracker_dispatcher.dart';
import '../../domain/published_routine_view.dart';
import '../../application/workout_hub_program.dart';
import '../../application/workout_hub_attempt.dart';
import '../workout_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_domain/workout.dart';
import 'equipment_scanner_screen.dart';
import 'camera_setup_screen.dart';
import 'exercise_tutorial_screen.dart';
import '../../../../navigation/workout_navigation.dart';
import 'routine_screen.dart';
import 'widgets/workout_exercise_image.dart';

class WorkoutPrepScreen extends StatelessWidget {
  const WorkoutPrepScreen(
      {super.key,
      this.live = false,
      this.publishedRoutine,
      this.routineLoadFailed = false,
      this.routineStatusMessage,
      this.routineCatalogControls,
      this.onOpenEquipment,
      this.onOpenPrograms,
      this.onOpenSettings,
      this.scheduledWorkout,
      this.freeAttempt,
      this.onStartFree,
      this.recoveryDayLabel,
      this.onStartScheduled,
      this.programLoading = false,
      this.programLoadError = false,
      this.organizationId,
      this.trackers = const ExerciseTrackerDispatcher(),
      this.preferencesFactory = createWorkoutPreferences,
      this.routes = const WorkoutPrepRoutes()});
  final bool live;
  final WorkoutPreferencesFactory preferencesFactory;
  final PublishedRoutine? publishedRoutine;
  final bool routineLoadFailed;
  final String? routineStatusMessage;
  final Widget? routineCatalogControls;
  final VoidCallback? onOpenEquipment;
  final VoidCallback? onOpenPrograms;
  final VoidCallback? onOpenSettings;
  final ScheduledWorkoutPreview? scheduledWorkout;
  final WorkoutHubAttempt? freeAttempt;
  final VoidCallback? onStartFree;
  final String? recoveryDayLabel;
  final VoidCallback? onStartScheduled;
  final bool programLoading, programLoadError;
  final String? organizationId;
  final WorkoutPrepRoutes routes;
  final ExerciseTrackerDispatcher trackers;

  @override
  Widget build(BuildContext context) {
    final selectedRoutine = scheduledWorkout?.routine ?? publishedRoutine;
    String? savedStatus(Exercise row) {
      final attempt = scheduledWorkout?.attempt ?? freeAttempt?.attempt;
      final index = row is PublishedRoutineExercise
          ? selectedRoutine?.exercises.indexOf(row) ?? -1
          : -1;
      if (attempt == null || index < 0) return null;
      final result = attempt.entries.where((e) => e.index == index).firstOrNull;
      return result == null ? null : exerciseStatusLabel(result.status);
    }

    final routine = live
        ? selectedRoutine?.exercises
                .where((e) =>
                    scheduledWorkout == null ||
                    e.dayNumber == scheduledWorkout!.day)
                .toList() ??
            <PublishedRoutineExercise>[]
        : context.read<WorkoutRepository>().routine;
    final totalSets = routine.fold<int>(0, (sum, e) => sum + e.sets);
    final hasWorkout = !programLoading &&
        routine.isNotEmpty &&
        (!live || selectedRoutine != null);
    final title = live ? selectedRoutine?.title : 'Lower Body Strength';
    final isMultiDay = selectedRoutine != null &&
        selectedRoutine.exercises.map((e) => e.dayNumber).toSet().length > 1;
    final int? duration = live
        ? scheduledWorkout != null && isMultiDay
            ? null
            : selectedRoutine?.estimatedMinutes
        : 45;
    final multipleDays = live && scheduledWorkout == null && isMultiDay;

    void openExercise(int index) {
      if (live) {
        final builder = routes.tutorialBuilder;
        if (builder == null) {
          showUnavailable(context);
          return;
        }
        final exercise = routine[index] as PublishedRoutineExercise;
        Navigator.push(context,
            MaterialPageRoute(builder: (ctx) => builder(ctx, exercise)));
      } else {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    ExerciseTutorialScreen(exercise: routine[index])));
      }
    }

    void openRoutine() {
      final display = selectedRoutine == null
          ? null
          : PublishedRoutine(
              id: selectedRoutine.id,
              sourceBlueprintId: selectedRoutine.sourceBlueprintId,
              title: selectedRoutine.title,
              schemaVersion: selectedRoutine.schemaVersion,
              betweenExerciseRestSeconds:
                  selectedRoutine.betweenExerciseRestSeconds,
              estimatedMinutes: selectedRoutine.estimatedMinutes,
              exercises: routine.cast<PublishedRoutineExercise>(),
              difficulty: selectedRoutine.difficulty,
            );
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => live
                  ? RoutineScreen(
                      organizationId: organizationId ?? '',
                      publishedRoutine: display,
                      tutorialBuilder: routes.tutorialBuilder)
                  : const RoutineScreen()));
    }

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          title: const Text('Workout'),
          actions: [
            if (onOpenSettings != null)
              IconButton(
                  tooltip: 'Workout settings',
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.settings_outlined))
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          sliver: SliverList.list(children: [
            if (recoveryDayLabel != null) ...[
              Panel(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(recoveryDayLabel!,
                        style: Theme.of(context).textTheme.titleLarge),
                    const Text(
                        'Follow your planned recovery. Your next workout is shown below.'),
                    if (!hasWorkout)
                      FilledButton(
                          onPressed: onOpenPrograms,
                          child: const Text('View training schedule')),
                  ])),
              const SizedBox(height: 12),
            ],
            if (programLoading) ...[
              const Panel(
                  child: Row(children: [
                SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 12),
                Expanded(child: Text('Loading your workout…')),
              ])),
            ] else if (hasWorkout) ...[
              _WorkoutOverview(
                title: title!,
                exerciseCount: routine.length,
                totalSets: totalSets,
                minutes: duration,
                scheduledWorkout: scheduledWorkout,
                actionLabelOverride:
                    recoveryDayLabel != null && onOpenPrograms != null
                        ? 'View Training Schedule'
                        : null,
                freeAttempt: freeAttempt,
                switcher: routineCatalogControls,
                onStart: recoveryDayLabel != null && onOpenPrograms != null
                    ? onOpenPrograms!
                    : scheduledWorkout != null
                        ? onStartScheduled ?? () => showUnavailable(context)
                        : live
                            ? onStartFree ?? () => _startRealSession(context)
                            : () => _startSession(context),
                journeyFirst: live && routes.journeyBuilder != null,
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                    child: Text('Exercises in this workout',
                        style: Theme.of(context).textTheme.titleLarge)),
                TextButton(
                    onPressed: openRoutine, child: const Text('View routine')),
              ]),
              const SizedBox(height: 8),
              for (var i = 0; i < routine.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _WorkoutExerciseRow(
                    index: i + 1,
                    exercise: routine[i],
                    statusLabel: savedStatus(routine[i]),
                    day: multipleDays
                        ? (routine[i] as PublishedRoutineExercise).dayNumber
                        : null,
                    tracker: routine[i] is PublishedRoutineExercise &&
                            organizationId != null
                        ? trackers
                            .resolve(
                                organizationId: organizationId!,
                                exerciseId:
                                    (routine[i] as PublishedRoutineExercise)
                                        .exerciseId)
                            .tracker
                        : null,
                    organizationId: organizationId,
                    trackers: trackers,
                    onTap: () => openExercise(i),
                  ),
                ),
            ] else if (routineCatalogControls != null) ...[
              routineCatalogControls!,
            ] else ...[
              Panel(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(routineStatusMessage ?? 'No workout selected',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                        routineLoadFailed
                            ? 'Check your connection and refresh to try again.'
                            : 'When a workout is available, select it to see its exercises and start.',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ])),
            ],
            if (programLoadError) ...[
              const SizedBox(height: 12),
              const Text(
                  'Could not load your training plan. Open My training plan to retry.',
                  style: TextStyle(color: AppColors.inkSoft)),
            ],
            const SizedBox(height: 24),
            Text('Workout tools',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (onOpenPrograms != null) ...[
              const SizedBox(height: 8),
              _DetourCard(
                  icon: Icons.calendar_month_outlined,
                  iconColor: AppColors.primary,
                  title: 'My training plan',
                  subtitle: 'View your schedule and saved progress',
                  onTap: onOpenPrograms),
            ],
            _DetourCard(
              icon: Icons.videocam_outlined,
              iconColor: AppColors.primary,
              title: 'Review camera setup',
              subtitle: 'Check your distance and camera angle',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CameraSetupScreen())),
            ),
            const SizedBox(height: 8),
            _DetourCard(
              icon: Icons.qr_code_scanner_rounded,
              iconColor: AppColors.primary,
              title: 'Scan equipment',
              subtitle: 'Find instructions and safety tips',
              onTap: live
                  ? onOpenEquipment ?? () => showUnavailable(context)
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const EquipmentScannerScreen())),
            ),
            if (live) ...[
              const SizedBox(height: 8),
              _DetourCard(
                  icon: Icons.history_rounded,
                  iconColor: AppColors.primary,
                  title: 'Saved workout sessions',
                  subtitle: 'Review your saved workout results',
                  onTap: () {
                    final auth = context.read<AuthBloc>();
                    final scope = auth.state.session?.scope;
                    if (scope == null) return;
                    final destination = routes.savedSessionsBuilder;
                    if (destination == null) {
                      showUnavailable(context);
                      return;
                    }
                    Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => BlocProvider.value(
                                value: auth,
                                child: Builder(
                                    builder: (context) =>
                                        destination(context, scope)))));
                  }),
            ],
            if (const bool.fromEnvironment('GAINPATH_POSE_PREVIEW'))
              TextButton(
                  onPressed: () => _startPosePreview(context),
                  child: const Text('Try live camera preview')),
          ]),
        ),
      ]),
    );
  }

  Future<void> _startSession(BuildContext context) async {
    // UC-2.5 — biometric consent gate on first camera use.
    final consented = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _ConsentSheet(),
    );
    if (consented == true && context.mounted) {
      Navigator.pushNamed(context, WorkoutNavigation.guided);
    }
  }

  Future<void> _startRealSession(BuildContext context) async {
    final lease = _CaptureLaunchLease(context);
    try {
      await _startRealSessionWithLease(context, lease);
    } finally {
      lease.dispose();
    }
  }

  Future<void> _startRealSessionWithLease(
      BuildContext context, _CaptureLaunchLease lease) async {
    if (routes.journeyBuilder != null) {
      _openRoutineJourney(context);
      return;
    }
    final auth = context.read<AuthBloc>();
    final scope = auth.state.session?.scope;
    if (scope == null) {
      showUnavailable(context);
      return;
    }
    final candidates = publishedRoutine?.exercises
            .where((e) =>
                trackers
                    .resolve(
                        organizationId: scope.organizationId,
                        exerciseId: e.exerciseId)
                    .tracker !=
                null)
            .toList() ??
        [];
    if (candidates.isEmpty) {
      final exercises = publishedRoutine?.exercises;
      final tutorial = routes.tutorialBuilder;
      if (exercises != null && exercises.isNotEmpty && tutorial != null) {
        await Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (context) => BlocProvider.value(
                value: auth,
                child: Builder(
                    builder: (context) => tutorial(context, exercises.first)),
              ),
            ));
        return;
      }
      showUnavailable(context);
      return;
    }
    final exercise = candidates.first;
    WorkoutPreferencesController preferences;
    try {
      preferences = await preferencesFactory(scope);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Workout preferences are unavailable. Try again.')));
      }
      return;
    }
    if (!lease.current || auth.state.session?.scope != scope) return;
    var uploadRequested = false;
    final tracker = trackers
        .resolve(
            organizationId: scope.organizationId,
            exerciseId: exercise.exerciseId)
        .tracker;
    final consented = await showWorkoutCaptureConsent(context,
        preferences: preferences,
        allowUpload: tracker == ExerciseTracker.sideViewSquat,
        exerciseInstruction: switch (tracker) {
          ExerciseTracker.frontViewLateralRaise =>
            lateralRaiseCaptureInstruction,
          ExerciseTracker.frontViewShoulderPress =>
            shoulderPressCaptureInstruction,
          ExerciseTracker.sideViewCurl => curlCaptureInstruction,
          ExerciseTracker.sideViewRow => rowCaptureInstruction,
          ExerciseTracker.sideViewReverseLunge =>
            reverseLungeCaptureInstruction,
          ExerciseTracker.sideViewCalfRaise => calfRaiseCaptureInstruction,
          ExerciseTracker.sideViewWallPushUp => wallPushUpCaptureInstruction,
          ExerciseTracker.sideViewFloorPushUp => floorPushUpCaptureInstruction,
          _ => null,
        },
        setupConfirmationLabel: tracker == ExerciseTracker.sideViewFloorPushUp
            ? floorPushUpSetupConfirmation
            : tracker == ExerciseTracker.sideViewWallPushUp
                ? wallPushUpSetupConfirmation
                : tracker == ExerciseTracker.frontViewLateralRaise
                    ? lateralRaiseSetupConfirmation
                    : tracker == ExerciseTracker.frontViewShoulderPress
                        ? shoulderPressSetupConfirmation
                        : tracker == ExerciseTracker.sideViewRow
                            ? rowSetupConfirmation
                            : tracker == ExerciseTracker.sideViewReverseLunge
                                ? reverseLungeSetupConfirmation
                                : null,
        onUploadChanged: (value) => uploadRequested = value);
    if (consented != true ||
        !lease.current ||
        auth.state.session?.scope != scope) {
      return;
    }
    final destination = routes.realSessionBuilder;
    if (destination == null) {
      showUnavailable(context);
      return;
    }
    final launch = RealWorkoutLaunch(
        scope: scope,
        routineId: publishedRoutine!.id,
        exercise: exercise,
        consented: true,
        consentCurrent: () => preferences.validConsent,
        requestServerUpload: uploadRequested,
        setupConfirmed: true);
    Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => BlocProvider.value(
                value: auth,
                child: Builder(
                    builder: (context) => destination(context, launch)))));
  }

  void _openRoutineJourney(BuildContext context) {
    final routine = publishedRoutine, destination = routes.journeyBuilder;
    if (routine == null || destination == null) {
      showUnavailable(context);
      return;
    }
    final auth = context.read<AuthBloc>();
    if (auth.state.session == null) {
      showUnavailable(context);
      return;
    }
    Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => BlocProvider.value(
                value: auth,
                child: Builder(
                    builder: (context) => destination(context, routine)))));
  }

  Future<void> _startPosePreview(BuildContext context) async {
    final consented = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const _ConsentSheet(previewOnly: true));
    if (consented == true && context.mounted) {
      final destination = routes.posePreviewBuilder;
      if (destination == null) {
        showUnavailable(context);
        return;
      }
      final auth = context.read<AuthBloc>();
      Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (_) => BlocProvider.value(
                  value: auth, child: Builder(builder: destination))));
    }
  }
}

/// A camera launch begun in the foreground cannot survive an interruption.
class _CaptureLaunchLease with WidgetsBindingObserver {
  _CaptureLaunchLease(this.context) {
    final state = WidgetsBinding.instance.lifecycleState;
    _interrupted = state != null && state != AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }
  final BuildContext context;
  bool _interrupted = false;
  bool get current =>
      !_interrupted &&
      context.mounted &&
      ModalRoute.of(context)?.isCurrent == true;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _interrupted = true;
  }

  void dispose() => WidgetsBinding.instance.removeObserver(this);
}

class _WorkoutOverview extends StatelessWidget {
  const _WorkoutOverview(
      {required this.title,
      required this.exerciseCount,
      required this.totalSets,
      required this.minutes,
      this.scheduledWorkout,
      this.freeAttempt,
      this.actionLabelOverride,
      required this.onStart,
      required this.journeyFirst,
      this.switcher});
  final String title;
  final int exerciseCount, totalSets;
  final int? minutes;
  final ScheduledWorkoutPreview? scheduledWorkout;
  final WorkoutHubAttempt? freeAttempt;
  final String? actionLabelOverride;
  final VoidCallback onStart;
  final bool journeyFirst;
  final Widget? switcher;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(children: [
          const Positioned.fill(child: ColoredBox(color: AppColors.primary)),
          const Positioned.fill(
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x66200C35), Color(0xE510081D)],
                          stops: [0, 1])))),
          Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                              scheduledWorkout == null
                                  ? 'FREE WORKOUT'
                                  : 'YOUR PROGRAM · ${scheduledWorkout!.date.day} ${const [
                                      'JAN',
                                      'FEB',
                                      'MAR',
                                      'APR',
                                      'MAY',
                                      'JUN',
                                      'JUL',
                                      'AUG',
                                      'SEP',
                                      'OCT',
                                      'NOV',
                                      'DEC'
                                    ][scheduledWorkout!.date.month - 1]}',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: .7)),
                          if (switcher != null) switcher!,
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                        '$exerciseCount ${exerciseCount == 1 ? 'exercise' : 'exercises'} · $totalSets ${totalSets == 1 ? 'set' : 'sets'}${minutes == null ? '' : ' · about $minutes min'}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14)),
                    const SizedBox(height: 12),
                    if (scheduledWorkout != null)
                      Text(_scheduledStatus(scheduledWorkout!),
                          style: const TextStyle(color: Colors.white)),
                    if (freeAttempt?.checkpoint != null ||
                        scheduledWorkout?.attempt != null) ...[
                      Text(
                          '${scheduledWorkout?.attempt?.completedExercises ?? freeAttempt?.completed ?? 0} / ${scheduledWorkout?.attempt?.entries.length ?? freeAttempt?.total ?? exerciseCount} exercises completed · ${scheduledWorkout?.attempt?.statusLabel ?? freeAttempt?.statusLabel}',
                          style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                          value:
                              (scheduledWorkout?.attempt?.completedExercises ??
                                      freeAttempt?.completed ??
                                      0) /
                                  (scheduledWorkout?.attempt?.entries.length ??
                                      freeAttempt?.total ??
                                      exerciseCount)),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 52)),
                            onPressed: onStart,
                            icon: Icon(actionLabelOverride != null
                                ? Icons.calendar_month_outlined
                                : (scheduledWorkout?.attempt?.isComplete ==
                                            true ||
                                        freeAttempt?.attempt?.isComplete ==
                                            true)
                                    ? Icons.summarize_outlined
                                    : Icons.play_arrow_rounded),
                            label: Text(actionLabelOverride ??
                                (scheduledWorkout != null
                                    ? scheduledWorkout!.attempt?.isComplete ==
                                            true
                                        ? 'View Workout Summary'
                                        : scheduledWorkout!.attempt?.finished ==
                                                true
                                            ? 'Resume Unfinished Exercises'
                                            : scheduledWorkout!.inProgress
                                                ? 'Continue workout'
                                                : 'Start workout'
                                    : freeAttempt?.actionLabel ??
                                        'Start workout')))),
                    if (journeyFirst) ...[
                      const SizedBox(height: 8),
                      Text(
                          actionLabelOverride != null
                              ? 'Your saved workout remains available in your training schedule.'
                              : (scheduledWorkout?.attempt?.isComplete ==
                                          true ||
                                      freeAttempt?.attempt?.isComplete == true)
                                  ? 'Workout completed. Review your saved results.'
                                  : 'Choose an exercise next. Progress saves on this device.',
                          style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ])),
        ]),
      );
}

class _WorkoutExerciseRow extends StatelessWidget {
  const _WorkoutExerciseRow(
      {required this.index,
      required this.exercise,
      required this.onTap,
      this.day,
      this.tracker,
      this.organizationId,
      this.statusLabel,
      this.trackers = const ExerciseTrackerDispatcher()});
  final int index;
  final Exercise exercise;
  final int? day;
  final ExerciseTracker? tracker;
  final String? organizationId;
  final String? statusLabel;
  final ExerciseTrackerDispatcher trackers;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final equipment = exercise is PublishedRoutineExercise
        ? (exercise as PublishedRoutineExercise).tutorial.equipment.trim()
        : '';
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.hairline)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              SizedBox(
                  width: 26,
                  child: Text('$index',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.inkSoft,
                          fontWeight: FontWeight.w700))),
              const SizedBox(width: 8),
              ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                      width: 60,
                      height: 60,
                      child: WorkoutExerciseImage(url: exercise.imageUrl))),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(exercise.name,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(
                        exercise is PublishedRoutineExercise
                            ? '${ExercisePresentation.forExercise(exercise as PublishedRoutineExercise, organizationId: organizationId ?? "", trackers: trackers).targetsWithRest}${day == null ? "" : " · Day $day"}'
                            : '${exercise.sets} sets · ${exercise.reps} reps',
                        style: Theme.of(context).textTheme.bodyMedium),
                    if (exercise is PublishedRoutineExercise)
                      Text(
                          ExercisePresentation.forExercise(
                                  exercise as PublishedRoutineExercise,
                                  organizationId: organizationId ?? '',
                                  trackers: trackers)
                              .label,
                          style: Theme.of(context).textTheme.bodySmall),
                    if (equipment.isNotEmpty)
                      Text(equipment,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall),
                    if (statusLabel != null)
                      Text(statusLabel!,
                          style: Theme.of(context).textTheme.bodySmall),
                  ])),
              const Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
            ])),
      ),
    );
  }
}

class _DetourCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _DetourCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: iconColor, size: 23),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontSize: 12.5)),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

Future<bool?> showWorkoutCaptureConsent(BuildContext context,
    {required ValueChanged<bool> onUploadChanged,
    bool allowUpload = true,
    String? exerciseInstruction,
    String? setupConfirmationLabel,
    bool requireSetup = true,
    WorkoutPreferencesController? preferences}) async {
  final auth = context.read<AuthBloc>();
  final scope = auth.state.session?.scope;
  if (scope == null) return false;
  final lease = _CaptureLaunchLease(context);
  try {
    final saved = preferences ?? await createWorkoutPreferences(scope);
    await saved.load();
    if (!lease.current ||
        auth.state.session?.scope != scope ||
        saved.scope != scope) {
      return false;
    }
    if (!saved.validConsent) {
      final accepted = await showAiTrackingPrivacyConsent(context);
      if (accepted != true ||
          !lease.current ||
          auth.state.session?.scope != scope) {
        return false;
      }
      await saved.grantConsent();
    }
    if (!lease.current ||
        auth.state.session?.scope != scope ||
        !saved.validConsent) {
      return false;
    }
    onUploadChanged(false);
    if (!requireSetup) return true;
    final ready = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _ConsentSheet(
            privacyAccepted: true,
            realWorkout: true,
            onUploadChanged: onUploadChanged,
            allowUpload: allowUpload,
            exerciseInstruction: exerciseInstruction,
            setupConfirmationLabel: setupConfirmationLabel));
    return lease.current &&
        auth.state.session?.scope == scope &&
        saved.validConsent &&
        ready == true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'AI Tracking preferences could not be saved. Retry before starting.')));
    }
    return false;
  } finally {
    lease.dispose();
  }
}

const curlCaptureInstruction =
    'Choose both arms, left only or right only before the camera starts. Reps are per selected arm per set. Keep the selected arm closest to the camera, lower it to calibrate, and switch only when prompted. Keep the shoulder, elbow, wrist and hip visible. Results stay on this device; upload and rewards are unavailable.';

const reverseLungeCaptureInstruction =
    'Choose the front leg that stays planted before opening the camera. The other foot steps backward. Reps apply only to the selected front leg for every set; do not alternate within a set. Put a stable side camera on the selected front-leg side, with its knee and heel-to-toe outline, your torso, both hips and both ankles visible. The verified camera hold and 3-second countdown start automatically; no touch is needed. The far knee bend is not measured. Stand tall with a small comfortable gap so both ankles stay visible, then step back, lower with control and return both feet to the same standing position between reps. Balance, load, floor contact and three-dimensional alignment are not assessed. No form score, verified upload or workout rewards are available.';
const reverseLungeSetupConfirmation =
    'My phone is stable at my side, both legs and feet stay visible, and I have clear space to step backward with the other leg.';

const rowCaptureInstruction =
    'Choose the arm to train before opening the camera. Reps apply to that selected arm only. Support the other hand and knee on a stable bench, keep your torso nearly horizontal and let the working arm hang to calibrate. Place the camera side-on with the working shoulder, elbow, wrist and hip visible. Pull the elbow toward your hip and lower with control. Bench contact, weight, spinal shape and three-dimensional rotation are not assessed. No form score, verified upload or workout rewards are available.';
const rowSetupConfirmation =
    'I have a stable bench, the selected arm faces the side camera, and I can keep my shoulder, elbow, wrist and hip visible.';

const shoulderPressCaptureInstruction =
    'Face the camera with both shoulders, elbows, wrists and hips visible. Leave space above your hands. Hold both hands above bent elbows at shoulder height to calibrate. Press overhead together and return with control; both arms together count as one rep. Weight, spinal alignment and three-dimensional shoulder mechanics are not assessed. No form score, verified upload or workout rewards are available.';
const shoulderPressSetupConfirmation =
    'I face the camera with both arms and hips visible and enough space above my hands.';

const calfRaiseCaptureInstruction =
    'Stand side-on on level ground, with both feet flat to calibrate. Keep your hips, knees, heels and toes fully visible. Raise both heels, hold briefly, then lower with control; do not jump. Only the visible leg is measured; equal work on both legs, balance and load are not assessed. Results stay on this device; upload and rewards are unavailable.';

const wallPushUpCaptureInstruction =
    'Face a wall with palms at chest height, then extend your arms to start. Place the phone at your side and keep your shoulder, elbow, wrist, hip and knee visible. Bend toward the wall with your body in line, then push back with control. Keep palms in place. Wall contact is user-confirmed; force, load and equal work by both arms are not assessed. Results stay on this device; upload and rewards are unavailable.';
const wallPushUpSetupConfirmation =
    'My palms are on the wall at chest height, my body is side-on to the camera, and my shoulder, elbow, wrist, hip and knee are visible.';

const floorPushUpCaptureInstruction =
    'Use Left Side View or Right Side View. Place a stable phone near floor height, level and side-on, far enough away to show your whole body. Keep your shoulder, elbow, wrist, hip and ankle visible; the near side is selected automatically. Begin in a floor plank with arms extended, lower your chest with control, then extend fully. After tracking is interrupted, return to the top and hold to restart. Elbow flare, load and floor contact are not assessed. Form estimates and thresholds are provisional. Results save on this device and may appear in descriptive backup reports when you enable backup; verified upload, rewards and automatic recommendations are unavailable.';
const floorPushUpSetupConfirmation =
    'My phone is stable in Left Side View or Right Side View, my whole body is visible, and I have clear floor space for a standard push-up.';

class _ConsentSheet extends StatefulWidget {
  const _ConsentSheet(
      {this.previewOnly = false,
      this.privacyAccepted = false,
      this.realWorkout = false,
      this.allowUpload = true,
      this.exerciseInstruction,
      this.setupConfirmationLabel,
      this.onUploadChanged});
  final bool allowUpload;
  final String? exerciseInstruction;
  final String? setupConfirmationLabel;
  final ValueChanged<bool>? onUploadChanged;
  final bool previewOnly;
  final bool realWorkout;
  final bool privacyAccepted;

  @override
  State<_ConsentSheet> createState() => _ConsentSheetState();
}

class _ConsentSheetState extends State<_ConsentSheet> {
  bool _checked = false;
  bool _setupChecked = false;
  bool _uploadChecked = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
        child: Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: AppColors.hairline,
                  borderRadius: BorderRadius.circular(999)),
            ),
          ),
          Text(
              widget.privacyAccepted
                  ? 'Prepare your exercise'
                  : 'Before we turn on the camera',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (!widget.privacyAccepted)
            Text(
              widget.previewOnly
                  ? 'GainPath uses your camera to display your body landmarks on this device.'
                  : 'GainPath reads your body position from the camera to check your form '
                      'and count your reps.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          const SizedBox(height: 14),
          Panel(
            background: AppColors.primaryTint,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.privacyAccepted)
                  _point(context, 'Everything is processed on this device.'),
                if (!widget.privacyAccepted)
                  _point(context, 'No video is recorded, stored, or uploaded.'),
                if (!widget.privacyAccepted)
                  _point(
                      context,
                      widget.previewOnly
                          ? 'This preview does not save activity or count reps.'
                          : 'Only your movement scores are saved.'),
                if (widget.realWorkout)
                  _point(
                      context,
                      widget.exerciseInstruction ??
                          'This session tracks only the supported squat. Results are saved on this device. Upload is optional and awards no rewards.'),
                if (widget.realWorkout)
                  _point(context,
                      'Form guidance is provisional. Use a side view with the camera upright and stationary, and keep your full body in view.'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (!widget.privacyAccepted)
            InkWell(
              onTap: () => setState(() => _checked = !_checked),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Checkbox(
                      value: _checked,
                      onChanged: (v) => setState(() => _checked = v ?? false),
                    ),
                    Expanded(
                      child: Text(
                        'I agree to camera-based movement tracking as described above.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          if (widget.realWorkout)
            CheckboxListTile(
                value: _setupChecked,
                onChanged: (value) =>
                    setState(() => _setupChecked = value ?? false),
                title: Text(widget.setupConfirmationLabel ??
                    'My full body is visible from the side and the camera is upright and stationary.'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero),
          FilledButton(
            // Camera consent and setup are required; server upload is optional.
            onPressed: (_checked || widget.privacyAccepted) &&
                    (!widget.realWorkout || _setupChecked)
                ? () => Navigator.pop(context, true)
                : null,
            child: Text(widget.privacyAccepted
                ? 'Ready to continue'
                : 'Accept and start'),
          ),
          if (widget.realWorkout && widget.allowUpload)
            CheckboxListTile(
                value: _uploadChecked,
                onChanged: (value) {
                  setState(() => _uploadChecked = value ?? false);
                  widget.onUploadChanged?.call(_uploadChecked);
                },
                title: const Text(
                    'Also allow this measured summary to be uploaded.'),
                subtitle: const Text(
                    'Requires server consent before capture. Only counts, score, measured time and version identifiers are sent. No video or landmarks. Acceptance remains disabled until physical model validation.'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
        ],
      ),
    ));
  }

  Widget _point(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 17, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
                child: Text(text,
                    style: const TextStyle(fontSize: 14, height: 1.4))),
          ],
        ),
      );
}

/// AD-M2.2 detour — View Routine. The full exercise list with thumbnails,
/// set/rep targets, and rest intervals; tapping an exercise hands off into
/// its tutorial. Reviewing and returning is the whole point of this screen
/// living outside the main staging menu.

const lateralRaiseCaptureInstruction =
    'Front view: show both shoulders, elbows, wrists and hips with space on both sides. Hold arms at your sides until Ready, then raise both arms out to shoulder height and lower fully. One bilateral cycle is one rep. Counts are provisional; no form score or load assessment.';
const lateralRaiseSetupConfirmation =
    'I can face the camera with both arms visible throughout the raise. I will hold my arms at my sides for automatic readiness.';

String _scheduledStatus(ScheduledWorkoutPreview workout) {
  final now = DateTime.now().toUtc().add(const Duration(hours: 8));
  final date =
      DateTime.utc(workout.date.year, workout.date.month, workout.date.day);
  final today = DateTime.utc(now.year, now.month, now.day);
  return date == today
      ? 'Scheduled today'
      : date.isBefore(today)
          ? 'Missed · not completed · ${workout.date.day}/${workout.date.month}/${workout.date.year}'
          : 'Upcoming · ${workout.date.day}/${workout.date.month}/${workout.date.year}';
}
