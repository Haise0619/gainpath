import 'dart:convert';
import 'dart:io';
// Workspace diagnostic; the pose package is resolved by the workspace lockfile.
// ignore: depend_on_referenced_packages
import 'package:gainpath_pose/gainpath_pose.dart';
import '../packages/gainpath_pose/test/support/lateral_raise_trajectory.dart';

/// Host scalar-analysis cost only; excludes phone camera, inference and rendering.
void main() {
  final frames = lateralRaiseTrajectory(stepMicros: 16667).toList();
  final analyzer = LateralRaiseAnalyzer(), clock = Stopwatch();
  final samples = <double>[];
  final period = frames.last.capturedAtMicros + 16667;
  for (var cycle = 0; cycle < 250; cycle++) {
    for (final original in frames) {
      final t = original.capturedAtMicros + cycle * period;
      final f = PoseFrame(
          capturedAtMicros: t,
          detectorId: original.detectorId,
          modelVersion: original.modelVersion,
          imageWidth: original.imageWidth,
          imageHeight: original.imageHeight,
          landmarks: original.landmarks);
      clock
        ..reset()
        ..start();
      analyzer.update(f, nowMicros: t);
      clock.stop();
      if (cycle >= 50) {
        samples.add(clock.elapsedTicks * 1000000 / clock.frequency);
      }
    }
  }
  samples.sort();
  if (analyzer.snapshot.repetitions != 250 ||
      analyzer.snapshot.formScorePercent != null) {
    throw StateError('Bilateral replay correctness changed');
  }
  stdout.writeln(jsonEncode({
    'scope': 'Synthetic host CPU replay; not phone FPS/accuracy',
    'warmupCycles': 50,
    'sampledFrames': samples.length,
    'repetitions': analyzer.snapshot.repetitions,
    'medianMicros': samples[samples.length ~/ 2],
    'p95Micros': samples[(samples.length * .95).floor()]
  }));
}
