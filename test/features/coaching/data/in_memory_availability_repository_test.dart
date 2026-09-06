import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath/features/coaching/data/in_memory/in_memory_availability_repository.dart';

void main() {
  test('InMemoryAvailabilityRepository serves seed data', () {
    final repo = InMemoryAvailabilityRepository();
    expect(repo.workingDays, isNotEmpty);
    expect(repo.blockedSlots, isNotEmpty);
  });
}
