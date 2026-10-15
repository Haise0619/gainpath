import '../entities/tutorial_video.dart';

class TutorialEditConflict implements Exception {
  const TutorialEditConflict();
  @override
  String toString() =>
      'This exercise changed or was deleted. Reload before editing.';
}

class TutorialEditAuthorizationChanged implements Exception {
  const TutorialEditAuthorizationChanged();
  @override
  String toString() =>
      'Your authorization changed. Reopen the catalog after signing in.';
}

class TutorialCatalogSaveFailed implements Exception {
  const TutorialCatalogSaveFailed();
  @override
  String toString() =>
      'Could not verify the exercise save. Reload the catalog before retrying.';
}

/// Data access contract for the workout feature. Implemented in-memory for the
/// prototype; a Firebase implementation will sit behind the same interface.
abstract class TutorialRepository {
  List<TutorialVideo> get tutorials;

  Future<List<TutorialVideo>> load() async => tutorials;

  Future<TutorialVideo> save(TutorialVideo tutorial) async {
    throw UnsupportedError(
        'This repository does not support saving exercises.');
  }

  bool get requiresCatalogSelection => false;
}
