import 'dart:typed_data';
import 'dart:math' as math;
import 'package:gainpath_pose/gainpath_pose.dart';
import 'blazepose_geometry.dart';
import 'blazepose_contract.dart';

// Adapter-owned mapping, independent of enum ordinal persistence.
const blazePoseTopology = [
  PoseLandmark.nose,
  PoseLandmark.leftEyeInner,
  PoseLandmark.leftEye,
  PoseLandmark.leftEyeOuter,
  PoseLandmark.rightEyeInner,
  PoseLandmark.rightEye,
  PoseLandmark.rightEyeOuter,
  PoseLandmark.leftEar,
  PoseLandmark.rightEar,
  PoseLandmark.leftMouth,
  PoseLandmark.rightMouth,
  PoseLandmark.leftShoulder,
  PoseLandmark.rightShoulder,
  PoseLandmark.leftElbow,
  PoseLandmark.rightElbow,
  PoseLandmark.leftWrist,
  PoseLandmark.rightWrist,
  PoseLandmark.leftPinky,
  PoseLandmark.rightPinky,
  PoseLandmark.leftIndex,
  PoseLandmark.rightIndex,
  PoseLandmark.leftThumb,
  PoseLandmark.rightThumb,
  PoseLandmark.leftHip,
  PoseLandmark.rightHip,
  PoseLandmark.leftKnee,
  PoseLandmark.rightKnee,
  PoseLandmark.leftAnkle,
  PoseLandmark.rightAnkle,
  PoseLandmark.leftHeel,
  PoseLandmark.rightHeel,
  PoseLandmark.leftFootIndex,
  PoseLandmark.rightFootIndex,
];
double poseSigmoid(double v) => 1 / (1 + math.exp(-v.clamp(-100, 100)));
final _anchors = List<(double, double)>.unmodifiable(blazePoseAnchors());
List<(double, double)> blazePoseAnchors() => [
      // Grouped identical strides: fixed-size anchors, 2 anchors per layer/cell.
      for (final layer in [(28, 2), (14, 2), (7, 6)])
        for (var y = 0; y < layer.$1; y++)
          for (var x = 0; x < layer.$1; x++)
            for (var a = 0; a < layer.$2; a++)
              ((x + 0.5) / layer.$1, (y + 0.5) / layer.$1),
    ];

class _Detection {
  _Detection(this.score, this.x, this.y, this.w, this.h, this.points);
  final double score, x, y, w, h;
  final List<(double, double)> points;
  double overlap(_Detection other) {
    final width = math.max(
        0,
        math.min(x + w / 2, other.x + other.w / 2) -
            math.max(x - w / 2, other.x - other.w / 2));
    final height = math.max(
        0,
        math.min(y + h / 2, other.y + other.h / 2) -
            math.max(y - h / 2, other.y - other.h / 2));
    final intersection = width * height,
        union = w * h + other.w * other.h - intersection;
    return union > 0 ? intersection / union : 0;
  }
}

TensorImageTransform? decodePoseDetection(
    Float32List boxes, Float32List scores, TensorImageTransform image,
    {Map<String, Object?>? diagnostics}) {
  if (boxes.length != 2254 * 12 || scores.length != 2254) {
    throw const FormatException('Invalid detector output.');
  }
  final detections = <_Detection>[];
  var maxScore = 0.0;
  var finiteScores = 0;
  for (var i = 0; i < scores.length; i++) {
    if (!scores[i].isFinite) continue;
    finiteScores++;
    final score = poseSigmoid(scores[i]);
    maxScore = math.max(maxScore, score);
    if (score < 0.5) continue;
    final b = i * 12, anchor = _anchors[i];
    if (!List.generate(12, (j) => boxes[b + j].isFinite).every((v) => v)) {
      continue;
    }
    detections.add(_Detection(
        score,
        boxes[b] / 224 + anchor.$1,
        boxes[b + 1] / 224 + anchor.$2,
        boxes[b + 2] / 224,
        boxes[b + 3] / 224, [
      for (var p = 0; p < 4; p++)
        (
          boxes[b + 4 + p * 2] / 224 + anchor.$1,
          boxes[b + 5 + p * 2] / 224 + anchor.$2
        ),
    ]));
  }
  diagnostics?.addAll({
    'maxPersonConfidence': maxScore,
    'acceptedDetections': detections.length
  });
  if (detections.isEmpty) {
    diagnostics?['outcome'] = finiteScores == 0
        ? 'detector_nonfinite_scores'
        : maxScore < .5
            ? 'detector_no_person'
            : 'detector_invalid_boxes';
    return null;
  }
  detections.sort((a, b) => b.score.compareTo(a.score));
  final top = detections.first;
  final cluster = detections
      .where((d) => identical(d, top) || top.overlap(d) > 0.3)
      .toList();
  final weight = cluster.fold<double>(0, (v, d) => v + d.score);
  (double, double) point(int n) => image.project(
      cluster.fold<double>(0, (v, d) => v + d.points[n].$1 * d.score) / weight,
      cluster.fold<double>(0, (v, d) => v + d.points[n].$2 * d.score) / weight);
  final roi = roiFromAlignment(point(0), point(1));
  diagnostics?.addAll({
    'personConfidence': top.score,
    'outcome': roi == null ? 'invalid_detector_roi' : 'detector_person'
  });
  return roi;
}

TensorImageTransform? roiFromAlignment(
    (double, double) hip, (double, double) scale) {
  final dx = scale.$1 - hip.$1, dy = scale.$2 - hip.$2;
  final side = 2.5 * math.sqrt(dx * dx + dy * dy);
  if (!side.isFinite || side < 1) return null;
  final angle = math.pi / 2 + math.atan2(dy, dx);
  return TensorImageTransform(
      centerX: hip.$1,
      centerY: hip.$2,
      side: side,
      rotation: (angle + math.pi) % (2 * math.pi) - math.pi);
}

/// Official graph refines all 39 points before splitting tracking auxiliaries.
TensorImageTransform? roiFromAuxiliaryLandmarks(
    Float32List raw, Float32List heatmap, TensorImageTransform previous) {
  if (raw.length != 195 || heatmap.length != 64 * 64 * 39) {
    throw const FormatException('Invalid auxiliary tensor contract.');
  }
  if (!raw.sublist(165, 175).every((v) => v.isFinite) ||
      poseSigmoid(raw[169]) < .5 ||
      poseSigmoid(raw[174]) < .5) {
    return null;
  }
  final hip = _refineHeatmap(heatmap, 33, raw[165] / 256, raw[166] / 256);
  final scale = _refineHeatmap(heatmap, 34, raw[170] / 256, raw[171] / 256);
  return roiFromAlignment(
      previous.project(hip.$1, hip.$2), previous.project(scale.$1, scale.$2));
}

PoseFrame decodeBlazePoseLandmarks(
    {required Float32List raw,
    required Float32List world,
    required double posePresence,
    required TensorImageTransform roi,
    required int imageWidth,
    required int imageHeight,
    required int timestampMicros,
    Float32List? heatmap}) {
  if (raw.length != 195 ||
      world.length != 117 ||
      (heatmap != null && heatmap.length != 64 * 64 * 39) ||
      !posePresence.isFinite ||
      posePresence < 0 ||
      posePresence > 1 ||
      imageWidth <= 0 ||
      imageHeight <= 0) {
    throw const FormatException('Invalid landmark tensor contract.');
  }
  final points = <PoseLandmark, PosePoint>{},
      metres = <PoseLandmark, PosePoint>{};
  if (posePresence >= 0.5) {
    for (var i = 0; i < 33; i++) {
      final values = raw.sublist(i * 5, i * 5 + 5),
          w = world.sublist(i * 3, i * 3 + 3);
      if (!values.every((v) => v.isFinite) || !w.every((v) => v.isFinite)) {
        continue;
      }
      var x = values[0] / 256, y = values[1] / 256;
      if (heatmap != null) {
        final refined = _refineHeatmap(heatmap, i, x, y);
        x = refined.$1;
        y = refined.$2;
      }
      final projected = roi.project(x, y);
      final visibility = poseSigmoid(values[3]),
          presence = poseSigmoid(values[4]);
      points[blazePoseTopology[i]] = PosePoint(
          x: projected.$1 / imageWidth,
          y: projected.$2 / imageHeight,
          z: values[2] / 256 * roi.side / imageWidth,
          visibility: visibility,
          presence: presence);
      metres[blazePoseTopology[i]] = PosePoint(
          x: math.cos(roi.rotation) * w[0] - math.sin(roi.rotation) * w[1],
          y: math.sin(roi.rotation) * w[0] + math.cos(roi.rotation) * w[1],
          z: w[2],
          visibility: visibility,
          presence: presence);
    }
  }
  return PoseFrame(
      capturedAtMicros: timestampMicros,
      detectorId: 'blazepose-tflite',
      modelVersion: BlazePoseModelContract.version,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      posePresence: posePresence,
      landmarks: points,
      worldLandmarks: metres);
}

(double, double) _refineHeatmap(
    Float32List heatmap, int landmark, double x, double y) {
  final cx = (x * 64).floor(), cy = (y * 64).floor();
  if (cx < 0 || cy < 0 || cx >= 64 || cy >= 64) return (x, y);
  var sum = 0.0, wx = 0.0, wy = 0.0, max = 0.0;
  for (var row = math.max(0, cy - 3); row < math.min(64, cy + 4); row++) {
    for (var col = math.max(0, cx - 3); col < math.min(64, cx + 4); col++) {
      final value = heatmap[(row * 64 + col) * 39 + landmark];
      if (!value.isFinite) continue;
      final weight = poseSigmoid(value);
      sum += weight;
      wx += col * weight;
      wy += row * weight;
      max = math.max(max, weight);
    }
  }
  return max >= 0.5 && sum > 0 ? (wx / 64 / sum, wy / 64 / sum) : (x, y);
}
