import 'package:test/test.dart';
import 'package:gainpath_domain/src/identity/enums/account_status.dart';

void main() {
  test('labels round-trip', () {
    for (final s in AccountStatus.values) {
      expect(AccountStatus.fromLabel(s.label), s);
    }
  });
}
