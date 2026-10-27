import 'dart:math';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/workout.dart';

class FirebaseExerciseMediaStore implements TutorialMediaStore {
  FirebaseExerciseMediaStore(
      {required this.scope, required this.isCurrent, FirebaseStorage? storage})
      : _storage = storage;
  final SessionScope scope;
  final bool Function() isCurrent;
  final FirebaseStorage? _storage;

  @override
  Future<String> uploadCover(EquipmentImage image) =>
      _upload(image.copyBytes(), image.contentType, 'exerciseImages', '');
  @override
  Future<String> uploadVideo(EquipmentVideo video,
          {void Function(double)? onProgress}) =>
      _upload(video.copyBytes(), 'video/mp4', 'exerciseVideos', '.mp4',
          onProgress: onProgress);

  Future<String> _upload(
      Uint8List bytes, String contentType, String collection, String extension,
      {void Function(double)? onProgress}) async {
    if (!isCurrent()) throw const TutorialEditAuthorizationChanged();
    final random = Random.secure();
    final id = List.generate(
            16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
    final ref = (_storage ?? FirebaseStorage.instance).ref(
        'orgs/${scope.organizationId}/$collection/${scope.userId}/$id$extension');
    try {
      final task =
          ref.putData(bytes, SettableMetadata(contentType: contentType));
      final subscription = task.snapshotEvents.listen((snapshot) {
        if (!isCurrent()) {
          task.cancel();
          return;
        }
        if (snapshot.totalBytes > 0) {
          onProgress?.call(
              (snapshot.bytesTransferred / snapshot.totalBytes).clamp(0, 1));
        }
      }, onError: (Object _) {});
      try {
        await task;
      } finally {
        await subscription.cancel();
      }
      if (!isCurrent()) throw const TutorialEditAuthorizationChanged();
      final url = await ref.getDownloadURL();
      if (!isCurrent()) throw const TutorialEditAuthorizationChanged();
      return url;
    } on TutorialEditAuthorizationChanged {
      rethrow;
    } catch (_) {
      if (!isCurrent()) throw const TutorialEditAuthorizationChanged();
      throw const TutorialMediaUploadFailed();
    }
  }
}
