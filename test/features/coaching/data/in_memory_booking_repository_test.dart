import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath/features/coaching/data/in_memory/in_memory_booking_repository.dart';

void main() {
  test('InMemoryBookingRepository serves seed data', () {
    final repo = InMemoryBookingRepository();
    expect(repo.allBookings, isNotEmpty);
    expect(repo.memberBookings, isNotEmpty);
    expect(repo.coachRoster, isNotEmpty);
  });
}
