import 'dart:typed_data';

class EquipmentVideo {
  static const maxBytes = 100 * 1024 * 1024;
  EquipmentVideo(Uint8List data, {required this.name})
      : bytes = Uint8List.fromList(data).asUnmodifiableView() {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException('Choose an MP4 video no larger than 100 MB.');
    }
    if (bytes.length < 12 ||
        String.fromCharCodes(bytes.sublist(4, 8)) != 'ftyp') {
      throw const FormatException('Choose a valid MP4 video.');
    }
  }
  final Uint8List bytes;
  /// An independent native buffer for platform upload APIs.
  Uint8List copyBytes() => Uint8List.fromList(bytes);
  final String name;
}

abstract interface class EquipmentVideoPicker {
  Future<EquipmentVideo?> pick();
}

abstract interface class EquipmentVideoStore {
  Future<String> upload(EquipmentVideo video,
      {void Function(double)? onProgress});
}

class EquipmentVideoUploadFailed implements Exception {
  const EquipmentVideoUploadFailed();
}
