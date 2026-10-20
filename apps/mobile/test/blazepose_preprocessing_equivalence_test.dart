import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/infrastructure/pose/blazepose_geometry.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'support/preprocessing_baseline.dart';
import 'support/preprocessing_fixture.dart';

String tensorDigest(Float32List tensor) => sha256
    .convert(
        tensor.buffer.asUint8List(tensor.offsetInBytes, tensor.lengthInBytes))
    .toString();

void main() {
  for (final format in PosePixelFormat.values) {
    for (final rotation in [0, 90, 180, 270]) {
      test('$format/$rotation preserves full model tensors bit for bit', () {
        final image = preprocessingFixture(format, rotation);
        final transforms = [
          TensorImageTransform.fullFrame(
              image.uprightWidth, image.uprightHeight),
          // A non-right-angle ROI crosses all borders, with fractional samples.
          TensorImageTransform(
              centerX: image.uprightWidth * .43,
              centerY: image.uprightHeight * .71,
              side: 36.7,
              rotation: -.37),
        ];
        for (final size in [224, 256]) {
          final minimum = size == 224 ? -1.0 : 0.0;
          for (final border in PoseImageBorder.values) {
            for (final transform in transforms) {
              final expected = preprocessBaseline(image, transform, size,
                  minimum: minimum, maximum: 1, border: border);
              final actual = preprocessImage(image, transform, size,
                  minimum: minimum, maximum: 1, border: border);
              expect(actual.length, size * size * 3);
              expect(tensorDigest(actual), tensorDigest(expected),
                  reason: '$size/$border/ROI=${transform.rotation}');
            }
          }
        }
      });
    }
  }
}
