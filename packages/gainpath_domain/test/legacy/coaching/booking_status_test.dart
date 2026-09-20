import 'package:test/test.dart';
import 'package:gainpath_domain/src/coaching/enums/booking_status.dart';

void main() {
  test('labels round-trip', () {
    for (final s in BookingStatus.values) {
      expect(BookingStatus.fromLabel(s.label), s);
    }
  });
}
