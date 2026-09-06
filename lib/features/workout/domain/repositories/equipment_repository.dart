import 'package:gainpath/features/workout/domain/entities/gym_equipment.dart';

/// Data access contract for the workout feature. Implemented in-memory for the
/// prototype; a Firebase implementation will sit behind the same interface.
abstract class EquipmentRepository {
  List<GymEquipment> get gymEquipment;
}
