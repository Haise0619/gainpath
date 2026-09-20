import 'package:test/test.dart';
import 'package:gainpath_domain/src/identity/enums/certification_status.dart';

void main() {
  test('labels round-trip', () {
    for (final s in CertificationStatus.values) {
      expect(CertificationStatus.fromLabel(s.label), s);
    }
  });
}
