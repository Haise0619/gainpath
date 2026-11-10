import 'dart:async';
import 'dart:convert';
import 'dart:ui' show FrameTiming;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show AppRole, SessionScope;
import 'package:gainpath_identity/gainpath_identity.dart';
import '../../features/workout/application/pose_preview_controller.dart';
import '../../features/workout/presentation/member/live_workout_screen.dart';
import '../../features/workout/presentation/member/widgets/pose_landmark_painter.dart';
import '../../infrastructure/pose/android_pose_camera.dart';
import '../../infrastructure/pose/blazepose_detector.dart';
import '../../infrastructure/pose/pose_render_diagnostics.dart';
import '../../infrastructure/pose/pose_quality_diagnostics.dart';
import '../../infrastructure/pose/pose_joint_lag_diagnostics.dart';
import '../di/workout_preferences_factory.dart';
import '../../features/workout/application/workout_preferences_controller.dart';
import '../../features/workout/presentation/member/workout_ai_consent_guard.dart';
import '../../features/workout/presentation/member/workout_privacy_settings_screen.dart';

typedef PreviewControllerFactory = PosePreviewController Function(
    SessionScope scope,
    SessionScope? Function() activeScope,
    int Function() clock);

/// Explicit local preview; it never creates a workout session or upload gateway.
class PosePreviewRoute extends StatefulWidget {
  const PosePreviewRoute(
      {super.key,
      this.preferencesFactory = createWorkoutPreferences,
      this.controllerFactory,
      this.viewportBuilder});
  final WorkoutPreferencesFactory preferencesFactory;

  /// Hardware-free test seam; production uses Android camera/permission checks.
  final PreviewControllerFactory? controllerFactory;
  final Widget Function(PosePreviewController)? viewportBuilder;
  @override
  State<PosePreviewRoute> createState() => _PosePreviewRouteState();
}

class _PosePreviewRouteState extends State<PosePreviewRoute>
    with WidgetsBindingObserver {
  PosePreviewController? _session;
  AndroidPoseCamera? _camera;
  StreamSubscription<AuthState>? _auth;
  Timer? _metrics;
  final _clock = Stopwatch()..start();
  final _render = PoseRenderDiagnostics();
  PoseQualityDiagnostics? _quality;
  AuthBloc? _authBloc;
  SessionScope? _scope;
  WorkoutPreferencesController? _preferences;
  bool _opening = false, _revoked = false, _launchInterrupted = false;
  bool _foreground = true;
  bool get _authorized =>
      mounted &&
      !_revoked &&
      _authBloc != null &&
      _scope != null &&
      _authBloc?.state.session?.scope == _scope &&
      AuthRolePolicy.canEnter(_authBloc!.state,
          allowed: const {AppRole.member});

  @override
  void initState() {
    super.initState();
    _foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _launchInterrupted = !_foreground;
    WidgetsBinding.instance.addObserver(this);
  }

  void _revoke() {
    _revoked = true;
    // close invalidates generations and camera callbacks synchronously, before
    // the consent guard's next build unmounts its capture child.
    unawaited(_session?.close().catchError((Object _) {}));
    if (mounted) setState(() {});
  }

  void _consentChanged() {
    if (_preferences?.validConsent != true) _revoke();
  }

  void _frameTimings(List<FrameTiming> frames) {
    for (final frame in frames) {
      _quality?.sample(
          'flutterBuildMicros', frame.buildDuration.inMicroseconds);
      _quality?.sample(
          'flutterRasterMicros', frame.rasterDuration.inMicroseconds);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opening) return;
    _opening = true;
    final auth = context.read<AuthBloc>();
    if (!AuthRolePolicy.canEnter(auth.state, allowed: const {AppRole.member})) {
      return;
    }
    _authBloc = auth;
    _scope = auth.state.session!.scope;
    _auth = auth.stream.listen((_) {
      if (!_authorized) _revoke();
    });
    unawaited(_open());
  }

  Future<void> _open() async {
    try {
      final preferences = await widget.preferencesFactory(_scope!);
      await preferences.load();
      if (!_authorized || _launchInterrupted) return;
      if (preferences.scope != _scope) {
        _revoke();
        return;
      }
      _preferences = preferences;
      preferences.addListener(_consentChanged);
      if (!preferences.validConsent) {
        _revoke();
        return;
      }
      _createSession();
      if (mounted) setState(() {});
      await _session!.start(consented: preferences.validConsent);
    } catch (_) {
      if (mounted) _revoke();
    }
  }

  void _createSession() {
    _quality =
        PoseQualityDiagnostics(clockMicros: () => _clock.elapsedMicroseconds);
    if (_quality!.enabled) {
      WidgetsBinding.instance.addTimingsCallback(_frameTimings);
    }
    if (widget.controllerFactory == null) {
      _camera = AndroidPoseCamera(
          quality: _quality,
          clockMicros: () => _clock.elapsedMicroseconds,
          preferFront: const String.fromEnvironment('GAINPATH_POSE_LENS',
                  defaultValue: 'front') !=
              'back');
    }
    SessionScope? activeScope() =>
        _authorized && _preferences?.validConsent == true ? _scope : null;
    _session = widget.controllerFactory
            ?.call(_scope!, activeScope, () => _clock.elapsedMicroseconds) ??
        PosePreviewController(
            scope: _scope!,
            activeScope: activeScope,
            camera: _camera!,
            detectorFactory: () => BlazePoseDetector.create(quality: _quality),
            quality: _quality,
            clockMicros: () => _clock.elapsedMicroseconds);
    // Aggregate metrics normally; representative joints only with the
    // explicitly enabled temporary development rendering trace.
    if (kDebugMode || poseQualityDebugEnabled) {
      _metrics = Timer.periodic(const Duration(seconds: 5), (_) {
        if (_session!.phase != PosePreviewPhase.closed) {
          final snapshot = _session!.diagnostics;
          final aggregate = Map<String, Object>.of(snapshot)
            ..remove('renderUi')
            ..remove('renderDecoder')
            ..remove('quality');
          aggregate['primarySkeletonSource'] = poseRefinedSkeletonDebugEnabled
              ? 'refined_diagnostic'
              : 'filtered';
          debugPrint('POSE_FOUNDATION_METRICS ${jsonEncode(aggregate)}');
          printPoseRenderingTrace(snapshot, _render);
          if (_quality!.enabled) {
            final quality = _quality!.snapshot(
                activeMicros: _session!.activeTimeMicros,
                received: _session!.receivedFrames,
                processed: snapshot['processedFrames'] as int,
                delivered: _session!.displayedFrames);
            printPoseQualitySnapshot(_quality!, quality);
          }
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground &&
        (_session == null || _session!.phase == PosePreviewPhase.opening)) {
      _launchInterrupted = true;
      _revoke();
    } else if (!_authorized || _preferences?.validConsent != true) {
      _revoke();
    } else if (_foreground) {
      unawaited(_session?.foreground().catchError((Object _) {}));
    } else {
      unawaited(_session?.background().catchError((Object _) {}));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _preferences?.removeListener(_consentChanged);
    _metrics?.cancel();
    if (_quality?.enabled == true) {
      WidgetsBinding.instance.removeTimingsCallback(_frameTimings);
    }
    unawaited(_auth?.cancel());
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _scope == null
      ? const Scaffold(
          body:
              Center(child: Text('Sign in as a member to preview the camera.')))
      : WorkoutAiConsentGuard(
          scope: _scope!,
          preferencesFactory: widget.preferencesFactory,
          child: _revoked || _launchInterrupted
              ? const Scaffold(
                  body: Center(
                      child: Text(
                          'Preview stopped. Return and reopen Preview when authorized.')))
              : _session == null
                  ? const Scaffold(
                      body: Center(child: CircularProgressIndicator()))
                  : LiveWorkoutScreen(
                      cameraSession: _session!,
                      cameraViewport: widget.viewportBuilder?.call(_session!) ??
                          PoseCameraViewport(
                              camera: _camera!,
                              session: _session!,
                              diagnostics: _render)));
}

class PoseCameraViewport extends StatelessWidget {
  const PoseCameraViewport(
      {super.key,
      required this.camera,
      required this.session,
      this.diagnostics});
  final PoseRenderDiagnostics? diagnostics;
  final AndroidPoseCamera camera;
  final PosePreviewController session;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: session, builder: (context, _) => _buildCamera(context));

  Widget _buildCamera(BuildContext context) {
    final controller = camera.controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<CameraValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final landscape =
              value.deviceOrientation == DeviceOrientation.landscapeLeft ||
                  value.deviceOrientation == DeviceOrientation.landscapeRight;
          final raw = value.previewSize!;
          final width = landscape ? raw.width : raw.height,
              height = landscape ? raw.height : raw.width;
          final frame = session.frame;
          // Some devices negotiate different preview/analysis aspects. Do not
          // stretch landmarks onto a different field of view; verify on hardware.
          final aligned = frame == null ||
              ((frame.imageWidth / frame.imageHeight) - (width / height))
                      .abs() <
                  .02;
          diagnostics?.viewport(frame,
              width: width, height: height, aspectCompatible: aligned);
          return LayoutBuilder(builder: (context, constraints) {
            Rect? performanceViewport;
            if (session.performance != null) {
              final sx = constraints.maxWidth / width,
                  sy = constraints.maxHeight / height;
              final scale = sx > sy ? sx : sy;
              performanceViewport = Rect.fromLTWH(
                  -(constraints.maxWidth - width * scale) / 2 / scale,
                  -(constraints.maxHeight - height * scale) / 2 / scale,
                  constraints.maxWidth / scale,
                  constraints.maxHeight / scale);
            }
            if (session.quality.enabled) {
              final sx = constraints.maxWidth / width,
                  sy = constraints.maxHeight / height;
              final scale = sx > sy ? sx : sy;
              session.quality.viewport = {
                'width': constraints.maxWidth,
                'height': constraints.maxHeight,
                'imageWidth': frame?.imageWidth,
                'imageHeight': frame?.imageHeight,
                'coverScale': scale,
                'coverOffsetX': (constraints.maxWidth - width * scale) / 2,
                'coverOffsetY': (constraints.maxHeight - height * scale) / 2,
                'aspectCompatible': aligned,
                'mirrored': camera.mirrored
              };
              if (!aligned) {
                session.quality.transition('preview_aspect_mismatch');
              }
            }
            return ClipRect(
                child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                        width: width,
                        height: height,
                        child: CameraPreview(controller,
                            child: CustomPaint(
                                painter: PoseLandmarkPainter(
                                    frame: aligned ? frame : null,
                                    sourceFrame: frame,
                                    blankReason: aligned
                                        ? null
                                        : 'preview_aspect_mismatch',
                                    mirrored: camera.mirrored,
                                    performance: session.performance,
                                    performanceViewport: performanceViewport,
                                    quality: session.quality,
                                    diagnostics: diagnostics))))));
          });
        });
  }
}
