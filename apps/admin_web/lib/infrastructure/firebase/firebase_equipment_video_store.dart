import 'dart:math';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/workout.dart';

class FirebaseEquipmentVideoStore implements EquipmentVideoStore {
  FirebaseEquipmentVideoStore({required this.scope, FirebaseStorage? storage})
      : _storage = storage;
  final SessionScope scope;
  final FirebaseStorage? _storage;
  @override
  Future<String> upload(EquipmentVideo video,
      {void Function(double)? onProgress}) async {
    final random = Random.secure();
    final id = List.generate(
            16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
    final ref = (_storage ?? FirebaseStorage.instance).ref(
        'orgs/${scope.organizationId}/equipmentVideos/${scope.userId}/$id.mp4');
    try {
      final task =
          ref.putData(video.bytes, SettableMetadata(contentType: 'video/mp4'));
      final subscription = task.snapshotEvents.listen((s) {
        if (s.totalBytes > 0) {
          onProgress?.call(s.bytesTransferred / s.totalBytes);
        }
      }, onError: (Object _) {});
      try {
        await task;
      } finally {
        await subscription.cancel();
      }
      return await ref.getDownloadURL();
    } catch (_) {
      throw const EquipmentVideoUploadFailed();
    }
  }
}
