import 'package:test/test.dart';
import 'package:gainpath_data/src/workout/in_memory/in_memory_equipment_repository.dart';

void main() {
  test('InMemoryEquipmentRepository serves seed data', () {
    final repo = InMemoryEquipmentRepository();
    expect(repo.gymEquipment, isNotEmpty);
  });
}
