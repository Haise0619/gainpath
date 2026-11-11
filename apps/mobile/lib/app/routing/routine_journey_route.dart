import 'dart:async';
import '../../features/workout/presentation/member/workout_privacy_settings_screen.dart';
import '../di/workout_preferences_factory.dart';
import '../../features/workout/domain/program_enrollment.dart';
import '../../features/workout/application/workout_preferences_controller.dart';
import '../../features/workout/presentation/member/workout_ai_consent_guard.dart';
import 'between_exercise_rest_route.dart';
import '../../features/workout/domain/tutorial_player.dart';
import '../../infrastructure/media/video_tutorial_player.dart';
import '../../features/workout/presentation/workout_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show AppRole, SessionScope;
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import '../../features/workout/application/routine_journey_controller.dart';
import '../../features/workout/data/workout_session_repository.dart';
import '../../features/workout/domain/published_routine_view.dart';
import '../../features/workout/domain/routine_workout_context.dart';
import '../../features/workout/domain/routine_journey.dart';
import '../../features/workout/domain/workout_audio_port.dart';
import '../../features/workout/presentation/member/routine_next_exercise_sheet.dart';
import '../../features/workout/domain/exercise_tracker_dispatcher.dart';
import '../../navigation/workout_navigation.dart';
import '../../features/workout/presentation/member/routine_journey_screen.dart';
import '../../features/workout/presentation/member/workout_prep_screen.dart'
    show
        showWorkoutCaptureConsent,
        lateralRaiseCaptureInstruction,
        lateralRaiseSetupConfirmation,
        curlCaptureInstruction,
        rowCaptureInstruction,
        reverseLungeCaptureInstruction,
        reverseLungeSetupConfirmation,
        shoulderPressCaptureInstruction,
        shoulderPressSetupConfirmation,
        rowSetupConfirmation,
        calfRaiseCaptureInstruction,
        wallPushUpCaptureInstruction,
        wallPushUpSetupConfirmation,
        floorPushUpCaptureInstruction,
        floorPushUpSetupConfirmation;
import '../../navigation/membership_access_gate.dart';
import '../di/workout_store_factory.dart';
import 'exercise_tutorial_route.dart';
import 'member_progress_route.dart';
import 'exercise_tracker_route.dart';
import 'guided_timed_workout_route.dart';
import '../../features/workout/domain/exercise_execution_resolver.dart';
import 'squat_result_sync.dart' show newWorkoutRequestId;

enum RoutineJourneyAction { view, resume, repeat, nextDay }

class RoutineJourneyRoute extends StatefulWidget {
  const RoutineJourneyRoute(
      {super.key,
      required this.scope,
      required this.routine,
      this.trackers = const ExerciseTrackerDispatcher(),
      this.attemptId,
      this.programAttemptId,
      this.programEnrollmentId,
      this.programDayKey,
      this.initialDay = 1,
      this.startFirstExercise = false,
      this.storeFactory = createRoutineJourneyStore,
      this.workoutStoreFactory = createWorkoutStore,
      this.preferencesFactory = createWorkoutPreferences,
      this.programStoreFactory,
      this.voicePreferencesFactory = createWorkoutVoicePreferences,
      this.timedPlayerFactory = VideoTutorialPlayer.new,
      this.restClock,
      this.measuredBuilder,
      this.action = RoutineJourneyAction.view});
  final SessionScope scope;
  final PublishedRoutine routine;
  final ExerciseTrackerDispatcher trackers;
  final String? attemptId;
  final String? programAttemptId;
  final String? programEnrollmentId, programDayKey;
  final int initialDay;
  final bool startFirstExercise;
  final RoutineJourneyAction action;
  final Future<RoutineJourneyStore> Function(SessionScope) storeFactory;
  final Future<WorkoutSessionStore> Function(SessionScope) workoutStoreFactory;
  final Future<ProgramEnrollmentStore> Function(SessionScope)?
      programStoreFactory;
  final Future<WorkoutPreferencesController> Function(SessionScope)
      preferencesFactory;
  final Future<WorkoutVoicePreferences> Function(SessionScope)
      voicePreferencesFactory;
  final TutorialPlayerFactory timedPlayerFactory;
  final Duration Function()? restClock;
  final Widget Function(RealWorkoutLaunch)? measuredBuilder;
  @override
  State<RoutineJourneyRoute> createState() => _RoutineJourneyRouteState();
}

class _RoutineJourneyRouteState extends State<RoutineJourneyRoute>
    with WidgetsBindingObserver {
  WorkoutPreferencesController? _preferences;
  bool _foreground = true, _launching = false;
  int _interruptionEpoch = 0;
  RoutineJourneyController? _controller;
  WorkoutSessionRepository? _workouts;
  StreamSubscription<AuthState>? _subscription;
  bool _opening = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _interruptionEpoch++;
  }

  bool _authorized(AuthBloc auth) =>
      auth.state.session?.scope == widget.scope &&
      AuthRolePolicy.canEnter(auth.state, allowed: const {AppRole.member});
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_opening && _controller == null && _error == null) unawaited(_open());
  }

  Future<void> _open() async {
    _opening = true;
    final launchEpoch = _interruptionEpoch;
    final auth = context.read<AuthBloc>();
    try {
      if (!_authorized(auth)) throw StateError('Routine account unavailable');
      final store = await widget.storeFactory(widget.scope);
      final workoutStore = await widget.workoutStoreFactory(widget.scope);
      final programStore = await widget.programStoreFactory?.call(widget.scope);
      if (widget.programAttemptId case final attemptId?) {
        final journal = await programStore?.load();
        final links = journal?.slotsForAttempt(attemptId).toList();
        if (links == null ||
            links.length != 1 ||
            journal?.activeId != widget.programEnrollmentId ||
            links.single.enrollment.id != widget.programEnrollmentId ||
            links.single.day.key != widget.programDayKey ||
            links.single.day.definition.routineDay != widget.initialDay ||
            links.single.day.definition.routineId != widget.routine.id ||
            links.single.enrollment.progress[links.single.day.key]?.skipped ==
                true) {
          throw StateError('The scheduled workout changed');
        }
      }
      try {
        _preferences = await widget.preferencesFactory(widget.scope);
      } catch (_) {
        /* Manual work remains available; automatic launch fails closed. */
      }
      if (!mounted || !_authorized(auth)) return;
      _workouts = WorkoutSessionRepository(
          scope: widget.scope,
          store: workoutStore,
          uploadGateway: UnavailableWorkoutUploadGateway(),
          activeScope: () => _authorized(auth) ? widget.scope : null);
      final c = RoutineJourneyController(
          scope: widget.scope,
          activeScope: () => _authorized(auth) ? widget.scope : null,
          routine: widget.routine,
          store: store,
          programStore: programStore,
          workouts: _workouts!,
          trackers: widget.trackers,
          newId: newWorkoutRequestId);
      _controller = c;
      _subscription = auth.stream.listen((_) => c.accountChanged());
      if (widget.programAttemptId != null) {
        await c.openProgramAttempt(widget.programAttemptId!, widget.initialDay);
      } else if (widget.attemptId == null) {
        await c.openLatest();
      } else {
        await c.openAttempt(widget.attemptId!);
      }
      switch (widget.action) {
        case RoutineJourneyAction.view:
          break;
        case RoutineJourneyAction.resume:
          await c.resume();
        case RoutineJourneyAction.repeat:
          await c.startNewAttempt();
        case RoutineJourneyAction.nextDay:
          await c.startNextDay();
      }
      if (c.allTargetsCompleted && !c.checkpoint!.finished) await c.finish();
      if (mounted) {
        setState(() {});
        final index = c.selectedIndex;
        if (widget.startFirstExercise &&
            c.checkpoint?.finished == false &&
            c.statusFor(index) == RoutineExerciseStatus.notStarted &&
            (c.isTimed(index) || c.supportsTracking(index))) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                launchEpoch == _interruptionEpoch &&
                _authorized(auth) &&
                c.selectedIndex == index) {
              unawaited(_track(index, automatic: true).catchError((Object _) {
                if (mounted && _authorized(auth)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content:
                          Text('Could not start this exercise. Try again.')));
                }
              }));
            }
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Routine progress is unavailable. Your saved workout history is retained.');
      }
    } finally {
      _opening = false;
    }
  }

  Future<void> _track(int index, {bool automatic = false}) async {
    if (_launching ||
        !_foreground ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _launching = true;
    try {
      await _trackOnce(index, automatic: automatic);
    } finally {
      _launching = false;
    }
  }

  Future<void> _trackOnce(int index, {bool automatic = false}) async {
    final launchEpoch = _interruptionEpoch;
    final auth = context.read<AuthBloc>(), c = _controller!;
    if (!_authorized(auth) ||
        !_foreground ||
        c.checkpoint?.finished != false ||
        isExerciseTargetComplete(c.statusFor(index))) {
      return;
    }
    final execution = c.executionFor(index);
    final attemptId = c.checkpoint!.id, day = c.day;
    bool currentLaunch() =>
        mounted &&
        _authorized(auth) &&
        _foreground &&
        ModalRoute.of(context)?.isCurrent == true &&
        c.checkpoint?.id == attemptId &&
        c.day == day &&
        c.selectedIndex == index &&
        launchEpoch == _interruptionEpoch &&
        c.checkpoint?.finished == false;
    if (c.isTimed(index)) {
      if (execution.kind != ExerciseExecutionKind.timed) {
        throw StateError('Video guided exercise unavailable');
      }
      final progress = await c.prepareGuidedSession(index);
      if (!currentLaunch()) return;
      final outcome = await Navigator.push<GuidedTimedWorkoutOutcome>(
          context,
          MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                  value: auth,
                  child: MembershipAccessGate(
                      enabled: membershipAccessEnforcementEnabled,
                      feature: MembershipAccessFeature.exercise,
                      resourceId: widget.routine.exercises[index].exerciseId,
                      child: GuidedTimedWorkoutRoute(
                          autoStart: automatic,
                          playerFactory: widget.timedPlayerFactory,
                          autoContinue: _preferences?.autoContinue == true,
                          scope: widget.scope,
                          routine: widget.routine,
                          exerciseIndex: index,
                          progress: progress,
                          persist: (value) =>
                              c.saveGuidedProgress(index, value))))));
      if (!mounted || !_authorized(auth)) return;
      if (outcome == GuidedTimedWorkoutOutcome.skipped) await c.skip(index);
      await c.refresh(completeRoutine: true);
      if (!mounted || !_authorized(auth)) return;
      if (c.statusFor(index) == RoutineExerciseStatus.timerCompleted &&
          !c.checkpoint!.finished &&
          c.unfinishedIndices.isNotEmpty) {
        if (launchEpoch == _interruptionEpoch) {
          await _nextExercise(index);
        }
      }
      return;
    }
    if (!c.supportsTracking(index)) {
      await _tutorial(index);
      return;
    }
    var upload = false;
    _preferences ??= await widget.preferencesFactory(widget.scope);
    if (!currentLaunch()) return;
    final tracker = c.trackingFor(index).tracker;
    final consented = await showWorkoutCaptureConsent(context,
        preferences: _preferences,
        // Calf Raise confirms floor contact in its own setup. Floor Push-up
        // confirms a stable phone and clear floor space here.
        requireSetup: !const {
              ExerciseTracker.sideViewSquat,
              ExerciseTracker.sideViewCurl,
              ExerciseTracker.sideViewCalfRaise,
              ExerciseTracker.frontViewLateralRaise,
              ExerciseTracker.frontViewShoulderPress,
            }.contains(tracker) &&
            !(automatic &&
                const {
                  ExerciseTracker.sideViewRow,
                  ExerciseTracker.sideViewReverseLunge,
                }.contains(tracker)),
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
        onUploadChanged: (value) => upload = value);
    if (consented != true ||
        launchEpoch != _interruptionEpoch ||
        !mounted ||
        !_authorized(auth) ||
        !_foreground ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    // Persist the exact capture ID before opening the camera. Reconciliation
    // can recover a durable result after interruption without duplicate activity.
    final sessionId = await c.prepareCapture(index);
    if (!currentLaunch() || _preferences?.validConsent != true) return;
    final exercise = widget.routine.exercises[index];
    final nextIndex = c.unfinishedIndices
        .where((candidate) => candidate != index)
        .firstOrNull;
    final launch = RealWorkoutLaunch(
        scope: widget.scope,
        routineId: widget.routine.id,
        exercise: exercise,
        consented: true,
        consentCurrent: () => _preferences?.validConsent == true,
        setupConfirmed: true,
        requestServerUpload: upload,
        sessionId: sessionId,
        routineContext: RoutineWorkoutContext(
            routineTitle: widget.routine.title,
            day: c.day,
            exerciseNumber: c.dayIndices.indexOf(index) + 1,
            totalExercises: c.dayIndices.length,
            nextExerciseName: nextIndex == null
                ? null
                : widget.routine.exercises[nextIndex].name),
        returnToRoutine: true);
    final saved = await Navigator.push<WorkoutSessionSummary>(
        context,
        MaterialPageRoute<WorkoutSessionSummary>(
            builder: (_) => BlocProvider.value(
                value: auth,
                child: MembershipAccessGate(
                    enabled: membershipAccessEnforcementEnabled,
                    feature: MembershipAccessFeature.exercise,
                    resourceId: exercise.exerciseId,
                    child: WorkoutAiConsentGuard(
                        scope: widget.scope,
                        preferencesFactory: widget.preferencesFactory,
                        child: widget.measuredBuilder?.call(launch) ??
                            ExerciseTrackerRoute(
                                trackers: widget.trackers, launch: launch))))));
    if (!mounted || !_authorized(auth)) return;
    await c.refresh(completeRoutine: true);
    if (!mounted || !_authorized(auth) || saved == null) return;
    if (c.statusFor(index) != RoutineExerciseStatus.completed) {
      await c.select(index);
      return;
    }
    if (!c.checkpoint!.finished && c.unfinishedIndices.isNotEmpty) {
      if (launchEpoch == _interruptionEpoch) await _nextExercise(index);
    }
  }

  Future<void> _nextExercise(int previousIndex) async {
    final auth = context.read<AuthBloc>(), c = _controller!;
    final launchEpoch = _interruptionEpoch;
    final previousExercise = widget.routine.exercises[previousIndex].name;
    if (!mounted ||
        !_foreground ||
        !_authorized(auth) ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final preferences = _preferences;
    if (preferences != null &&
        preferences.autoContinue &&
        !c.busy &&
        c.error == null &&
        c.checkpoint?.finished == false &&
        c.unfinishedIndices.isNotEmpty &&
        _foreground &&
        ModalRoute.of(context)?.isCurrent == true) {
      final attemptId = c.checkpoint!.id, day = c.day, index = c.selectedIndex;
      bool valid() =>
          mounted &&
          _authorized(auth) &&
          c.checkpoint?.id == attemptId &&
          c.day == day &&
          c.selectedIndex == index &&
          c.checkpoint?.finished == false &&
          c.error == null &&
          !c.busy &&
          c.unfinishedIndices.contains(index);
      bool hasRetainedTracker(int candidate) => const {
            ExerciseTracker.sideViewSquat,
            ExerciseTracker.sideViewCurl,
            ExerciseTracker.sideViewCalfRaise,
            ExerciseTracker.sideViewFloorPushUp,
            ExerciseTracker.frontViewLateralRaise,
            ExerciseTracker.frontViewShoulderPress,
          }.contains(c.executionFor(candidate).tracker);
      final BetweenExerciseRestVoice? voice = hasRetainedTracker(
                  previousIndex) ||
              hasRetainedTracker(index)
          ? (
              loadMode: () async =>
                  (await widget.voicePreferencesFactory(widget.scope)).read(),
              canAnnounce: () =>
                  preferences.scope == widget.scope && preferences.validConsent,
              authorization: Listenable.merge([c, preferences]),
            )
          : null;
      final outcome = await Navigator.push<BetweenExerciseRestOutcome>(
          context,
          MaterialPageRoute(
              builder: (_) => BetweenExerciseRestRoute(
                  previousExercise: previousExercise,
                  upcomingExercise: widget.routine.exercises[index],
                  organizationId: widget.scope.organizationId,
                  restSeconds: widget.routine.betweenExerciseRestSeconds ??
                      preferences.suggestedRestSeconds,
                  monotonicNow: widget.restClock,
                  prescribed: widget.routine.betweenExerciseRestSeconds != null,
                  voice: voice,
                  canAdvance: () =>
                      valid() && _preferences?.autoContinue == true)));
      if (outcome != BetweenExerciseRestOutcome.advance ||
          !valid() ||
          !_foreground ||
          _preferences?.autoContinue != true) {
        return;
      }
      // Manual selection is the logger itself; navigation never grants a set.
      if (c.isTimed(index) || c.supportsTracking(index)) {
        await _trackOnce(index, automatic: true);
      }
      return;
    }
    while (mounted && _authorized(auth) && c.unfinishedIndices.isNotEmpty) {
      final index = c.selectedIndex, tracking = c.trackingFor(c.selectedIndex);
      final action = await showModalBottomSheet<RoutineNextAction>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => ListenableBuilder(
              listenable: c,
              builder: (context, _) => c.authorized && _authorized(auth)
                  ? RoutineNextExerciseSheet(
                      previousExercise: previousExercise,
                      organizationId: widget.scope.organizationId,
                      exercise: widget.routine.exercises[index],
                      completedExercises: c.completedExercises,
                      totalExercises: c.dayIndices.length,
                      capabilityLabel: c.isTimed(index)
                          ? 'Video guided · Timer'
                          : tracking.capability.displayLabel,
                      hasTracking: tracking.capability.hasPoseTracking,
                      perArmTargets: c.perArmTargetsFor(index),
                      guidance: c.isTimed(index)
                          ? 'Timer completion · Not AI verified'
                          : tracking.description)
                  : const SafeArea(
                      child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Sign in to continue this routine.')))));
      if (!mounted ||
          !_foreground ||
          launchEpoch != _interruptionEpoch ||
          !_authorized(auth) ||
          action == null) {
        return;
      }
      if (action == RoutineNextAction.tutorial) {
        await _tutorial(index);
      } else {
        if (c.isTimed(index) || c.supportsTracking(index)) {
          await _trackOnce(index);
        }
        return;
      }
    }
  }

  Future<void> _tutorial(int index) async {
    final auth = context.read<AuthBloc>(), c = _controller!;
    if (!_authorized(auth)) return;
    final attemptId = c.checkpoint?.id, day = c.day;
    final outcome = await Navigator.push<ExerciseTutorialOutcome>(
        context,
        MaterialPageRoute(
            builder: (_) => BlocProvider.value(
                value: auth,
                child: ExerciseTutorialRoute(
                    scope: widget.scope,
                    exercise: widget.routine.exercises[index],
                    allowStart: attemptId != null &&
                        !c.checkpoint!.finished &&
                        !isExerciseTargetComplete(c.statusFor(index))))));
    if (!mounted ||
        !_authorized(auth) ||
        outcome != ExerciseTutorialOutcome.startExercise ||
        c.checkpoint?.id != attemptId ||
        c.day != day ||
        c.checkpoint!.finished ||
        !c.dayIndices.contains(index) ||
        isExerciseTargetComplete(c.statusFor(index))) {
      return;
    }
    await c.select(index);
    if (!mounted ||
        !_authorized(auth) ||
        c.checkpoint?.id != attemptId ||
        c.selectedIndex != index) {
      return;
    }
    if (c.isTimed(index) || c.supportsTracking(index)) await _track(index);
  }

  Future<void> _manualSet(int index) async {
    final epoch = _interruptionEpoch;
    if (_launching) return;
    _launching = true;
    try {
      final c = _controller!;
      await c.markManualSet(index);
      if (c.allTargetsCompleted) {
        await c.finish();
        return;
      }
      if (mounted &&
          epoch == _interruptionEpoch &&
          c.statusFor(index) == RoutineExerciseStatus.selfReportedCompleted) {
        await _nextExercise(index);
      }
    } finally {
      _launching = false;
    }
  }

  Future<void> _openProgress(MemberProgressView view) async {
    final c = _controller!, auth = context.read<AuthBloc>();
    final id = c.checkpoint?.id;
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) =>
                MemberProgressRoute(scope: widget.scope, view: view)));
    if (!mounted || !_authorized(auth) || id == null) return;
    try {
      await c.openAttempt(id);
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Reopen this routine to load its latest progress.');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    _controller?.dispose();
    _workouts?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
        if (state.session?.scope != widget.scope ||
            !AuthRolePolicy.canEnter(state, allowed: const {AppRole.member})) {
          return const Scaffold(
              body: Center(
                  child: Text('Sign in to view this account’s routine.')));
        }
        if (_error != null) {
          return Scaffold(
              appBar: AppBar(title: const Text('Routine unavailable')),
              body: Center(
                  child: FilledButton(
                      onPressed: () {
                        _controller?.dispose();
                        _controller = null;
                        _workouts?.dispose();
                        unawaited(_subscription?.cancel());
                        _subscription = null;
                        setState(() => _error = null);
                        unawaited(_open());
                      },
                      child: const Text('Retry routine'))));
        }
        final c = _controller;
        if (c == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return RoutineJourneyScreen(
            controller: c,
            onTrack: _track,
            onManualSet: _manualSet,
            onOpenSettings: () async {
              final auth = context.read<AuthBloc>();
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => WorkoutPrivacySettingsScreen(
                          scope: widget.scope,
                          onOpenBackup: () =>
                              _openProgress(MemberProgressView.backup),
                          isCurrent: () => mounted && _authorized(auth))));
            },
            onTutorial: _tutorial,
            onViewHistory: () => _openProgress(MemberProgressView.routines));
      });
}
