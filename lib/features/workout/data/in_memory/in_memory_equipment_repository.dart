import 'package:gainpath/features/workout/data/in_memory/workout_seed.dart';
import 'package:gainpath/features/workout/domain/entities/gym_equipment.dart';
import 'package:gainpath/features/workout/domain/repositories/equipment_repository.dart';

/// Session-scoped in-memory [EquipmentRepository] backed by [WorkoutSeed].
class InMemoryEquipmentRepository implements EquipmentRepository {
  @override
  List<GymEquipment> get gymEquipment => WorkoutSeed.gymEquipment;
}
