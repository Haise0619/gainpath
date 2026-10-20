import 'dart:typed_data';

/// Validated account photo bytes. Original filenames and local paths are not stored.
class AccountPhoto {
  AccountPhoto(Uint8List bytes)
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
  late final String contentType;
  bool _starts(List<int> prefix) =>
      bytes.length >= prefix.length &&
      List.generate(prefix.length, (i) => bytes[i] == prefix[i])
          .every((v) => v);
}

abstract interface class AccountPhotoPicker {
  Future<AccountPhoto?> pick();
}

abstract interface class AccountPhotoStore {
  Future<String> upload(AccountPhoto photo);
  Future<Uint8List> read(String path);
}

class AccountPhotoUnavailable implements Exception {
  const AccountPhotoUnavailable();
}
