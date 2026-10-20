/// Canonical landmark identifiers used by the pose-processing layer.
///
/// Detector adapters translate their native landmark model into this stable
/// vocabulary before any exercise rule sees a frame.
enum PoseLandmark {
  nose,
  leftEyeInner,
  leftEye,
  leftEyeOuter,
  rightEyeInner,
  rightEye,
  rightEyeOuter,
  leftEar,
  rightEar,
  leftMouth,
  rightMouth,
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,
  leftPinky,
  rightPinky,
  leftIndex,
  rightIndex,
  leftThumb,
  rightThumb,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
  leftHeel,
  rightHeel,
  leftFootIndex,
  rightFootIndex,
}

class PosePoint {
  const PosePoint({
    required this.x,
    required this.y,
    required this.z,
    required this.visibility,
    this.presence,
  });

  final double x;
  final double y;
  final double z;
  final double visibility;
  final double? presence;
}

class PoseFrame {
  PoseFrame({
    required this.capturedAtMicros,
    required this.detectorId,
    required this.modelVersion,
    required Map<PoseLandmark, PosePoint> landmarks,
    this.isMirrored = false,
    this.imageWidth = 1,
    this.imageHeight = 1,
    this.posePresence,
    Map<PoseLandmark, PosePoint> worldLandmarks = const {},
  }) : landmarks = Map.unmodifiable(landmarks),
       worldLandmarks = Map.unmodifiable(worldLandmarks);

  final int capturedAtMicros;
  final String detectorId;
  final String modelVersion;
  final bool isMirrored;
  final Map<PoseLandmark, PosePoint> landmarks;
  /// Upright image coordinates: x/width, y/height, z/width. Unmirrored in real
  /// adapters; preview mirroring is a presentation transform, not anatomy.
  final int imageWidth;
  final int imageHeight;
  final double? posePresence;
  /// Model-estimated metres relative to hip centre; never image-normalized z.
  final Map<PoseLandmark, PosePoint> worldLandmarks;

  PosePoint? landmark(PoseLandmark id) => landmarks[id];

  int get visibleLandmarkCount =>
      landmarks.values.where((point) => point.visibility > 0).length;
}
