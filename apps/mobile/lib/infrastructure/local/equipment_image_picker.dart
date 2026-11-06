import 'dart:ui' as ui;
import 'package:file_selector/file_selector.dart';
import 'package:gainpath_domain/workout.dart';

class LocalEquipmentImagePicker implements EquipmentImagePicker {
  LocalEquipmentImagePicker({Future<XFile?> Function()? selectFile})
      : _selectFile = selectFile ?? _openFile;

  final Future<XFile?> Function() _selectFile;

  static Future<XFile?> _openFile() => openFile(acceptedTypeGroups: const [
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

  @override
  Future<EquipmentImage?> pick() async {
    final file = await _selectFile();
    if (file == null) return null;
    if (await file.length() > EquipmentImage.maxBytes) {
      throw const FormatException('Choose an image no larger than 5 MB.');
    }
    final rawBytes = await file.readAsBytes();
    if (rawBytes.isEmpty) {
      throw const FormatException('Choose an image no larger than 5 MB.');
    }

    final isPng = rawBytes.length >= 8 &&
        rawBytes[0] == 137 &&
        rawBytes[1] == 80 &&
        rawBytes[2] == 78 &&
        rawBytes[3] == 71;
    final isJpeg = rawBytes.length >= 3 &&
        rawBytes[0] == 255 &&
        rawBytes[1] == 216 &&
        rawBytes[2] == 255;
    final isWebp = rawBytes.length >= 12 &&
        rawBytes[0] == 82 &&
        rawBytes[1] == 73 &&
        rawBytes[2] == 70 &&
        rawBytes[3] == 70 &&
        rawBytes[8] == 87 &&
        rawBytes[9] == 69 &&
        rawBytes[10] == 66 &&
        rawBytes[11] == 80;

    if (!isPng && !isJpeg && !isWebp) {
      throw const FormatException('Choose a JPG, PNG or WebP image.');
    }

    final buffer = await ui.ImmutableBuffer.fromUint8List(rawBytes);
    ui.Codec? codec;
    bool needsReencode = false;
    try {
      codec = await ui.instantiateImageCodecWithSize(buffer,
          getTargetSize: (width, height) {
        if (width <= 0 || height <= 0 || width * height > 24000000) {
          throw const FormatException(
              'Choose an image smaller than 24 megapixels.');
        }
        final longest = width > height ? width : height;
        if (longest <= 1024) {
          return ui.TargetImageSize(width: width, height: height);
        }
        needsReencode = true;
        final scale = 1024 / longest;
        return ui.TargetImageSize(
            width: (width * scale).round().clamp(1, 1024),
            height: (height * scale).round().clamp(1, 1024));
      });
      final frame = await codec.getNextFrame();
      try {
        // If resized, or if WebP (which Firebase function rejects), or if raw file > 1MB:
        // re-encode to clean, compact PNG so vision uploads are fast, reliable and within quotas.
        if (needsReencode || isWebp || rawBytes.length > 1024 * 1024) {
          final byteData =
              await frame.image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData == null) {
            throw const FormatException(
                'This image could not be processed. Choose another JPG, PNG or WebP.');
          }
          final pngBytes = byteData.buffer
              .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
          return EquipmentImage(pngBytes);
        }
      } finally {
        frame.image.dispose();
      }
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
          'This image could not be opened. Choose another JPG, PNG or WebP.');
    } finally {
      codec?.dispose();
    }
    return EquipmentImage(rawBytes);
  }
}
