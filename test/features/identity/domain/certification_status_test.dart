import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath/features/identity/domain/enums/certification_status.dart';

void main() {
  test('labels round-trip', () {
    for (final s in CertificationStatus.values) {
      expect(CertificationStatus.fromLabel(s.label), s);
    }
  });
}
