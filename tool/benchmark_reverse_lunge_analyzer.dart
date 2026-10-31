import 'dart:convert';
import 'dart:io';
// Workspace-only diagnostic.
// ignore: depend_on_referenced_packages
import 'package:gainpath_pose/gainpath_pose.dart';
import '../packages/gainpath_pose/test/support/reverse_lunge_trajectory.dart';

/// Synthetic CPU/replay evidence only; excludes camera/model inference/rendering.
void main() {
  final frames = reverseLungeTrajectory(stepMicros: 16667).toList();
  final samples = <double>[];
  final analyzer = ReverseLungeAnalyzer(side: LungeSide.left);
  final clock = Stopwatch();
  final period = frames.last.capturedAtMicros + 16667;
  for (var cycle = 0; cycle < 250; cycle++) {
    for (final original in frames) {
      final t = original.capturedAtMicros + cycle * period;
      final frame = PoseFrame(
          capturedAtMicros: t,
          detectorId: original.detectorId,
          modelVersion: original.modelVersion,
          imageWidth: original.imageWidth,
          imageHeight: original.imageHeight,
          landmarks: original.landmarks);
      clock
        ..reset()
        ..start();
      analyzer.update(frame, nowMicros: t);
      clock.stop();
      if (cycle >= 50) {
        samples.add(clock.elapsedTicks * 1000000 / clock.frequency);
      }
    }
  }
  samples.sort();
  if (analyzer.snapshot.repetitions != 250 ||
      analyzer.snapshot.formScorePercent != null) {
    throw StateError('Replay correctness changed');
  }
  final response = <Map<String, Object>>[];
  for (final step in [16667, 50000, 125000]) {
    final replay = ReverseLungeAnalyzer(side: LungeSide.left);
    int? countedAt;
    for (final frame in reverseLungeTrajectory(stepMicros: step)) {
      final update = replay.update(frame, nowMicros: frame.capturedAtMicros);
      if (update.repetitions == 1 && countedAt == null) {
        countedAt = frame.capturedAtMicros;
      }
    }
    if (countedAt == null) throw StateError('Sampling replay failed');
    response.add({
      'sampleIntervalMicros': step,
      'countedAtMicros': countedAt,
      'fixtureFeetReturnedAtMicros': 3900000,
      'countMinusFullReturnMicros': countedAt - 3900000
    });
  }
  stdout.writeln(jsonEncode({
    'scope': 'Synthetic host CPU/replay, not phone FPS or physical accuracy',
    'warmupCycles': 50,
    'sampledFrames': samples.length,
    'analyzerMedianMicros': samples[samples.length ~/ 2],
    'analyzerP95Micros': samples[(samples.length * .95).floor()],
    'timerFrequency': clock.frequency,
    'replayedRepetitions': analyzer.snapshot.repetitions,
    'formScore': analyzer.snapshot.formScorePercent,
    'response': response
  }));
}
