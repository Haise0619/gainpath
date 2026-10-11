import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_pose/gainpath_pose.dart';
import '../../../infrastructure/pose/pose_render_diagnostics.dart';
import '../../../infrastructure/pose/pose_quality_diagnostics.dart';

abstract interface class PoseCameraSource {
  Future<void> start(void Function(PoseInput) onFrame);
  void invalidate();
  Future<void> stop();
}

enum PosePreviewPhase { idle, opening, tracking, paused, failure, closed }

class PoseCameraPermissionDenied implements Exception {}

class PosePreviewController extends ChangeNotifier {
  PosePreviewController(
      {required this.scope,
      required this.activeScope,
      required this.camera,
      required this.detectorFactory,
      required this.clockMicros,
      this.onRefined,
      this.onGeometryInvalidated,
      PoseQualityDiagnostics? quality})
      : quality = quality ?? PoseQualityDiagnostics(clockMicros: clockMicros);
  final PoseQualityDiagnostics quality;
  final SessionScope scope;
  final SessionScope? Function() activeScope;
  final PoseCameraSource camera;
  final Future<ManagedPoseDetector> Function() detectorFactory;
  final int Function() clockMicros;

  /// Delivered fresh inverse-ROI pose before preview smoothing. No history.
  final void Function(PoseFrame)? onRefined;
  final void Function()? onGeometryInvalidated;
  PosePreviewPhase phase = PosePreviewPhase.idle;
  PoseFrame? frame;
  String? errorMessage;
  ManagedPoseDetector? _detector;
  LatestPoseProcessor<PoseInput, PoseFrame>? _scheduler;
  // Step 2P diagnostic experiment only; normal/release builds retain beta .3.
  static const _beta12Experiment = !kReleaseMode &&
      bool.fromEnvironment('GAINPATH_POSE_QUALITY_DEBUG') &&
      bool.fromEnvironment('GAINPATH_POSE_BETA12_EXPERIMENT');
  final _filter = PoseFrameFilter(beta: _beta12Experiment ? 1.2 : .3);
  final _activeTime = Stopwatch();
  Future<void> _tail = Future.value();
  Future<void>? _closing;
  Timer? _freshnessTimer;
  static const _maxFrameAgeMicros = 250000;
  int _revision = 0, receivedFrames = 0, displayedFrames = 0;
  int? _processingInputMicros;
  (int, int, int)? _geometry;
  Map<String, Object?> _debugDecoded = {};
  int _debugEmptyPoseFrames = 0, _debugExpiredOverlays = 0;
  double? _debugLastPosePresence;
  bool _disposed = false,
      _consented = false,
      _manualPause = false,
      _background = false,
      _resumeOnForeground = false;
  bool get _active =>
      !_disposed && phase != PosePreviewPhase.closed && activeScope() == scope;
  int get activeTimeMicros => _activeTime.elapsedMicroseconds;
  void startLagPhase(String name) {
    if (phase != PosePreviewPhase.tracking) return;
    quality.startCapture(name);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Map<String, Object> get diagnostics => {
        if (quality.enabled) 'quality': quality.countersSnapshot,
        if (quality.enabled)
          'filterConfiguration': {
            'beta': _filter.beta,
            'minCutoff': _filter.minCutoff,
            'derivativeCutoff': OneEuroFilter().dCutoff,
            'minimumVisibility': _filter.minimumVisibility,
            'resetAfterMicros': _filter.resetAfterMicros,
            'experiment':
                _beta12Experiment ? 'step2p_beta12' : 'control_beta03',
          },
        if (kDebugMode)
          'poseHealth': {
            'emptyPoseFrames': _debugEmptyPoseFrames,
            'expiredOverlays': _debugExpiredOverlays,
            'overlayCapturedAtMicros': frame?.capturedAtMicros,
            'overlayAgeMillis': frame == null
                ? null
                : (clockMicros() - frame!.capturedAtMicros) / 1000,
            'lastPosePresence': _debugLastPosePresence
          },
        if (poseRenderDebugEnabled)
          'renderUi': {
            'decoded': _debugDecoded,
            'filtered': poseImageRenderingSummary(frame),
            'emptyPoseFrames': _debugEmptyPoseFrames,
            'expiredOverlays': _debugExpiredOverlays,
            'overlayAgeMillis': frame == null
                ? null
                : (clockMicros() - frame!.capturedAtMicros) / 1000,
          },
        if (camera is PoseDetectorDiagnostics)
          ...(camera as PoseDetectorDiagnostics).diagnostics,
        'landmarkCount': frame?.landmarks.length ?? 0,
        if (_detector is PoseDetectorDiagnostics)
          ...(_detector as PoseDetectorDiagnostics).diagnostics,
        'receivedFrames': receivedFrames,
        'displayedFrames': displayedFrames,
        'processedFrames': _scheduler?.processedFrames ?? 0,
        'droppedFrames': _scheduler?.droppedFrames ?? 0,
        'staleFrames': _scheduler?.staleFrames ?? 0,
        'overlayFps': _activeTime.elapsedMicroseconds == 0
            ? 0.0
            : displayedFrames * 1000000 / _activeTime.elapsedMicroseconds,
      };
  Future<void> _enqueue(Future<void> Function() action) {
    final next = _tail.then((_) => action());
    _tail = next.catchError((Object e) {});
    return next;
  }

  Future<void> start({required bool consented}) async {
    if (!consented ||
        phase == PosePreviewPhase.closed ||
        _disposed ||
        _background ||
        phase == PosePreviewPhase.opening ||
        phase == PosePreviewPhase.tracking) {
      return;
    }
    if (!_active) {
      await close();
      return;
    }
    _consented = true;
    _manualPause = false;
    errorMessage = null;
    final revision = ++_revision;
    phase = PosePreviewPhase.opening;
    quality.transition('lifecycle_opening');
    _notify();
    await _enqueue(() async {
      try {
        if (!_active || revision != _revision) return;
        if (_detector == null) {
          final detector = await detectorFactory();
          if (!_active || revision != _revision) {
            await detector.close();
            return;
          }
          _detector = detector;
          _scheduler = LatestPoseProcessor<PoseInput, PoseFrame>(
              maxAgeMicros: _maxFrameAgeMicros,
              clockMicros: clockMicros,
              timestampMicros: (i) => i.timestampMicros,
              process: (input) async {
                _processingInputMicros = input.timestampMicros;
                final start = clockMicros();
                quality.sample('queueAgeMicros', start - input.timestampMicros);
                final result = await detector.detect(input);
                quality.sample('hostProcessingMicros', clockMicros() - start);
                return result;
              },
              onDiscard: quality.enabled
                  ? (input, reason) =>
                      quality.discard(input.timestampMicros, reason)
                  : null,
              onResult: (pose) {
                if (!_active) {
                  unawaited(close());
                  return;
                }
                if (poseRenderDebugEnabled) {
                  _debugDecoded = poseImageRenderingSummary(pose);
                }
                if (kDebugMode) {
                  if (pose.landmarks.isEmpty) _debugEmptyPoseFrames++;
                  _debugLastPosePresence = pose.posePresence;
                }
                final filterTimer = Stopwatch()..start();
                frame = _filter.filter(pose);
                quality.delivered(frame!, filterTimer.elapsedMicroseconds,
                    refined: pose);
                if (quality.lag.enabled) {
                  final diagnosticTimer = Stopwatch()..start();
                  quality.lag.delivered(pose, frame!,
                      quality.traceFor(pose.capturedAtMicros), clockMicros());
                  quality.sample('jointLagDeliveryMicros',
                      diagnosticTimer.elapsedMicroseconds);
                }
                displayedFrames++;
                onRefined?.call(pose);
                _notify();
              },
              onError: (error, stack) {
                if (!_active) {
                  unawaited(close());
                  return;
                }
                _scheduler?.suspend();
                _filter.reset();
                quality.overlayCleared('pipeline_error', frame,
                    inputTimestamp: _processingInputMicros);
                frame = null;
                quality.lag.clear();
                quality.transition('pipeline_error',
                    details: {'type': error.runtimeType.toString()});
                _activeTime.stop();
                _freshnessTimer?.cancel();
                camera.invalidate();
                phase = PosePreviewPhase.failure;
                errorMessage =
                    'Pose tracking stopped. Retry the camera preview.';
                _notify();
                unawaited(_enqueue(() async {
                  await camera.stop();
                  await _scheduler?.drain();
                  await _detector?.reset();
                }));
              });
        }
        _filter.reset();
        _geometry = null;
        _scheduler!.resume();
        await camera.start((input) {
          if (!_active || revision != _revision || _background) return;
          final image = input.image;
          final geometry = image == null
              ? null
              : (image.width, image.height, image.rotationDegrees);
          if (_geometry != null && geometry != _geometry) {
            // Reject an in-flight result from the old orientation, including
            // 180° turns where width/height alone do not change.
            _scheduler!.suspend();
            _scheduler!.resume();
            _filter.reset();
            quality.overlayCleared('camera_geometry_invalidation', frame);
            frame = null;
            quality.transition('camera_geometry_invalidation');
            quality.lag.clear();
            onGeometryInvalidated?.call();
            _notify();
          }
          _geometry = geometry;
          receivedFrames++;
          _scheduler!.add(input);
        });
        if (!_active || revision != _revision) return;
        phase = PosePreviewPhase.tracking;
        _freshnessTimer?.cancel();
        _freshnessTimer =
            Timer.periodic(const Duration(milliseconds: 100), (_) {
          if (quality.lag.finishIfExpired()) _notify();
          if (quality.blanks.finishIfExpired()) _notify();
          final pose = frame;
          if (pose != null &&
              clockMicros() - pose.capturedAtMicros > _maxFrameAgeMicros) {
            if (kDebugMode) _debugExpiredOverlays++;
            quality.count(pose.landmarks.isEmpty
                ? 'expiredEmptyFrame'
                : 'expiredOverlay');
            quality.transition('freshness_expiry',
                timestamp: pose.capturedAtMicros,
                details: {
                  'ageMicros': clockMicros() - pose.capturedAtMicros,
                  'wasEmpty': pose.landmarks.isEmpty,
                  'latestDiscard': quality.lastDiscard
                });
            quality.overlayCleared('freshness_expiry', pose, watchdog: true);
            frame = null;
            quality.lag.filterReset('freshness_expiry');
            _filter.reset();
            _notify();
          }
        });
        _activeTime.start();
        _notify();
      } catch (error) {
        _freshnessTimer?.cancel();
        _scheduler?.suspend();
        camera.invalidate();
        await camera.stop().catchError((Object _) {});
        if (_active && revision == _revision) {
          quality.transition(error is PoseCameraPermissionDenied
              ? 'camera_permission_denied'
              : 'camera_or_model_initialization_error');
          phase = PosePreviewPhase.failure;
          errorMessage = error is PoseCameraPermissionDenied
              ? 'Camera permission is denied. Enable it in Android settings to try again.'
              : 'Camera or pose model unavailable. Retry the preview.';
          _notify();
        }
      }
    });
  }

  Future<void> pause({bool manual = true}) async {
    if (phase == PosePreviewPhase.closed || _disposed) return;
    if (manual) _manualPause = true;
    quality
        .transition(manual ? 'lifecycle_manual_pause' : 'lifecycle_background');
    _freshnessTimer?.cancel();
    ++_revision;
    _scheduler?.suspend();
    camera.invalidate();
    quality.overlayCleared(
        manual ? 'lifecycle_manual_pause' : 'lifecycle_background', frame);
    quality.blanks.finish();
    frame = null;
    quality.lag.clear();
    _filter.reset();
    _activeTime.stop();
    phase = PosePreviewPhase.paused;
    _notify();
    await _enqueue(() async {
      await camera.stop();
      await _scheduler?.drain();
      await _detector?.reset();
    });
  }

  Future<void> resume() async {
    if (_background) return;
    _manualPause = false;
    await start(consented: _consented);
  }

  Future<void> background() async {
    if (_background || phase == PosePreviewPhase.closed) return;
    _background = true;
    _resumeOnForeground =
        phase == PosePreviewPhase.tracking || phase == PosePreviewPhase.opening;
    await pause(manual: false);
  }

  Future<void> foreground() async {
    _background = false;
    if (_resumeOnForeground && !_manualPause) {
      _resumeOnForeground = false;
      await resume();
    }
  }

  Future<void> accountChanged() async {
    if (activeScope() != scope) {
      quality.transition('lifecycle_logout');
      quality.overlayCleared('lifecycle_logout', frame);
      await close();
    }
  }

  Future<void> close() {
    if (_closing != null) return _closing!;
    _freshnessTimer?.cancel();
    ++_revision;
    phase = PosePreviewPhase.closed;
    quality.transition('lifecycle_closed');
    quality.overlayCleared('lifecycle_closed', frame);
    quality.clearCoordinates();
    frame = null;
    _scheduler?.dispose();
    _filter.reset();
    _activeTime.stop();
    camera.invalidate();
    _notify();
    return _closing = _enqueue(() async {
      try {
        await camera.stop();
      } finally {
        await _scheduler?.drain();
        await _detector?.close();
        _detector = null;
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(close().catchError((Object _) {}));
    super.dispose();
  }
}
