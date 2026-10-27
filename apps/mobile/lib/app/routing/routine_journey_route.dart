import 'dart:async';
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
import '../../features/workout/presentation/member/routine_next_exercise_sheet.dart';
import '../../features/workout/domain/exercise_tracker_dispatcher.dart';
import '../../navigation/workout_navigation.dart';
import '../../features/workout/presentation/member/routine_journey_screen.dart';
import '../../features/workout/presentation/member/workout_prep_screen.dart'
    show
        showWorkoutCaptureConsent,
        curlCaptureInstruction,
        calfRaiseCaptureInstruction,
        wallPushUpCaptureInstruction,
        wallPushUpSetupConfirmation;
import '../../navigation/membership_access_gate.dart';
import '../di/workout_store_factory.dart';
import 'exercise_tutorial_route.dart';
import 'member_progress_route.dart';
import 'exercise_tracker_route.dart';
import 'squat_result_sync.dart' show newWorkoutRequestId;

enum RoutineJourneyAction { view, resume, repeat, nextDay }

class RoutineJourneyRoute extends StatefulWidget {
  const RoutineJourneyRoute(
      {super.key,
      required this.scope,
      required this.routine,
      this.trackers = const ExerciseTrackerDispatcher(),
      this.attemptId,
      this.action = RoutineJourneyAction.view});
  final SessionScope scope;
  final PublishedRoutine routine;
  final ExerciseTrackerDispatcher trackers;
  final String? attemptId;
  final RoutineJourneyAction action;
  @override
  State<RoutineJourneyRoute> createState() => _RoutineJourneyRouteState();
}

class _RoutineJourneyRouteState extends State<RoutineJourneyRoute> {
  RoutineJourneyController? _controller;
  WorkoutSessionRepository? _workouts;
  StreamSubscription<AuthState>? _subscription;
  bool _opening = false;
  String? _error;
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
    final auth = context.read<AuthBloc>();
    try {
      if (!_authorized(auth)) throw StateError('Routine account unavailable');
      final store = await createRoutineJourneyStore(widget.scope);
      final workoutStore = await createWorkoutStore(widget.scope);
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
          workouts: _workouts!,
          trackers: widget.trackers,
          newId: newWorkoutRequestId);
      _controller = c;
      _subscription = auth.stream.listen((_) => c.accountChanged());
      if (widget.attemptId == null) {
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
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Routine progress is unavailable. Your saved workout history is retained.');
      }
    } finally {
      _opening = false;
    }
  }

  Future<void> _track(int index) async {
    final auth = context.read<AuthBloc>(), c = _controller!;
    if (!_authorized(auth)) return;
    if (!c.supportsTracking(index)) {
      await _tutorial(index);
      return;
    }
    var upload = false;
    final tracker = c.trackingFor(index).tracker;
    final consented = await showWorkoutCaptureConsent(context,
        allowUpload: tracker == ExerciseTracker.sideViewSquat,
        exerciseInstruction: switch (tracker) {
          ExerciseTracker.sideViewCurl => curlCaptureInstruction,
          ExerciseTracker.sideViewCalfRaise => calfRaiseCaptureInstruction,
          ExerciseTracker.sideViewWallPushUp => wallPushUpCaptureInstruction,
          _ => null,
        },
        setupConfirmationLabel: tracker == ExerciseTracker.sideViewWallPushUp
            ? wallPushUpSetupConfirmation
            : null,
        onUploadChanged: (value) => upload = value);
    if (consented != true || !mounted || !_authorized(auth)) return;
    // Persist the exact capture ID before opening the camera. Reconciliation
    // can recover a durable result after interruption without duplicate activity.
    final sessionId = await c.prepareCapture(index);
    if (!mounted || !_authorized(auth)) return;
    final exercise = widget.routine.exercises[index];
    final nextIndex = c.unfinishedIndices
        .where((candidate) => candidate != index)
        .firstOrNull;
    final saved = await Navigator.push<WorkoutSessionSummary>(
        context,
        MaterialPageRoute<WorkoutSessionSummary>(
            builder: (_) => BlocProvider.value(
                value: auth,
                child: MembershipAccessGate(
                    enabled: membershipAccessEnforcementEnabled,
                    feature: MembershipAccessFeature.exercise,
                    resourceId: exercise.exerciseId,
                    child: ExerciseTrackerRoute(
                        trackers: widget.trackers,
                        launch: RealWorkoutLaunch(
                            scope: widget.scope,
                            routineId: widget.routine.id,
                            exercise: exercise,
                            consented: true,
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
                            returnToRoutine: true))))));
    if (!mounted || !_authorized(auth)) return;
    await c.refresh(completeRoutine: true);
    if (!mounted || !_authorized(auth) || saved == null) return;
    if (c.statusFor(index) != RoutineExerciseStatus.completed) {
      await c.select(index);
      return;
    }
    if (!c.checkpoint!.finished && c.unfinishedIndices.isNotEmpty) {
      await _nextExercise(exercise.name);
    }
  }

  Future<void> _nextExercise(String previousExercise) async {
    final auth = context.read<AuthBloc>(), c = _controller!;
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
                      exercise: widget.routine.exercises[index],
                      completedExercises: c.completedExercises,
                      totalExercises: c.dayIndices.length,
                      capabilityLabel: tracking.capability.displayLabel,
                      hasTracking: tracking.capability.hasPoseTracking,
                      perArmTargets: c.perArmTargetsFor(index),
                      guidance: tracking.description)
                  : const SafeArea(
                      child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Sign in to continue this routine.')))));
      if (!mounted || !_authorized(auth) || action == null) return;
      if (action == RoutineNextAction.tutorial) {
        await _tutorial(index);
      } else {
        await _track(index);
        return;
      }
    }
  }

  Future<void> _tutorial(int index) async {
    final auth = context.read<AuthBloc>();
    if (!_authorized(auth)) return;
    await Navigator.push<void>(
        context,
        MaterialPageRoute(
            builder: (_) => BlocProvider.value(
                value: auth,
                child: ExerciseTutorialRoute(
                    scope: widget.scope,
                    exercise: widget.routine.exercises[index]))));
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
            onTutorial: _tutorial,
            onViewProgress: () => _openProgress(MemberProgressView.dashboard),
            onViewHistory: () => _openProgress(MemberProgressView.routines));
      });
}
