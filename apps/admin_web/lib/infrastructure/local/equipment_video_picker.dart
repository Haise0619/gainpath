import 'package:file_selector/file_selector.dart';
import 'package:gainpath_domain/workout.dart';

class LocalEquipmentVideoPicker implements EquipmentVideoPicker {
  LocalEquipmentVideoPicker(
      {Future<XFile?> Function()? selectFile,
      this.maxBytes = EquipmentVideo.maxBytes})
      : _selectFile = selectFile ?? _open;
  final int maxBytes;
  final Future<XFile?> Function() _selectFile;
  static Future<XFile?> _open() => openFile(acceptedTypeGroups: const [
        XTypeGroup(
            label: 'MP4 tutorial',
            extensions: ['mp4'],
            mimeTypes: ['video/mp4'],
            uniformTypeIdentifiers: ['public.mpeg-4'])
      ]);
  @override
  Future<EquipmentVideo?> pick() async {
    final file = await _selectFile();
    if (file == null) return null;
    if (!file.name.toLowerCase().endsWith('.mp4') ||
        await file.length() > maxBytes) {
      throw FormatException(
          'Choose an MP4 video no larger than ${maxBytes ~/ (1024 * 1024)} MB.');
    }
    return EquipmentVideo(await file.readAsBytes(), name: file.name);
  }
}
