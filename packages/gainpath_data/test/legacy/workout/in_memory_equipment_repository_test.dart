import 'package:test/test.dart';
import 'package:gainpath_data/src/workout/in_memory/in_memory_equipment_repository.dart';
import 'package:gainpath_domain/workout.dart';

void main() {
  test('InMemoryEquipmentRepository serves seed data', () {
    final repo = InMemoryEquipmentRepository();
    expect(repo.gymEquipment, isNotEmpty);
  });
  test('mock CRUD preserves existing equipment and rejects a stale edit',
      () async {
    final repo = InMemoryEquipmentRepository();
    final ids = repo.gymEquipment.map((e) => e.id).toList();
    final created = await repo.saveEquipment(GymEquipment(
        id: '',
        name: 'Mock equipment',
        category: 'Legs',
        muscleGroup: 'Legs',
        description: 'Fixture',
        imageUrl: '',
        howToUse: [],
        safetyTips: []));
    final updated =
        await repo.saveEquipment(created.copyWith()..name = 'Edited');
    await expectLater(
        repo.saveEquipment(created), throwsA(isA<EquipmentConflict>()));
    final inactive =
        await repo.saveEquipment(updated.copyWith(isActive: false));
    expect(inactive.isActive, false);
    expect(
        (await repo.loadEquipment()).items.map((e) => e.id), containsAll(ids));
  });
}
