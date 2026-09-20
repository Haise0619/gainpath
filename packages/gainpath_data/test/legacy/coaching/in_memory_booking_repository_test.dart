import 'package:test/test.dart';
import 'package:gainpath_data/src/coaching/in_memory/in_memory_booking_repository.dart';

void main() {
  test('InMemoryBookingRepository serves seed data', () {
    final repo = InMemoryBookingRepository();
    expect(repo.allBookings, isNotEmpty);
    expect(repo.memberBookings, isNotEmpty);
    expect(repo.coachRoster, isNotEmpty);
  });
}
