import '../../workout/entities/equipment_image.dart';

/// Uploads validated cover bytes; local filenames and paths are never saved.
abstract interface class RewardMediaRepository {
  Future<String> uploadRewardCover(EquipmentImage image);
}

class RewardMediaUploadFailed implements Exception {
  const RewardMediaUploadFailed({this.code = 'unknown'});
  final String code;
  String get message {
    const known = {
      'unauthorized',
      'unauthenticated',
      'retry-limit-exceeded',
      'canceled',
      'quota-exceeded',
      'bucket-not-found',
      'project-not-found',
      'unknown',
      'client-error',
      'permission-denied',
      'invalid-argument',
      'already-exists',
      'unavailable',
      'deadline-exceeded',
      'resource-exhausted',
      'internal'
    };
    final safe = known.contains(code) ? code : 'unknown';
    return switch (safe) {
      'unauthorized' =>
        'Could not upload the reward image: Storage denied access (unauthorized). Your reward was not saved.',
      'unauthenticated' =>
        'Could not upload the reward image: sign in again (unauthenticated). Your reward was not saved.',
      'retry-limit-exceeded' =>
        'Could not upload the reward image: upload timed out (retry-limit-exceeded). Check your connection and retry.',
      'canceled' =>
        'Could not upload the reward image: upload was cancelled (canceled). Your reward was not saved.',
      _ =>
        'Could not upload the reward image ($safe). Your reward was not saved. Please retry.',
    };
  }

  @override
  String toString() => message;
}
