import 'one_euro_filter.dart';
import 'pose_frame.dart';

/// Independent x/y/z One Euro streams; confidence is observed, not invented.
class PoseFrameFilter {
  PoseFrameFilter(
      {this.resetAfterMicros = 500000,
      this.minCutoff = 1,
      this.beta = 0.3,
      this.minimumVisibility = 0.5});
  final int resetAfterMicros;
  final double minCutoff, beta, minimumVisibility;
  final _image = <PoseLandmark, List<OneEuroFilter>>{};
  final _world = <PoseLandmark, List<OneEuroFilter>>{};
  PoseFrame? _last;

  void reset() {
    _image.clear();
    _world.clear();
    _last = null;
  }

  PoseFrame filter(PoseFrame frame) {
    final last = _last;
    if (last != null) {
      if (frame.capturedAtMicros <= last.capturedAtMicros) {
        throw ArgumentError('Pose capture time must increase.');
      }
      if (frame.capturedAtMicros - last.capturedAtMicros > resetAfterMicros ||
          frame.imageWidth != last.imageWidth ||
          frame.imageHeight != last.imageHeight ||
          frame.detectorId != last.detectorId ||
          frame.modelVersion != last.modelVersion) {
        reset();
      }
    }
    final time = frame.capturedAtMicros / 1000000;
    Map<PoseLandmark, PosePoint> apply(Map<PoseLandmark, PosePoint> points,
        Map<PoseLandmark, List<OneEuroFilter>> filters) {
      filters.removeWhere((key, value) => !points.containsKey(key));
      final result = <PoseLandmark, PosePoint>{};
      for (final entry in points.entries) {
        final p = entry.value;
        if (![p.x, p.y, p.z, p.visibility, p.presence ?? 1]
            .every((v) => v.isFinite)) {
          filters.remove(entry.key);
          continue;
        }
        if (p.visibility < minimumVisibility ||
            (p.presence ?? 1) < minimumVisibility) {
          filters.remove(entry.key);
          result[entry.key] = p;
          continue;
        }
        final axes = filters.putIfAbsent(
            entry.key,
            () => List.generate(
                3, (_) => OneEuroFilter(minCutoff: minCutoff, beta: beta)));
        result[entry.key] = PosePoint(
          x: axes[0].filter(p.x, timestampSeconds: time),
          y: axes[1].filter(p.y, timestampSeconds: time),
          z: axes[2].filter(p.z, timestampSeconds: time),
          visibility: p.visibility,
          presence: p.presence,
        );
      }
      return result;
    }

    _last = frame;
    return PoseFrame(
        capturedAtMicros: frame.capturedAtMicros,
        detectorId: frame.detectorId,
        modelVersion: frame.modelVersion,
        imageWidth: frame.imageWidth,
        imageHeight: frame.imageHeight,
        isMirrored: frame.isMirrored,
        posePresence: frame.posePresence,
        landmarks: apply(frame.landmarks, _image),
        worldLandmarks: apply(frame.worldLandmarks, _world));
  }
}

/// One inference plus one replaceable newest input. No unbounded frame queue.
class LatestPoseProcessor<T, R> {
  LatestPoseProcessor(
      {required this.clockMicros,
      required this.timestampMicros,
      required this.process,
      required this.onResult,
      required this.onError,
      this.onDiscard,
      this.maxAgeMicros = 250000});
  final int Function() clockMicros;
  final int Function(T) timestampMicros;
  final Future<R> Function(T) process;
  final void Function(R) onResult;
  final void Function(Object, StackTrace) onError;

  /// Optional observation; never changes the latest-frame policy.
  final void Function(T, String)? onDiscard;
  final int maxAgeMicros;
  int droppedFrames = 0, staleFrames = 0, processedFrames = 0;
  bool _disposed = false, _suspended = false, _busy = false;
  int _generation = 0;
  int? _lastDelivered;
  T? _pending;
  Future<void>? _active;

  void add(T value) {
    if (_disposed || _suspended) return;
    if (_busy) {
      if (_pending != null) {
        droppedFrames++;
        onDiscard?.call(_pending as T, 'replaced_pending');
      }
      _pending = value;
    } else {
      _busy = true;
      _active = _run(value);
    }
  }

  Future<void> _run(T first) async {
    T? current = first;
    try {
      while (current != null && !_disposed && !_suspended) {
        final value = current;
        final time = timestampMicros(value);
        final generation = _generation;
        if (clockMicros() - time > maxAgeMicros ||
            (_lastDelivered != null && time <= _lastDelivered!)) {
          staleFrames++;
          onDiscard?.call(value, 'stale_before_processing');
        } else {
          try {
            final result = await process(value);
            processedFrames++;
            if (generation == _generation && !_disposed && !_suspended) {
              if (clockMicros() - time <= maxAgeMicros) {
                _lastDelivered = time;
                onResult(result);
              } else {
                staleFrames++;
                onDiscard?.call(value, 'stale_result');
              }
            } else {
              onDiscard?.call(value, 'generation_invalidated_result');
            }
          } catch (error, stack) {
            if (generation == _generation && !_disposed && !_suspended) {
              onError(error, stack);
            }
          }
        }
        current = _pending;
        _pending = null;
      }
    } finally {
      _busy = false;
    }
  }

  void suspend() {
    _generation++;
    _suspended = true;
    if (_pending != null) {
      droppedFrames++;
      onDiscard?.call(_pending as T, 'generation_invalidated_pending');
    }
    _pending = null;
    _lastDelivered = null;
  }

  void resume() {
    if (!_disposed) _suspended = false;
  }

  void dispose() {
    suspend();
    _disposed = true;
  }

  Future<void> drain() async {
    await _active;
  }
}
