import 'dart:math';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/workout.dart';

class FirebaseEquipmentImageStore implements EquipmentImageStore {
  FirebaseEquipmentImageStore({required this.scope, FirebaseStorage? storage})
      : _storage = storage;
  final SessionScope scope;
  final FirebaseStorage? _storage;

  @override
  Future<String> upload(EquipmentImage image) async {
    // Random immutable objects avoid overwriting an image another record uses.
    final random = Random.secure();
    final id = List.generate(
            16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
    final ref = (_storage ?? FirebaseStorage.instance).ref(
        'orgs/${scope.organizationId}/equipmentImages/${scope.userId}/$id');
    try {
      await ref.putData(
          image.bytes, SettableMetadata(contentType: image.contentType));
      return await ref.getDownloadURL();
    } catch (_) {
      // SDK errors may contain object URLs. Never surface them to UI or logs.
      throw const EquipmentImageUploadFailed();
    }
  }
}
