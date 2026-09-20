import '../../fakes/mock_data_session.dart';
import 'workout_seed.dart';
import 'package:gainpath_domain/workout.dart';

/// Session-scoped in-memory [EquipmentRepository] backed by [WorkoutSeed].
class InMemoryEquipmentRepository implements EquipmentRepository {
  InMemoryEquipmentRepository({MockDataSession? session})
      : _seed = (session ?? MockDataSession()).workout;

  final WorkoutSeed _seed;

  @override
  List<GymEquipment> get gymEquipment => _seed.gymEquipment;
}
