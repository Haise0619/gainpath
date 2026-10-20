import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:gainpath_domain/identity.dart';

/// A header avatar is a bounded still image, never document/video media.
Future<Uint8List> decodeStaticCoachAvatar(Uint8List bytes) async {
  // The domain checks image magic and the 5 MB limit before native decoding.
  final photo = AccountPhoto(bytes);
  final buffer = await ui.ImmutableBuffer.fromUint8List(photo.bytes);
  ui.Codec? codec;
  try {
    codec = await ui.instantiateImageCodecWithSize(buffer,
        getTargetSize: (width, height) {
      if (width <= 0 || height <= 0 || width * height > 24000000) {
        throw const FormatException('Unsupported avatar dimensions.');
      }
      final longest = width > height ? width : height;
      final scale = longest > 256 ? 256 / longest : 1.0;
      return ui.TargetImageSize(
          width: (width * scale).round().clamp(1, 256),
          height: (height * scale).round().clamp(1, 256));
    });
    if (codec.frameCount != 1) {
      throw const FormatException('Use a still image for the profile avatar.');
    }
    final frame = await codec.getNextFrame();
    try {
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw const FormatException('Avatar unavailable.');
      return Uint8List.fromList(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    } finally {
      frame.image.dispose();
    }
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('Avatar is not a supported still image.');
  } finally {
    codec?.dispose();
  }
}
