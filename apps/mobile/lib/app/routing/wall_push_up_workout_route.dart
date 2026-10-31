import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show AppRole;
import 'package:gainpath_identity/gainpath_identity.dart';
import '../../features/workout/application/wall_push_up_workout_session.dart';
import '../../features/workout/data/workout_session_repository.dart';
import '../../features/workout/domain/workout_audio_port.dart';
import '../../features/workout/presentation/member/real_workout_view.dart';
import '../../infrastructure/audio/android_workout_audio.dart';
import '../../infrastructure/firebase/firebase_member_preferences_repository.dart';
import '../../infrastructure/pose/android_pose_camera.dart';
import '../../infrastructure/pose/blazepose_detector.dart';
import '../../infrastructure/pose/blazepose_contract.dart';
import '../../navigation/workout_navigation.dart';
import '../di/workout_store_factory.dart';
import 'pose_preview_route.dart' show PoseCameraViewport;
import 'real_squat_route.dart' show ScopedSquatResult;
import 'squat_result_sync.dart' show newWorkoutRequestId;

class WallPushUpWorkoutRoute extends StatefulWidget {
  const WallPushUpWorkoutRoute({super.key, required this.launch});
  final RealWorkoutLaunch launch;
  @override
  State<WallPushUpWorkoutRoute> createState() => _WallPushUpWorkoutRouteState();
}

class _WallPushUpWorkoutRouteState extends State<WallPushUpWorkoutRoute>
    with WidgetsBindingObserver {
  final _clock = Stopwatch()..start();
  WallPushUpWorkoutSession? _session;
  WorkoutSessionRepository? _repository;
  WorkoutVoicePreferences? _voicePreferences;
  AndroidPoseCamera? _camera;
  StreamSubscription<AuthState>? _auth;
  bool _opening = false, _foreground = true;
  String? _error;
  bool _authorized(AuthBloc auth) =>
      auth.state.session?.scope == widget.launch.scope &&
      AuthRolePolicy.canEnter(auth.state, allowed: const {AppRole.member});
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_opening && _session == null && _error == null) {
      unawaited(_open());
    }
  }

  Future<void> _open() async {
    _opening = true;
    final launch = widget.launch, auth = context.read<AuthBloc>();
    try {
      if (!_authorized(auth) || !launch.consented || !launch.setupConfirmed) {
        throw StateError(
            'Wall push-up capture requires current consent and account');
      }
      final store = await createWorkoutStore(launch.scope);
      if (!mounted || !_authorized(auth)) return;
      try {
        _voicePreferences = await createWorkoutVoicePreferences(launch.scope);
      } catch (_) {/* Session voice controls remain available. */}
      if (!mounted || !_authorized(auth)) return;
      _repository = WorkoutSessionRepository(
          scope: launch.scope,
          store: store,
          uploadGateway: UnavailableWorkoutUploadGateway(),
          activeScope: () => _authorized(auth) ? launch.scope : null);
      _camera =
          AndroidPoseCamera(clockMicros: () => _clock.elapsedMicroseconds);
      final session = WallPushUpWorkoutSession(
          scope: launch.scope,
          activeScope: () => _authorized(auth) ? launch.scope : null,
          camera: _camera!,
          detectorFactory: () => BlazePoseDetector.create(),
          audioPort: AndroidWorkoutAudio(),
          repository: _repository!,
          clockMicros: () => _clock.elapsedMicroseconds,
          sessionId: launch.sessionId ?? newWorkoutRequestId(),
          exerciseId: launch.exercise.exerciseId,
          publishedRoutineId: launch.routineId,
          detectorId: 'blazepose-tflite',
          detectorVersion: BlazePoseModelContract.version,
          sets: launch.exercise.sets,
          reps: launch.exercise.reps,
          saveVoiceMode: (mode) async {
            await _voicePreferences?.write(mode);
          });
      session.guidance.setRestSeconds(launch.exercise.restSeconds);
      _session = session;
      _auth = auth.stream.listen((_) => session.accountChanged());
      setState(() {});
      await session.start(
          consented: launch.consented,
          setupConfirmed: launch.setupConfirmed,
          foreground: _foreground);
      unawaited(_preferences(session));
    } catch (_) {
      _session?.dispose();
      _session = null;
      await _auth?.cancel();
      _auth = null;
      _repository?.dispose();
      _repository = null;
      if (mounted) {
        setState(() => _error =
            'Could not open the wall push-up session. Check your account and retry.');
      }
    } finally {
      _opening = false;
    }
  }

  Future<void> _preferences(WallPushUpWorkoutSession session) async {
    try {
      final mode = await _voicePreferences?.read();
      if (mode != null) {
        session.applySavedVoiceMode(mode);
        return;
      }
      session.applyPreferences(
          await FirebaseMemberPreferencesRepository(scope: widget.launch.scope)
              .load());
    } catch (_) {/* Voice remains muted unless enabled. */}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    unawaited(_session?.setForeground(_foreground));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_auth?.cancel());
    _session?.dispose();
    _repository?.dispose();
    _clock.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
          appBar: AppBar(title: const Text('Wall push-up session')),
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
    final session = _session;
    if (session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return RealWorkoutView(
        session: session,
        exerciseName: widget.launch.exercise.name,
        targetRepetitions: widget.launch.exercise.reps,
        routineContext: widget.launch.routineContext,
        viewport:
            PoseCameraViewport(camera: _camera!, session: session.preview),
        uploadNotice:
            'Wall push-up · provisional tracking. Results stay on this device; cloud upload and rewards are unavailable.',
        resultBuilder: (summary) => ScopedSquatResult(
            summary: summary,
            auth: context.read<AuthBloc>(),
            returnToRoutine: widget.launch.returnToRoutine));
  }
}
