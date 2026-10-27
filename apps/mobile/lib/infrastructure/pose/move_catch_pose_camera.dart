import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_pose/gainpath_pose.dart';
import '../../features/gamification/domain/move_catch_ports.dart';
import '../../features/workout/application/pose_preview_controller.dart';
import 'android_pose_camera.dart';
import 'blazepose_detector.dart';

/// Only fresh, visible shoulders and hips control this local game.
MoveCatchTorsoSample? moveCatchTorsoSample(PoseFrame frame,
    {required bool mirrored}) {
  if (frame.detectorId != 'blazepose-tflite' ||
      (frame.posePresence != null &&
          (!frame.posePresence!.isFinite || frame.posePresence! < .65))) {
    return null;
  }
  final points = [
    PoseLandmark.leftShoulder,
    PoseLandmark.rightShoulder,
    PoseLandmark.leftHip,
    PoseLandmark.rightHip,
  ].map(frame.landmark).toList();
  if (points.any((p) =>
      p == null ||
      !p.x.isFinite ||
      !p.y.isFinite ||
      p.x < 0 ||
      p.x > 1 ||
      p.y < 0 ||
      p.y > 1 ||
      !p.visibility.isFinite ||
      p.visibility < .65 ||
      (p.presence != null && (!p.presence!.isFinite || p.presence! < .65)))) {
    return null;
  }
  final shoulders = points[0]!.y + points[1]!.y;
  final hips = points[2]!.y + points[3]!.y;
  final width = (points[0]!.x - points[1]!.x).abs();
  if (width < .08 || width > .8 || (hips - shoulders) / 2 < .08) return null;
  final center = points.fold<double>(0, (sum, p) => sum + p!.x) / 4;
  return MoveCatchTorsoSample(
      centerX: mirrored ? 1 - center : center,
      shoulderWidth: width,
      capturedAtMicros: frame.capturedAtMicros);
}

/// Game-only partial-torso tracking. Learned offsets preserve the body centre
/// when only one anatomical side remains visible; no missing joint is invented.
class MoveCatchTorsoTracker {
  final Map<PoseLandmark, double> _offsets = {};
  double? _width;
  bool? _mirrored;
  int _capture = -1;
  void reset() {
    _offsets.clear();
    _width = null;
    _mirrored = null;
    _capture = -1;
  }

  MoveCatchTorsoSample? sample(PoseFrame frame,
      {required bool mirrored, required int nowMicros}) {
    if (frame.capturedAtMicros < 0 ||
        frame.capturedAtMicros <= _capture ||
        frame.capturedAtMicros > nowMicros ||
        nowMicros - frame.capturedAtMicros > 250000 ||
        frame.detectorId != 'blazepose-tflite') {
      return null;
    }
    if (_mirrored != null && _mirrored != mirrored) reset();
    _capture = frame.capturedAtMicros;
    _mirrored = mirrored;
    final full = moveCatchTorsoSample(frame, mirrored: false);
    if (full != null) {
      for (final id in [
        PoseLandmark.leftShoulder,
        PoseLandmark.rightShoulder,
        PoseLandmark.leftHip,
        PoseLandmark.rightHip
      ]) {
        _offsets[id] = frame.landmark(id)!.x - full.centerX;
      }
      _width = full.shoulderWidth;
      return MoveCatchTorsoSample(
          centerX: mirrored ? 1 - full.centerX : full.centerX,
          shoulderWidth: full.shoulderWidth,
          capturedAtMicros: full.capturedAtMicros);
    }
    if (_width == null ||
        (frame.posePresence != null &&
            (!frame.posePresence!.isFinite || frame.posePresence! < .6))) {
      return null;
    }
    bool usable(PosePoint? p) =>
        p != null &&
        p.x.isFinite &&
        p.y.isFinite &&
        p.x >= 0 &&
        p.x <= 1 &&
        p.y >= 0 &&
        p.y <= 1 &&
        p.visibility.isFinite &&
        p.visibility >= .6 &&
        (p.presence == null || (p.presence!.isFinite && p.presence! >= .6));
    final estimates = <double>[];
    for (final pair in [
      (PoseLandmark.leftShoulder, PoseLandmark.leftHip),
      (PoseLandmark.rightShoulder, PoseLandmark.rightHip)
    ]) {
      final shoulder = frame.landmark(pair.$1), hip = frame.landmark(pair.$2);
      if (usable(shoulder) && usable(hip) && hip!.y - shoulder!.y >= .08) {
        estimates.add(shoulder.x - _offsets[pair.$1]!);
        estimates.add(hip.x - _offsets[pair.$2]!);
      }
    }
    if (estimates.length < 2) return null;
    estimates.sort();
    if (estimates.last - estimates.first > _width! * .5) return null;
    final center =
        (estimates.reduce((a, b) => a + b) / estimates.length).clamp(0.0, 1.0);
    return MoveCatchTorsoSample(
        centerX: mirrored ? 1 - center : center,
        shoulderWidth: _width!,
        capturedAtMicros: frame.capturedAtMicros,
        fullTorso: false);
  }
}

class MoveCatchPoseCamera extends MoveCatchCamera {
  MoveCatchPoseCamera(
      {required SessionScope scope,
      required SessionScope? Function() activeScope,
      required int Function() clockMicros}) {
    source = AndroidPoseCamera(clockMicros: clockMicros);
    preview = PosePreviewController(
        scope: scope,
        activeScope: activeScope,
        camera: source,
        detectorFactory: BlazePoseDetector.create,
        clockMicros: clockMicros,
        onGeometryInvalidated: _tracker.reset,
        onRefined: (frame) {
          final sample = _tracker.sample(frame,
              mirrored: source.mirrored, nowMicros: clockMicros());
          if (sample != null) _onSample?.call(sample);
        });
    preview.addListener(_changed);
  }
  late final AndroidPoseCamera source;
  final _tracker = MoveCatchTorsoTracker();
  late final PosePreviewController preview;
  void Function(MoveCatchTorsoSample)? _onSample;
  Future<void>? _closing;
  PosePreviewPhase? _reportedPhase;
  String? _reportedError;
  Object? _reportedController;
  void _changed() {
    // Native CameraPreview paints its own frames. Pose arrivals already reach
    // the game through _onSample, so do not rebuild the camera tree per pose.
    if (_reportedPhase == preview.phase &&
        _reportedError == preview.errorMessage &&
        identical(_reportedController, source.controller)) {
      return;
    }
    _reportedPhase = preview.phase;
    _reportedError = preview.errorMessage;
    _reportedController = source.controller;
    notifyListeners();
  }

  @override
  bool get tracking => preview.phase == PosePreviewPhase.tracking;
  @override
  String? get error => preview.errorMessage;
  @override
  Future<void> start(void Function(MoveCatchTorsoSample) onSample) async {
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
