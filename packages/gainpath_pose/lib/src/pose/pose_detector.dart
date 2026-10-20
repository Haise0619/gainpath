import 'dart:math' as math;

import 'pose_frame.dart';
import 'pose_image.dart';

class PoseInput {
  const PoseInput({
    required this.timestampMicros,
    this.imageWidth = 1,
    this.imageHeight = 1,
    this.image,
  });

  final int timestampMicros;
  final int imageWidth;
  final int imageHeight;
  /// Mobile adapters supply a Dart-owned snapshot. Native/plugin types never
  /// enter this port. Simulation callers may omit it as before.
  final PoseCameraImage? image;
}

abstract interface class PoseDetector {
  Future<PoseFrame> detect(PoseInput input);
}

/// Optional lifecycle port for real adapters with per-stream/native resources.
abstract interface class ManagedPoseDetector implements PoseDetector {
  Future<void> reset();
  Future<void> close();
}

abstract interface class PoseDetectorDiagnostics {
  Map<String, Object> get diagnostics;
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
