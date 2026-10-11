import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show AppRole, SessionScope;
import 'package:gainpath_identity/gainpath_identity.dart';
import '../../features/workout/application/real_squat_session_controller.dart';
import '../../features/workout/data/published_routine.dart';
import '../../features/workout/data/workout_session_repository.dart';
import '../../features/workout/domain/real_workout_contract.dart';
import '../../features/workout/data/real_workout_outbox_repository.dart';
import '../../infrastructure/firebase/firebase_real_workout_gateway.dart';
import '../di/real_workout_sync_store_factory.dart';
import 'squat_result_sync.dart';
import '../../features/workout/presentation/member/live_workout_screen.dart';
import '../../features/workout/presentation/member/workout_result_screen.dart';
import '../../infrastructure/audio/android_workout_audio.dart';
import '../../infrastructure/firebase/firebase_member_preferences_repository.dart';
import '../../infrastructure/pose/android_pose_camera.dart';
import '../../infrastructure/pose/blazepose_detector.dart';
import '../../infrastructure/pose/blazepose_contract.dart';
import '../di/workout_store_factory.dart';
import 'pose_preview_route.dart';

/// Measured development squat. Server opt-in is optional and precedes capture.
class RealSquatRoute extends StatefulWidget {
  const RealSquatRoute(
      {super.key,
      required this.routineId,
      required this.exercise,
      required this.scope,
      required this.consented,
      required this.setupConfirmed,
      this.requestServerUpload = false,
      this.storeFactory = createWorkoutStore});
  final String routineId;
  final PublishedRoutineExercise exercise;
  final SessionScope scope;
  final bool consented, setupConfirmed;
  final bool requestServerUpload;
  final Future<WorkoutSessionStore> Function(SessionScope) storeFactory;
  @override
  State<RealSquatRoute> createState() => _RealSquatRouteState();
}

class _RealSquatRouteState extends State<RealSquatRoute>
    with WidgetsBindingObserver {
  final _clock = Stopwatch()..start();
  RealSquatSessionController? _session;
  AndroidPoseCamera? _camera;
  WorkoutSessionRepository? _repository;
  RealWorkoutOutboxRepository? _outbox;
  WorkoutConsentAcknowledgement? _acknowledgement;
  String? _uploadNotice;
  StreamSubscription<AuthState>? _authSubscription;
  bool _opening = false;
  bool _foreground = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_opening && _session == null && _error == null) unawaited(_open());
  }

  Future<void> _open() async {
    _opening = true;
    final auth = context.read<AuthBloc>();
    bool authorized() =>
        auth.state.session?.scope == widget.scope &&
        AuthRolePolicy.canEnter(auth.state, allowed: const {AppRole.member});
    try {
      final binding = DevelopmentSquatBinding.resolve(
          organizationId: widget.scope.organizationId,
          exerciseId: widget.exercise.exerciseId,
          sets: widget.exercise.sets,
          reps: widget.exercise.reps);
      if (!authorized() ||
          !widget.consented ||
          !widget.setupConfirmed ||
          binding == null) {
        throw StateError(
            'This session requires a supported squat, active member account and camera setup consent.');
      }
      final store = await widget.storeFactory(widget.scope);
      if (!mounted || !authorized()) return;
      if (widget.requestServerUpload) {
        try {
          final syncStore = await createRealWorkoutSyncStore(widget.scope);
          if (!mounted || !authorized()) return;
          _outbox = RealWorkoutOutboxRepository(
              scope: widget.scope,
              activeScope: () => authorized() ? widget.scope : null,
              store: syncStore,
              gateway: FirebaseRealWorkoutGateway(scope: widget.scope),
              newRequestId: newWorkoutRequestId);
          _acknowledgement = await _outbox!.acknowledgeConsent();
        } catch (_) {/* No server grant: still permitted local capture. */}
        if (!mounted || !authorized()) return;
        _uploadNotice = _acknowledgement == null
            ? 'Upload consent could not be confirmed. This session will stay local.'
            : 'Upload consent is recorded. Model acceptance remains disabled pending physical validation.';
      }
      _repository = WorkoutSessionRepository(
          scope: widget.scope,
          store: store,
          uploadGateway: UnavailableWorkoutUploadGateway(),
          activeScope: () => authorized() ? widget.scope : null);
      _camera =
          AndroidPoseCamera(clockMicros: () => _clock.elapsedMicroseconds);
      final random = Random.secure();
      final id = List.generate(
              16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
          .join();
      if (_acknowledgement != null) {
        try {
          if (!await _outbox!.prepareCapture(id, _acknowledgement!)) {
            _acknowledgement = null;
          }
        } catch (_) {
          _acknowledgement = null;
        }
        if (_acknowledgement == null) {
          _uploadNotice =
              'Upload opt-in could not be saved. This session will stay local.';
        }
        if (!mounted || !authorized()) return;
      }
      final c = RealSquatSessionController(
          scope: widget.scope,
          activeScope: () => authorized() ? widget.scope : null,
          camera: _camera!,
          detectorFactory: () => BlazePoseDetector.create(),
          audioPort: AndroidWorkoutAudio(),
          repository: _repository!,
          clockMicros: () => _clock.elapsedMicroseconds,
          sessionId: id,
          exerciseId: widget.exercise.exerciseId,
          publishedRoutineId: widget.routineId,
          detectorId: 'blazepose-tflite',
          detectorVersion: BlazePoseModelContract.version,
          onSaved: _outbox == null
              ? null
              : (summary) async {
                  await _outbox!.enqueueFromIntent(summary);
                });
      _session = c;
      _authSubscription = auth.stream.listen((_) => c.accountChanged());
      setState(() {});
      await c.start(
          consented: true, setupConfirmed: true, foreground: _foreground);
      unawaited(_preferences(c));
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not open the local squat session. Check your account and retry.');
      }
    } finally {
      _opening = false;
    }
  }

  Future<void> _preferences(RealSquatSessionController c) async {
    try {
      final preferences =
          await FirebaseMemberPreferencesRepository(scope: widget.scope).load();
      c.applyPreferences(preferences);
    } catch (_) {
      /* Voice remains off unless explicitly enabled for this session. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    unawaited(_session?.setForeground(_foreground));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_authSubscription?.cancel());
    _session?.dispose();
    _repository?.dispose();
    _outbox?.dispose();
    _clock.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
          appBar: AppBar(title: const Text('Squat session')),
          body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error!),
            FilledButton(
                onPressed: () {
                  setState(() => _error = null);
                  unawaited(_open());
                },
                child: const Text('Retry'))
          ])));
    }
    if (_session == null) {
      return Scaffold(
          appBar: AppBar(title: const Text('Opening squat session')),
          body: const Center(child: CircularProgressIndicator()));
    }
    final auth = context.read<AuthBloc>();
    return LiveWorkoutScreen(
        realSession: _session,
        exerciseName: widget.exercise.name,
        targetRepetitions: widget.exercise.reps,
        resultBuilder: (summary) => ScopedSquatResult(
            summary: summary,
            auth: auth,
            syncEnabled: true,
            acknowledgement: _acknowledgement),
        uploadNotice: _uploadNotice,
        cameraViewport:
            PoseCameraViewport(camera: _camera!, session: _session!.preview));
  }
}

/// Result routes remain guarded after the camera route has been disposed.
class ScopedSquatResult extends StatelessWidget {
  const ScopedSquatResult(
      {super.key,
      required this.summary,
      required this.auth,
      this.syncEnabled = false,
      this.acknowledgement});
  final WorkoutSessionSummary summary;
  final AuthBloc auth;
  final bool syncEnabled;
  final WorkoutConsentAcknowledgement? acknowledgement;
  @override
  Widget build(BuildContext context) => BlocBuilder<AuthBloc, AuthState>(
      bloc: auth,
      builder: (context, state) => state.session?.scope == summary.scope &&
              AuthRolePolicy.canEnter(state, allowed: const {AppRole.member})
          ? syncEnabled
              ? SquatResultSync(
                  summary: summary,
                  auth: auth,
                  acknowledgement: acknowledgement)
              : WorkoutResultScreen.measured(summary: summary)
          : const Scaffold(
              body: Center(
                  child: Text('Sign in to view this account’s result.'))));
}
