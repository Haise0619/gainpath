import 'dart:async';
import 'dart:math';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_pose/gainpath_pose.dart';
import '../../features/gamification/domain/reach_tap.dart';
import '../../features/gamification/domain/reach_tap_camera.dart';
import '../../features/gamification/domain/reach_tap_projection.dart';
import '../../features/workout/application/pose_preview_controller.dart';
import 'android_pose_camera.dart';
import 'blazepose_detector.dart';
import 'blazepose_contract.dart';

/// Refined BlazePose coordinates have already been rotated to upright by the
/// existing image/ROI pipeline. Mirror exactly once, then apply the same centered
/// cover crop as the camera viewport. Never rotate an upright result again.
ReachTapSample? reachTapSample(PoseFrame frame,
    {required double boardWidth,
    required double boardHeight,
    required double previewWidth,
    required double previewHeight,
    required bool mirrored,
    String orientation = ''}) {
  if (frame.detectorId != 'blazepose-tflite' ||
      frame.modelVersion != BlazePoseModelContract.version ||
      frame.isMirrored ||
      frame.imageWidth <= 0 ||
      frame.imageHeight <= 0 ||
      ![boardWidth, boardHeight, previewWidth, previewHeight]
          .every((v) => v.isFinite && v > 0) ||
      ((frame.imageWidth / frame.imageHeight) - (previewWidth / previewHeight))
              .abs() >=
          .02 ||
      (frame.posePresence != null &&
          (!frame.posePresence!.isFinite ||
              frame.posePresence! < .65 ||
              frame.posePresence! > 1))) {
    return null;
  }
  final transform = ReachTapProjection(
      imageWidth: frame.imageWidth.toDouble(),
      imageHeight: frame.imageHeight.toDouble(),
      viewportWidth: boardWidth,
      viewportHeight: boardHeight,
      mirrored: mirrored);
  if (!transform.compatible) return null;
  Point<double>? point(PoseLandmark id) {
    final p = frame.landmark(id);
    if (p == null ||
        ![p.x, p.y, p.z, p.visibility, p.presence ?? 1]
            .every((v) => v.isFinite) ||
        p.x < 0 ||
        p.x > 1 ||
        p.y < 0 ||
        p.y > 1 ||
        p.visibility < .65 ||
        p.visibility > 1 ||
        (p.presence ?? 1) < .65 ||
        (p.presence ?? 1) > 1) {
      return null;
    }
    final mapped = transform.map(Point<double>(p.x, p.y));
    // A cropped-out real hand is unavailable, not clamped back onto the screen.
    return mapped.x < 0 || mapped.x > 1 || mapped.y < 0 || mapped.y > 1
        ? null
        : mapped;
  }

  final ls = point(PoseLandmark.leftShoulder),
      rs = point(PoseLandmark.rightShoulder),
      le = point(PoseLandmark.leftElbow),
      re = point(PoseLandmark.rightElbow),
      lh = point(PoseLandmark.leftWrist),
      rh = point(PoseLandmark.rightWrist),
      lp = point(PoseLandmark.leftHip),
      rp = point(PoseLandmark.rightHip);
  // Retain independent observed hands. Full setup still requires both elbows
  // and wrists in the engine; an occluded opposite hand/elbow must not erase
  // a real visible scoring hand during play. Never infer or clamp a missing hand.
  if ([ls, rs, lp, rp].contains(null)) return null;
  return ReachTapSample(
      leftShoulder: ls,
      rightShoulder: rs,
      leftElbow: le,
      rightElbow: re,
      leftHand: lh,
      rightHand: rh,
      leftHip: lp,
      rightHip: rp,
      capturedAtMicros: frame.capturedAtMicros,
      boardWidth: boardWidth,
      boardHeight: boardHeight,
      geometryKey:
          '${frame.detectorId}/${frame.modelVersion}/${frame.imageWidth}/${frame.imageHeight}/$mirrored/$boardWidth/$boardHeight/$orientation');
}

class ReachTapPoseCamera extends ReachTapCamera {
  ReachTapPoseCamera(
      {required SessionScope scope,
      required SessionScope? Function() activeScope,
      required this.clockMicros}) {
    source = AndroidPoseCamera(clockMicros: clockMicros);
    preview = PosePreviewController(
        scope: scope,
        activeScope: activeScope,
        camera: source,
        detectorFactory: BlazePoseDetector.create,
        clockMicros: clockMicros,
        onGeometryInvalidated: () => _onSample?.call(null),
        onRefined: _consume);
    preview.addListener(_changed);
  }
  final int Function() clockMicros;
  late final AndroidPoseCamera source;
  late final PosePreviewController preview;
  void Function(ReachTapSample?)? _onSample;
  double _width = 0, _height = 0;
  Object? _controller;
  PosePreviewPhase? _phase;
  String? _error;
  Future<void>? _closing;
  void configureViewport(double width, double height) {
    if (_width == width && _height == height) return;
    _width = width;
    _height = height;
    // Layout may run during build. Cancel prior-geometry gameplay after build.
    scheduleMicrotask(() => _onSample?.call(null));
  }

  void _consume(PoseFrame frame) {
    final value = source.controller?.value, raw = value?.previewSize;
    if (raw == null || value == null) {
      _onSample?.call(null);
      return;
    }
    final landscape = value.deviceOrientation.name.startsWith('landscape');
    _onSample?.call(reachTapSample(frame,
        boardWidth: _width,
        boardHeight: _height,
        previewWidth: landscape ? raw.width : raw.height,
        previewHeight: landscape ? raw.height : raw.width,
        mirrored: source.mirrored,
        orientation: value.deviceOrientation.name));
  }

  void _changed() {
    if (preview.phase != PosePreviewPhase.tracking || preview.frame == null) {
      _onSample?.call(null);
    }
    if (_phase == preview.phase &&
        _error == preview.errorMessage &&
        identical(_controller, source.controller)) {
      return;
    }
    _phase = preview.phase;
    _error = preview.errorMessage;
    _controller = source.controller;
    notifyListeners();
  }

  @override
  bool get tracking => preview.phase == PosePreviewPhase.tracking;
  @override
  String? get error => preview.errorMessage;
  @override
  Future<void> start(void Function(ReachTapSample?) onSample) async {
    _onSample = onSample;
    await preview.start(consented: true);
    if (preview.phase == PosePreviewPhase.failure) {
      throw StateError('Camera unavailable');
    }
  }

  @override
  Future<void> pause() => preview.pause();
  @override
  Future<void> resume() async {
    await preview.resume();
    if (preview.phase == PosePreviewPhase.failure) {
      throw StateError('Camera unavailable');
    }
  }

  @override
  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    _onSample = null;
    preview.removeListener(_changed);
    await preview.close();
    preview.dispose();
  }
}
