import 'package:gainpath_data/gamification.dart';
import 'package:gainpath_data/coaching.dart';
import 'package:test/test.dart';

void main() {
  test('points mutations cannot escape a default repository', () {
    final first = InMemoryGamificationRepository();
    final second = InMemoryGamificationRepository();
    final initial = second.points;

    first.addPoints(123);

    expect(first.points, initial + 123);
    expect(second.points, initial);
    expect(InMemoryGamificationRepository().points, initial);
  });

  test('nested booking messages cannot escape a default repository', () {
    final first = InMemoryBookingRepository();
    final second = InMemoryBookingRepository();
    final initial = second.allBookings.first.messages.length;

    first.allBookings.first.messages.clear();

    expect(first.allBookings.first.messages, isEmpty);
    expect(second.allBookings.first.messages, hasLength(initial));
    expect(InMemoryBookingRepository().allBookings.first.messages,
        hasLength(initial));
  });
}
