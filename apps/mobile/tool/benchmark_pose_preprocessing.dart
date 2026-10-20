import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:gainpath_mobile/infrastructure/pose/blazepose_geometry.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import '../test/support/preprocessing_baseline.dart';
import '../test/support/preprocessing_fixture.dart';

// Manual AOT performance gate, not a timing-sensitive unit/CI test.
// Use run_pose_preprocessing_benchmark.ps1 to isolate unrelated native hooks.
// --verify-speedup requires >=10% in both landmark cases, no >5% regression.
typedef Kernel = Float32List Function(
    PoseCameraImage, TensorImageTransform, int,
    {required double minimum, required double maximum, PoseImageBorder border});

double _sink = 0;
double _median(List<double> samples) {
  final sorted = List<double>.of(samples)..sort();
  return sorted[sorted.length ~/ 2];
}

String _digest(Float32List tensor) => sha256
    .convert(
        tensor.buffer.asUint8List(tensor.offsetInBytes, tensor.lengthInBytes))
    .toString();

void main(List<String> args) {
  final image = preprocessingFixture(PosePixelFormat.yuv420, 270,
      width: 720, height: 480, chromaPixelStride: 2);
  final cases = [
    (
      'detector_full_frame',
      TensorImageTransform.fullFrame(480, 720),
      224,
      -1.0,
      PoseImageBorder.zero
    ),
    (
      'landmark_rotated_roi',
      TensorImageTransform(
          centerX: 240, centerY: 420, side: 600, rotation: .35),
      256,
      0.0,
      PoseImageBorder.replicate
    ),
    (
      'landmark_expanded_roi',
      TensorImageTransform(centerX: 80, centerY: 650, side: 820, rotation: -.7),
      256,
      0.0,
      PoseImageBorder.replicate
    ),
  ];
  final results = <Map<String, Object>>[];
  var landmarksFaster = true, noRegression = true;
  for (final c in cases) {
    Float32List call(Kernel kernel) =>
        kernel(image, c.$2, c.$3, minimum: c.$4, maximum: 1, border: c.$5);
    final originalDigest = _digest(call(preprocessBaseline));
    final optimizedDigest = _digest(call(preprocessImage));
    if (originalDigest != optimizedDigest) {
      throw StateError('Tensor changed in ${c.$1}.');
    }
    double batch(Kernel kernel) {
      final clock = Stopwatch()..start();
      for (var i = 0; i < 5; i++) {
        final tensor = call(kernel);
        _sink += tensor[101] + tensor.last;
      }
      return clock.elapsedMicroseconds / 5000;
    }

    for (var i = 0; i < 5; i++) {
      batch(preprocessBaseline);
      batch(preprocessImage);
    }
    final baseline = <double>[], optimized = <double>[];
    for (var i = 0; i < 9; i++) {
      if (i.isEven) {
        baseline.add(batch(preprocessBaseline));
        optimized.add(batch(preprocessImage));
      } else {
        optimized.add(batch(preprocessImage));
        baseline.add(batch(preprocessBaseline));
      }
    }
    final oldTime = _median(baseline), newTime = _median(optimized);
    final speedup = oldTime / newTime;
    if (c.$1.startsWith('landmark_')) landmarksFaster &= speedup >= 1.10;
    noRegression &= newTime <= oldTime * 1.05;
    results.add({
      'case': c.$1,
      'baselineMedianMillis': oldTime,
      'optimizedMedianMillis': newTime,
      'speedupRatio': speedup,
      'baselineBatchMillis': baseline,
      'optimizedBatchMillis': optimized,
      'tensorSha256': originalDigest,
      'bitwiseEquivalent': true,
    });
  }
  final accepted = landmarksFaster && noRegression;
  stdout.writeln(const JsonEncoder.withIndent('  ').convert({
    'platform': Platform.operatingSystem,
    'dartVersion': Platform.version,
    'sample': 'synthetic YUV420 720x480, rotation 270, chroma pixel stride 2',
    'warmupBatchesPerKernel': 5,
    'measuredBatchesPerKernel': 9,
    'iterationsPerBatch': 5,
    'cases': results,
    'checksumSink': _sink,
    'landmarkCasesAtLeastTenPercentFaster': landmarksFaster,
    'noCaseRegressedMoreThanFivePercent': noRegression,
    'performanceGatePassed': accepted,
    'boundary': 'host preprocessing only; not phone or end-to-end latency',
  }));
  if (args.contains('--verify-speedup') && !accepted) exitCode = 1;
}
