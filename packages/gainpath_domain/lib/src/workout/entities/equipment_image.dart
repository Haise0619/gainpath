import 'dart:typed_data';

/// Selected bytes only: filenames and computer paths are never persisted.
class EquipmentImage {
  EquipmentImage(Uint8List bytes)
      : bytes = Uint8List.fromList(bytes).asUnmodifiableView() {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException('Choose an image no larger than 5 MB.');
    }
    contentType = _starts([137, 80, 78, 71, 13, 10, 26, 10])
        ? 'image/png'
        : _starts([255, 216, 255])
            ? 'image/jpeg'
            : _starts([82, 73, 70, 70]) &&
                    bytes.length >= 12 &&
                    bytes[8] == 87 &&
                    bytes[9] == 69 &&
                    bytes[10] == 66 &&
                    bytes[11] == 80
                ? 'image/webp'
                : throw const FormatException(
                    'Choose a JPG, PNG or WebP image.');
  }
  static const maxBytes = 5 * 1024 * 1024;
  final Uint8List bytes;
  /// An independent native buffer for browser image and upload APIs.
  Uint8List copyBytes() => Uint8List.fromList(bytes);
  late final String contentType;
  bool _starts(List<int> prefix) =>
      bytes.length >= prefix.length &&
      List.generate(prefix.length, (i) => bytes[i] == prefix[i])
          .every((v) => v);
}

abstract interface class EquipmentImagePicker {
  Future<EquipmentImage?> pick();
}

abstract interface class EquipmentImageStore {
  Future<String> upload(EquipmentImage image);
}

class EquipmentImageUploadFailed implements Exception {
  const EquipmentImageUploadFailed();
}
