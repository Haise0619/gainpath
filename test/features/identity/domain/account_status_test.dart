import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath/features/identity/domain/enums/account_status.dart';

void main() {
  test('labels round-trip', () {
    for (final s in AccountStatus.values) {
      expect(AccountStatus.fromLabel(s.label), s);
    }
  });
}
