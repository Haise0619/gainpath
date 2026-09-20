/// Canonical landmark identifiers used by the pose-processing layer.
///
/// Detector adapters translate their native landmark model into this stable
/// vocabulary before any exercise rule sees a frame.
enum PoseLandmark {
  nose,
  leftShoulder,
  rightShoulder,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
}

class PosePoint {
  const PosePoint({
    required this.x,
    required this.y,
    required this.z,
    required this.visibility,
  });

  final double x;
  final double y;
  final double z;
  final double visibility;
}

class PoseFrame {
  PoseFrame({
    required this.capturedAtMicros,
    required this.detectorId,
    required this.modelVersion,
    required Map<PoseLandmark, PosePoint> landmarks,
    this.isMirrored = false,
  }) : landmarks = Map.unmodifiable(landmarks);

  final int capturedAtMicros;
  final String detectorId;
  final String modelVersion;
  final bool isMirrored;
  final Map<PoseLandmark, PosePoint> landmarks;

  PosePoint? landmark(PoseLandmark id) => landmarks[id];

  int get visibleLandmarkCount =>
      landmarks.values.where((point) => point.visibility > 0).length;
}
