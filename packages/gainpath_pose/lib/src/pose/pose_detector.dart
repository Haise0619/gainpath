import 'dart:math' as math;

import 'pose_frame.dart';

class PoseInput {
  const PoseInput({
    required this.timestampMicros,
    this.imageWidth = 1,
    this.imageHeight = 1,
  });

  final int timestampMicros;
  final int imageWidth;
  final int imageHeight;
}

abstract interface class PoseDetector {
  Future<PoseFrame> detect(PoseInput input);
}

/// Deterministic detector used by development, tests and the UI prototype.
///
/// It deliberately implements the same port as a native detector. Replacing
/// it with an ML Kit or TFLite adapter must not change the downstream engine.
class SimulatedPoseDetector implements PoseDetector {
  @override
  Future<PoseFrame> detect(PoseInput input) async {
    final phase = input.timestampMicros / 800000;
    final y = 0.5 + math.sin(phase) * 0.04;
    return PoseFrame(
      capturedAtMicros: input.timestampMicros,
      detectorId: 'simulated',
      modelVersion: '1',
      landmarks: {
        for (final landmark in PoseLandmark.values)
          landmark: PosePoint(x: 0.5, y: y, z: 0, visibility: 1),
      },
    );
  }
}
