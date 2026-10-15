import 'dart:ui' as ui;
import 'package:file_selector/file_selector.dart';
import 'package:gainpath_domain/workout.dart';

class LocalEquipmentImagePicker implements EquipmentImagePicker {
  @override
  Future<EquipmentImage?> pick() async {
    final file = await openFile(acceptedTypeGroups: const [
      XTypeGroup(label: 'Equipment images', extensions: [
        'jpg',
        'jpeg',
        'png',
        'webp'
      ], mimeTypes: [
        'image/jpeg',
        'image/png',
        'image/webp'
      ], uniformTypeIdentifiers: [
        'public.jpeg',
        'public.png',
        'org.webmproject.webp'
      ])
    ]);
    if (file == null) return null;
    if (await file.length() > EquipmentImage.maxBytes) {
      throw const FormatException('Choose an image no larger than 5 MB.');
    }
    final image = EquipmentImage(await file.readAsBytes());
    final buffer = await ui.ImmutableBuffer.fromUint8List(image.bytes);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width * descriptor.height > 24000000) {
        throw const FormatException(
            'Choose an image smaller than 24 megapixels.');
      }
      codec = await descriptor.instantiateCodec(targetWidth: 256);
      final frame = await codec.getNextFrame();
      frame.image.dispose();
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
          'This image could not be opened. Choose another JPG, PNG or WebP.');
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
    return image;
  }
}
