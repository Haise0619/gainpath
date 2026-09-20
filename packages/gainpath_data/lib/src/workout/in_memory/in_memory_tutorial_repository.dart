import '../../fakes/mock_data_session.dart';
import 'workout_seed.dart';
import 'package:gainpath_domain/workout.dart';

/// Session-scoped in-memory [TutorialRepository] backed by [WorkoutSeed].
class InMemoryTutorialRepository implements TutorialRepository {
  InMemoryTutorialRepository({MockDataSession? session})
      : _seed = (session ?? MockDataSession()).workout;

  final WorkoutSeed _seed;

  @override
  List<TutorialVideo> get tutorials => _seed.tutorials;
}
