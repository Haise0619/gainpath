import 'package:gainpath/features/workout/data/in_memory/workout_seed.dart';
import 'package:gainpath/features/workout/domain/entities/tutorial_video.dart';
import 'package:gainpath/features/workout/domain/repositories/tutorial_repository.dart';

/// Session-scoped in-memory [TutorialRepository] backed by [WorkoutSeed].
class InMemoryTutorialRepository implements TutorialRepository {
  @override
  List<TutorialVideo> get tutorials => WorkoutSeed.tutorials;
}
