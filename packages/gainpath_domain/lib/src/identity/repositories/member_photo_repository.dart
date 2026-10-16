import 'dart:typed_data';
import '../entities/account_photo.dart';

class MemberPhoto {
  const MemberPhoto({required this.path, required this.editBaseline});
  final String path;
  final Object editBaseline;
}

abstract interface class MemberPhotoRepository {
  Future<MemberPhoto> load();
  Future<MemberPhoto> save(MemberPhoto original,
      {AccountPhoto? photo, bool remove = false});
  Future<Uint8List?> readPhoto(MemberPhoto original);
}

class MemberPhotoException implements Exception {
  const MemberPhotoException(this.message, {this.reloadRequired = false});
  final String message;
  final bool reloadRequired;
}
