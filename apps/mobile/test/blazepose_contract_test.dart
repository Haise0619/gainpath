import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/infrastructure/pose/blazepose_contract.dart';
import 'package:gainpath_mobile/infrastructure/pose/blazepose_geometry.dart';
import 'package:gainpath_mobile/infrastructure/pose/blazepose_decode.dart';
import 'package:gainpath_pose/gainpath_pose.dart';

void main() {
  test('invalid detector scores are not reported as a genuine no-person result',
      () {
    final trace = <String, Object?>{};
    final boxes = Float32List(2254 * 12),
        scores = Float32List(2254)..fillRange(0, 2254, double.nan);
    expect(
        decodePoseDetection(
            boxes, scores, TensorImageTransform.fullFrame(640, 480),
            diagnostics: trace),
        isNull);
    expect(trace['outcome'], 'detector_nonfinite_scores');
    scores.fillRange(0, 2254, -100);
    decodePoseDetection(boxes, scores, TensorImageTransform.fullFrame(640, 480),
        diagnostics: trace);
    expect(trace['outcome'], 'detector_no_person');
    scores[0] = 10;
    decodePoseDetection(boxes, scores, TensorImageTransform.fullFrame(640, 480),
        diagnostics: trace);
    expect(trace['outcome'], 'invalid_detector_roi');
    expect(trace['personConfidence'], greaterThan(.99));
  });
  test('tracking ROI uses heatmap-refined auxiliary alignment points', () {
    final raw = Float32List(195),
        heatmap = Float32List(64 * 64 * 39)..fillRange(0, 64 * 64 * 39, -100);
    raw[165] = 128;
    raw[166] = 128;
    raw[169] = 10;
    raw[170] = 128;
    raw[171] = 64;
    raw[174] = 10;
    heatmap[(32 * 64 + 34) * 39 + 33] = 10;
    heatmap[(16 * 64 + 34) * 39 + 34] = 10;
    final roi = roiFromAuxiliaryLandmarks(
        raw, heatmap, TensorImageTransform.fullFrame(256, 256));
    expect(roi!.centerX, closeTo(136, 1e-5));
    expect(roi.centerY, closeTo(128, 1e-5));
    expect(roi.side, closeTo(160, 1e-5));
  });
  test('bundled exact model hashes and runtime tensor signatures are checked',
      () {
    for (final contract in [
      BlazePoseModelContract.detector,
      BlazePoseModelContract.landmark
    ]) {
      expect(
          sha256.convert(File(contract.assetPath).readAsBytesSync()).toString(),
          contract.sha256);
      contract.validate(contract.input, contract.outputs);
      expect(
          () => contract.validate(
              const PoseTensorSpec('input_1', [1, 256, 256, 3], 'uint8'),
              contract.outputs),
          throwsStateError);
      expect(
          () => contract.validate(
              contract.input, contract.outputs.reversed.toList()),
          throwsStateError);
    }
  });
  test(
      'SSD decoding unletterboxes alignment points into the expanded rotated body ROI',
      () {
    final anchors = blazePoseAnchors();
    expect(anchors, hasLength(2254));
    final boxes = Float32List(2254 * 12),
        scores = Float32List(2254)..fillRange(0, 2254, -100);
    scores[0] = 10;
    final anchor = anchors[0];
    boxes[4] = (0.5 - anchor.$1) * 224;
    boxes[5] = (0.5 - anchor.$2) * 224;
    boxes[6] = (0.5 - anchor.$1) * 224;
    boxes[7] = (0.34375 - anchor.$2) * 224;
    boxes[2] = 40;
    boxes[3] = 40;
    final roi = decodePoseDetection(
        boxes, scores, TensorImageTransform.fullFrame(640, 480));
    expect(roi, isNotNull);
    expect(roi!.centerX, closeTo(320, 0.001));
    expect(roi.centerY, closeTo(240, 0.001));
    expect(roi.side, closeTo(250, 0.001));
    expect(roi.rotation, closeTo(0, 0.001));
    scores.fillRange(0, 2254, -100);
    expect(
        decodePoseDetection(
            boxes, scores, TensorImageTransform.fullFrame(640, 480)),
        isNull);
  });
  test(
      'maps all 33 anatomical indices with image z, probabilities and rotated world metres',
      () {
    final raw = Float32List(195), world = Float32List(117);
    for (var i = 0; i < 39; i++) {
      raw[i * 5] = 128;
      raw[i * 5 + 1] = 128;
      raw[i * 5 + 2] = -25.6;
      raw[i * 5 + 4] = 2;
      world[i * 3] = 1;
      world[i * 3 + 1] = 2;
      world[i * 3 + 2] = 3;
    }
    final frame = decodeBlazePoseLandmarks(
        raw: raw,
        world: world,
        posePresence: 0.9,
        roi: TensorImageTransform(
            centerX: 320, centerY: 240, side: 256, rotation: math.pi / 2),
        imageWidth: 640,
        imageHeight: 480,
        timestampMicros: 123);
    expect(frame.landmarks.length, 33);
    expect(frame.worldLandmarks.length, 33);
    expect(frame.landmark(PoseLandmark.leftShoulder)!.x, 0.5);
    expect(frame.landmark(PoseLandmark.leftShoulder)!.z, closeTo(-0.04, 1e-6));
    expect(frame.landmark(PoseLandmark.leftShoulder)!.visibility, 0.5);
    expect(frame.landmark(PoseLandmark.leftShoulder)!.presence,
        closeTo(0.880797, 1e-6));
    expect(
        frame.worldLandmarks[PoseLandmark.leftShoulder]!.x, closeTo(-2, 1e-6));
    expect(frame.worldLandmarks[PoseLandmark.leftShoulder]!.z, 3);
    raw[11 * 5] = 64;
    raw[12 * 5] = 192;
    final sides = decodeBlazePoseLandmarks(
        raw: raw,
        world: world,
        posePresence: 0.9,
        roi: TensorImageTransform(centerX: 320, centerY: 240, side: 256),
        imageWidth: 640,
        imageHeight: 480,
        timestampMicros: 124);
    expect(sides.landmark(PoseLandmark.leftShoulder)!.x, 0.4);
    expect(sides.landmark(PoseLandmark.rightShoulder)!.x, 0.6);
    expect(
        decodeBlazePoseLandmarks(
                raw: raw,
                world: world,
                posePresence: 0.2,
                roi: TensorImageTransform.fullFrame(640, 480),
                imageWidth: 640,
                imageHeight: 480,
                timestampMicros: 125)
            .landmarks,
        isEmpty);
    expect(
        () => decodeBlazePoseLandmarks(
            raw: Float32List(165),
            world: world,
            posePresence: 0.9,
            roi: TensorImageTransform.fullFrame(640, 480),
            imageWidth: 640,
            imageHeight: 480,
            timestampMicros: 125),
        throwsFormatException);
  });
}
