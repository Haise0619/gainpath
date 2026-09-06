import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath/features/membership/domain/enums/refund_status.dart';

void main() {
  test('labels round-trip', () {
    for (final s in RefundStatus.values) {
      expect(RefundStatus.fromLabel(s.label), s);
    }
  });
}
