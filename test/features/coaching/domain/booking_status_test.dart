import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath/features/coaching/domain/enums/booking_status.dart';

void main() {
  test('labels round-trip', () {
    for (final s in BookingStatus.values) {
      expect(BookingStatus.fromLabel(s.label), s);
    }
  });
}
