import 'pose_frame.dart';

enum TrackingStatus { healthy, degraded, lost }

class TrackingHealth {
  const TrackingHealth({
    required this.status,
    required this.visibleLandmarks,
    required this.lostDurationMicros,
  });

  final TrackingStatus status;
  final int visibleLandmarks;
  final int lostDurationMicros;
}

class TrackingHealthMonitor {
  TrackingHealthMonitor({
    this.minimumVisibleLandmarks = 3,
    this.minimumVisibility = 0.5,
    this.lostAfterMicros = 1000000,
  })  : assert(minimumVisibleLandmarks > 0),
        assert(minimumVisibility >= 0 && minimumVisibility <= 1),
        assert(lostAfterMicros > 0);

  final int minimumVisibleLandmarks;
  final double minimumVisibility;
  final int lostAfterMicros;
  int? _trackingLostAtMicros;

  TrackingHealth update(PoseFrame frame) {
    final visible = frame.landmarks.values
        .where((point) => point.visibility >= minimumVisibility)
        .length;
    if (visible >= minimumVisibleLandmarks) {
      _trackingLostAtMicros = null;
      return TrackingHealth(
        status: TrackingStatus.healthy,
        visibleLandmarks: visible,
        lostDurationMicros: 0,
      );
    }

    _trackingLostAtMicros ??= frame.capturedAtMicros;
    final duration = frame.capturedAtMicros - _trackingLostAtMicros!;
    return TrackingHealth(
      status: duration >= lostAfterMicros
          ? TrackingStatus.lost
          : TrackingStatus.degraded,
      visibleLandmarks: visible,
      lostDurationMicros: duration,
    );
  }
}
