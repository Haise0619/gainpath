import 'dart:async';
import '../../features/workout/presentation/member/workout_privacy_settings_screen.dart';
import '../../features/workout/presentation/member/workout_ai_consent_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show AppRole, SessionScope;
import 'package:gainpath_domain/membership.dart';
import '../../navigation/membership_access_gate.dart';
import '../../features/workout/application/workout_hub_program.dart';
import '../../features/workout/application/workout_hub_attempt.dart';
import '../../features/workout/application/workout_program_controller.dart';
import '../../features/workout/domain/program_enrollment.dart';
import '../../features/workout/domain/routine_journey.dart';
import '../../features/workout/domain/published_routine_view.dart';
import '../../features/workout/presentation/member/published_routine_catalog_controls.dart';
import '../../features/workout/presentation/member/workout_prep_screen.dart';
import '../../navigation/workout_navigation.dart';
import '../di/program_store_factory.dart';
import '../di/workout_store_factory.dart';
import 'pose_preview_route.dart';
import 'exercise_tracker_route.dart';
import 'saved_squat_sessions_route.dart';
import 'exercise_tutorial_route.dart';
import 'routine_journey_route.dart';
import 'workout_program_route.dart';
import 'squat_result_sync.dart' show newWorkoutRequestId;

/// App-owned destinations and read-only program preview for the workout hub.
class WorkoutPrepRoute extends StatefulWidget {
  const WorkoutPrepRoute({
    super.key,
    this.live = true,
    this.publishedRoutine,
    this.routineLoadFailed = false,
    this.routineStatusMessage,
    this.routineCatalogControls,
    this.onOpenEquipment,
    this.programStoreFactory = createProgramEnrollmentStore,
    this.routineStoreFactory = createRoutineJourneyStore,
  });
  final PublishedRoutine? publishedRoutine;
  final bool live;
  final bool routineLoadFailed;
  final String? routineStatusMessage;
  final Widget? routineCatalogControls;
  final VoidCallback? onOpenEquipment;
  final Future<ProgramEnrollmentStore> Function(SessionScope)
      programStoreFactory;
  final Future<RoutineJourneyStore> Function(SessionScope) routineStoreFactory;
  @override
  State<WorkoutPrepRoute> createState() => _WorkoutPrepRouteState();
}

class _WorkoutPrepRouteState extends State<WorkoutPrepRoute>
    with WidgetsBindingObserver {
  AuthBloc? _auth;
  StreamSubscription<AuthState>? _authSubscription;
  SessionScope? _scope;
  WorkoutProgramController? _controller;
  WorkoutHubProgram? _hub;
  ScheduledWorkoutPreview? _scheduled;
  List<RoutineCheckpoint> _checkpoints = [];
  bool _loading = false,
      _loadError = false,
      _showFree = false,
      _starting = false;
  int _generation = 0;

  SessionScope? _activeScope() {
    final auth = _auth;
    if (!mounted ||
        !widget.live ||
        auth == null ||
        !AuthRolePolicy.canEnter(auth.state, allowed: const {AppRole.member})) {
      return null;
    }
    return auth.state.session?.scope;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindAuth();
  }

  void _bindAuth() {
    if (!widget.live || _auth != null) return;
    _auth = context.read<AuthBloc>();
    _authSubscription = _auth!.stream.listen((_) => _syncScope());
    _syncScope();
  }

  @override
  void didUpdateWidget(WorkoutPrepRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.live && widget.live) {
      _bindAuth();
      _syncScope();
    }
    if (oldWidget.live && !widget.live) _syncScope();
  }

  void _syncScope() {
    final current = _activeScope();
    if (current == _scope) return;
    ++_generation;
    _controller?.dispose();
    _controller = null;
    _hub = null;
    _scheduled = null;
    _checkpoints = [];
    _showFree = false;
    _scope = current;
    if (current != null) {
      unawaited(_reload(current));
    } else if (mounted) {
      setState(() {
        _loading = false;
        _loadError = false;
      });
    }
  }

  Future<void> _reload(SessionScope scope) async {
    final generation = ++_generation;
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = false;
      });
    }
    WorkoutProgramController? candidate;
    try {
      final routineStore = await widget.routineStoreFactory(scope);
      final checkpoints = await routineStore.load();
      if (!mounted || generation != _generation || _activeScope() != scope) {
        return;
      }
      setState(() => _checkpoints = checkpoints);
      final store = await widget.programStoreFactory(scope);
      if (!mounted || generation != _generation || _activeScope() != scope) {
        return;
      }
      candidate = WorkoutProgramController(
          scope: scope,
          activeScope: () => _activeScope() == scope ? scope : null,
          store: store,
          routineStore: routineStore,
          newId: newWorkoutRequestId);
      final hub = WorkoutHubProgram(candidate);
      final preview = await hub.refresh();
      if (!mounted || generation != _generation || _activeScope() != scope) {
        return;
      }
      final old = _controller;
      setState(() {
        _controller = candidate;
        _hub = hub;
        _scheduled = preview;
        _checkpoints = checkpoints;
        _loading = false;
      });
      candidate = null;
      old?.dispose();
    } catch (_) {
      if (mounted && generation == _generation && _activeScope() == scope) {
        setState(() {
          _loading = false;
          _loadError = true;
          _scheduled = null;
        });
      }
    } finally {
      candidate?.dispose();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _scope != null && !_starting) {
      unawaited(_reload(_scope!));
    }
  }

  Future<void> _openPrograms(SessionScope scope, AuthBloc auth) async {
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => BlocProvider.value(
                value: auth,
                child: WorkoutProgramRoute(
                    scope: scope,
                    storeFactory: widget.programStoreFactory,
                    routineStoreFactory: widget.routineStoreFactory))));
    if (mounted && _activeScope() == scope) {
      _showFree = false;
      await _reload(scope);
    }
  }

  Future<void> _startScheduled() async {
    final shown = _scheduled, hub = _hub, auth = _auth, scope = _scope;
    if (_starting ||
        shown == null ||
        hub == null ||
        auth == null ||
        scope == null ||
        _activeScope() != scope ||
        _showFree) {
      return;
    }
    setState(() => _starting = true);
    try {
      final launch = await hub.start(shown);
      if (!mounted || _activeScope() != scope) return;
      await Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (_) => BlocProvider.value(
                  value: auth,
                  child: RoutineJourneyRoute(
                      scope: scope,
                      routine: launch.routine,
                      storeFactory: widget.routineStoreFactory,
                      programStoreFactory: widget.programStoreFactory,
                      programAttemptId: launch.attemptId,
                      programEnrollmentId: launch.enrollmentId,
                      programDayKey: launch.dayKey,
                      initialDay: launch.routineDay,
                      action: shown.attempt?.finished == true &&
                              shown.attempt?.isComplete != true
                          ? RoutineJourneyAction.resume
                          : RoutineJourneyAction.view))));
    } catch (_) {
      if (mounted && _activeScope() == scope) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Your training plan could not be started. Please review it and try again.')));
      }
    } finally {
      if (mounted) {
        setState(() => _starting = false);
        if (_activeScope() == scope) await _reload(scope);
      }
    }
  }

  @override
  void dispose() {
    ++_generation;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_authSubscription?.cancel());
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = _auth;
    final scope = _activeScope();
    final scheduled = !_showFree ? _scheduled : null;
    final routine = widget.publishedRoutine;
    final freeAttempt = scope == null || routine == null
        ? null
        : WorkoutHubAttempt.fromCheckpoints(
            scope: scope,
            routine: routine,
            checkpoints: _checkpoints,
            scheduledAttemptIds:
                _controller?.journal?.scheduledAttemptIds ?? const {});
    final original = widget.routineCatalogControls;
    final Widget? controls;
    if (original is PublishedRoutineCatalogControls) {
      controls = PublishedRoutineCatalogControls(
        state: original.state,
        catalogCubit: original.catalogCubit,
        inHero: scheduled != null ||
            (widget.publishedRoutine?.exercises.isNotEmpty ?? false),
        onRefresh: original.onRefresh,
        onLoadMore: original.onLoadMore,
        onSelect: (id) {
          if (mounted) setState(() => _showFree = true);
          original.onSelect(id);
        },
        scheduledTitle: _scheduled?.routine.title,
        scheduledSelected: scheduled != null,
        onChooseScheduled: _scheduled == null
            ? null
            : () {
                if (mounted) setState(() => _showFree = false);
              },
      );
    } else {
      controls = original;
    }
    return Stack(children: [
      IgnorePointer(
          ignoring: _starting,
          child: WorkoutPrepScreen(
            live: widget.live,
            organizationId: scope?.organizationId,
            onOpenSettings: scope == null
                ? null
                : () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => WorkoutPrivacySettingsScreen(
                                scope: scope,
                                isCurrent: () => _activeScope() == scope)));
                    if (mounted && _activeScope() == scope) {
                      await _reload(scope);
                    }
                  },
            onOpenPrograms: scope == null || auth == null
                ? null
                : () => _openPrograms(scope, auth),
            onOpenEquipment: widget.onOpenEquipment,
            publishedRoutine: widget.publishedRoutine,
            freeAttempt: freeAttempt,
            onStartFree: scope == null ||
                    auth == null ||
                    widget.publishedRoutine == null
                ? null
                : () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => BlocProvider.value(
                                value: auth,
                                child: RoutineJourneyRoute(
                                    scope: scope,
                                    routine: widget.publishedRoutine!,
                                    storeFactory: widget.routineStoreFactory,
                                    programStoreFactory:
                                        widget.programStoreFactory,
                                    attemptId: freeAttempt!.checkpoint?.id,
                                    action: freeAttempt.startsNewAttempt
                                        ? RoutineJourneyAction.repeat
                                        : freeAttempt.resumeUnfinished
                                            ? RoutineJourneyAction.resume
                                            : RoutineJourneyAction.view))));
                    if (mounted && _activeScope() == scope) {
                      await _reload(scope);
                    }
                  },
            recoveryDayLabel: !_showFree ? _hub?.recoveryDayLabel : null,
            scheduledWorkout: scheduled,
            onStartScheduled: scheduled == null ? null : _startScheduled,
            programLoading: _loading,
            programLoadError: _loadError,
            routineLoadFailed: widget.routineLoadFailed,
            routineStatusMessage: widget.routineStatusMessage,
            routineCatalogControls: controls,
            routes: WorkoutPrepRoutes(
              realSessionBuilder: _realSession,
              savedSessionsBuilder: _savedSessions,
              posePreviewBuilder: _posePreview,
              journeyBuilder: scope == null
                  ? null
                  : (_, routine) => RoutineJourneyRoute(
                      scope: scope,
                      routine: routine,
                      storeFactory: widget.routineStoreFactory,
                      programStoreFactory: widget.programStoreFactory),
              tutorialBuilder: scope == null || auth == null
                  ? null
                  : (_, exercise) => BlocProvider.value(
                      value: auth,
                      child: ExerciseTutorialRoute(
                          scope: scope, exercise: exercise)),
            ),
          )),
      if (_starting)
        const Positioned(
            top: 0, left: 0, right: 0, child: LinearProgressIndicator()),
    ]);
  }
}

Widget _realSession(BuildContext context, RealWorkoutLaunch launch) =>
    MembershipAccessGate(
        enabled: membershipAccessEnforcementEnabled,
        feature: MembershipAccessFeature.exercise,
        resourceId: launch.exercise.exerciseId,
        child: WorkoutAiConsentGuard(
            scope: launch.scope, child: ExerciseTrackerRoute(launch: launch)));
Widget _savedSessions(BuildContext context, SessionScope scope) =>
    SavedSquatSessionsRoute(scope: scope);
Widget _posePreview(BuildContext context) => const PosePreviewRoute();
