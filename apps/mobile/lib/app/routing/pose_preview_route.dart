import 'dart:async';
import 'dart:convert';
import 'dart:ui' show FrameTiming;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show AppRole;
import 'package:gainpath_identity/gainpath_identity.dart';
import '../../features/workout/application/pose_preview_controller.dart';
import '../../features/workout/presentation/member/live_workout_screen.dart';
import '../../features/workout/presentation/member/widgets/pose_landmark_painter.dart';
import '../../infrastructure/pose/android_pose_camera.dart';
import '../../infrastructure/pose/blazepose_detector.dart';
import '../../infrastructure/pose/pose_render_diagnostics.dart';
import '../../infrastructure/pose/pose_quality_diagnostics.dart';
import '../../infrastructure/pose/pose_joint_lag_diagnostics.dart';

/// Explicit local preview; it never creates a workout session or upload gateway.
class PosePreviewRoute extends StatefulWidget {
  const PosePreviewRoute({super.key});
  @override
  State<PosePreviewRoute> createState() => _PosePreviewRouteState();
}

class _PosePreviewRouteState extends State<PosePreviewRoute> {
  PosePreviewController? _session;
  AndroidPoseCamera? _camera;
  StreamSubscription<AuthState>? _auth;
  Timer? _metrics;
  final _clock = Stopwatch()..start();
  final _render = PoseRenderDiagnostics();
  PoseQualityDiagnostics? _quality;
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
    if (_session != null) return;
    final auth = context.read<AuthBloc>();
    if (!AuthRolePolicy.canEnter(auth.state, allowed: const {AppRole.member})) {
      return;
    }
    _quality =
        PoseQualityDiagnostics(clockMicros: () => _clock.elapsedMicroseconds);
    if (_quality!.enabled) {
      WidgetsBinding.instance.addTimingsCallback(_frameTimings);
    }
    _camera = AndroidPoseCamera(
        quality: _quality,
        clockMicros: () => _clock.elapsedMicroseconds,
        preferFront: const String.fromEnvironment('GAINPATH_POSE_LENS',
                defaultValue: 'front') !=
            'back');
    _session = PosePreviewController(
        scope: auth.state.session!.scope,
        activeScope: () => auth.state.session?.scope,
        camera: _camera!,
        detectorFactory: () => BlazePoseDetector.create(quality: _quality),
        quality: _quality,
        clockMicros: () => _clock.elapsedMicroseconds);
    _auth = auth.stream.listen((_) => unawaited(_session!.accountChanged()));
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
    unawaited(_session!.start(consented: true));
  }

  @override
  void dispose() {
    _metrics?.cancel();
    if (_quality?.enabled == true) {
      WidgetsBinding.instance.removeTimingsCallback(_frameTimings);
    }
    unawaited(_auth?.cancel());
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _session == null
      ? const Scaffold(
          body:
              Center(child: Text('Sign in as a member to preview the camera.')))
      : LiveWorkoutScreen(
          cameraSession: _session!,
          cameraViewport: PoseCameraViewport(
              camera: _camera!, session: _session!, diagnostics: _render));
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
                                    quality: session.quality,
                                    diagnostics: diagnostics))))));
          });
        });
  }
}
