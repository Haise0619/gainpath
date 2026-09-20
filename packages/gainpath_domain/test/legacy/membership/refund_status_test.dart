import 'package:test/test.dart';
import 'package:gainpath_domain/src/membership/enums/refund_status.dart';

void main() {
  test('labels round-trip', () {
    for (final s in RefundStatus.values) {
      expect(RefundStatus.fromLabel(s.label), s);
    }
  });
}
