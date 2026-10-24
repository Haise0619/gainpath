import 'dart:ui' as ui;
import 'package:gainpath_domain/workout.dart';

Future<void> validateEquipmentImage(EquipmentImage image) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(image.bytes);
  final codec = await ui.instantiateImageCodecWithSize(buffer,
      getTargetSize: (width, height) {
    if (width * height > 24000000) {
      throw const FormatException('Choose an image smaller than 24 megapixels.');
    }
    return const ui.TargetImageSize(width: 256);
  });
  try {
    final frame = await codec.getNextFrame();
    frame.image.dispose();
  } finally {
    codec.dispose();
  }
}
