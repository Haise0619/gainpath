import 'package:file_selector/file_selector.dart';
import 'package:gainpath_domain/workout.dart';
import 'equipment_image_validation_native.dart'
    if (dart.library.js_interop) 'equipment_image_validation_web.dart';

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
    final image = EquipmentImage(await file.readAsBytes());
    try {
      await validateEquipmentImage(image);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
          'This image could not be opened. Choose another JPG, PNG or WebP.');
    }
    return image;
  }
}
