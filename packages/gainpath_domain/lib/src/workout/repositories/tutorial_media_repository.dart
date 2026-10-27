import '../entities/equipment_image.dart';
import '../entities/equipment_video.dart';
import '../entities/tutorial_video.dart';

/// Reuses the validated catalog image/MP4 byte types; storage paths are
/// exercise-specific. Local filenames and paths never enter catalog records.
abstract interface class TutorialMediaStore {
  Future<String> uploadCover(EquipmentImage image);
  Future<String> uploadVideo(EquipmentVideo video,
      {void Function(double)? onProgress});
}

abstract interface class TutorialMediaRepository {
  Future<TutorialVideo> saveWithMedia(TutorialVideo tutorial,
      {EquipmentImage? cover,
      EquipmentVideo? video,
      void Function(double)? onVideoProgress});
}

class TutorialMediaUploadFailed implements Exception {
  const TutorialMediaUploadFailed();
  @override
  String toString() =>
      'Could not upload exercise media. Reload the catalog before retrying.';
}
