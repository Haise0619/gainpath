import 'package:test/test.dart';
import 'package:gainpath_domain/src/membership/enums/transaction_status.dart';

void main() {
  test('labels round-trip', () {
    for (final s in TransactionStatus.values) {
      expect(TransactionStatus.fromLabel(s.label), s);
    }
  });
}
