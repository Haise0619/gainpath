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

  @override
  Future<List<TutorialVideo>> load() async => tutorials;

  @override
  bool get requiresCatalogSelection => false;

  @override
  Future<TutorialVideo> save(TutorialVideo tutorial) async {
    final existing = _seed.tutorials
        .indexWhere((item) => item.id.isNotEmpty && item.id == tutorial.id);
    if (existing < 0) {
      final saved = tutorial.id.isEmpty
          ? TutorialVideo(
              id: 'exercise-${DateTime.now().microsecondsSinceEpoch}',
              title: tutorial.title,
              category: tutorial.category,
              status: tutorial.status,
              coversExercise: tutorial.coversExercise,
              difficulty: tutorial.difficulty,
              durationMin: tutorial.durationMin,
              videoUrl: tutorial.videoUrl,
              thumbnailUrl: tutorial.thumbnailUrl,
              description: tutorial.description)
          : tutorial;
      _seed.tutorials.add(saved);
      return saved;
    }
    _seed.tutorials[existing] = tutorial;
    return tutorial;
  }
}
