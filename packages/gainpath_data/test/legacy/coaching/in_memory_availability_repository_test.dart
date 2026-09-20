import 'package:test/test.dart';
import 'package:gainpath_data/src/coaching/in_memory/in_memory_availability_repository.dart';

void main() {
  test('InMemoryAvailabilityRepository serves seed data', () {
    final repo = InMemoryAvailabilityRepository();
    expect(repo.workingDays, isNotEmpty);
    expect(repo.blockedSlots, isNotEmpty);
  });
}
