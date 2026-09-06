import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath/features/workout/data/in_memory/in_memory_equipment_repository.dart';

void main() {
  test('InMemoryEquipmentRepository serves seed data', () {
    final repo = InMemoryEquipmentRepository();
    expect(repo.gymEquipment, isNotEmpty);
  });
}
