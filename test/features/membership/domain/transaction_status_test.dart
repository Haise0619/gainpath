import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath/features/membership/domain/enums/transaction_status.dart';

void main() {
  test('labels round-trip', () {
    for (final s in TransactionStatus.values) {
      expect(TransactionStatus.fromLabel(s.label), s);
    }
  });
}
