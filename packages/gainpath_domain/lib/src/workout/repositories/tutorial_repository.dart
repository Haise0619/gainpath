import '../entities/tutorial_video.dart';

/// Data access contract for the workout feature. Implemented in-memory for the
/// prototype; a Firebase implementation will sit behind the same interface.
abstract class TutorialRepository {
  List<TutorialVideo> get tutorials;
}
