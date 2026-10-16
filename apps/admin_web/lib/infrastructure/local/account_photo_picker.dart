import 'dart:ui' as ui;
import 'package:file_selector/file_selector.dart';
import 'package:gainpath_domain/identity.dart';

class LocalAccountPhotoPicker implements AccountPhotoPicker {
  LocalAccountPhotoPicker({Future<XFile?> Function()? selectFile})
      : _selectFile = selectFile ?? _openFile;

  final Future<XFile?> Function() _selectFile;

  static Future<XFile?> _openFile() => openFile(acceptedTypeGroups: const [
        XTypeGroup(label: 'Profile photos', extensions: [
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
  Future<AccountPhoto?> pick() async {
    final file = await _selectFile();
    if (file == null) return null;
    if (await file.length() > AccountPhoto.maxBytes) {
      throw const FormatException('Choose an image no larger than 5 MB.');
    }
    final image = AccountPhoto(await file.readAsBytes());
    final buffer = await ui.ImmutableBuffer.fromUint8List(image.bytes);
    ui.Codec? codec;
    try {
      // ImageDescriptor.width/height are unsupported for encoded images on Web.
      // This callback supplies the intrinsic dimensions on both Web and native.
      codec = await ui.instantiateImageCodecWithSize(buffer,
          getTargetSize: (width, height) {
        if (width * height > 24000000) {
          throw const FormatException(
              'Choose an image smaller than 24 megapixels.');
        }
        return const ui.TargetImageSize(width: 256);
      });
      final frame = await codec.getNextFrame();
      frame.image.dispose();
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
          'This image could not be opened. Choose another JPG, PNG or WebP.');
    } finally {
      codec?.dispose();
      // instantiateImageCodecWithSize takes ownership of the buffer.
    }
    return image;
  }
}
