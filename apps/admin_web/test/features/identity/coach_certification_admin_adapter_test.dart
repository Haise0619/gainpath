import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/coach_certification_admin_adapter.dart';

void main() {
  test(
      'private certification bytes stay in the selected organization and Coach',
      () {
    const id = '0123456789abcdef0123456789abcdef';
    expect(
        isPrivateCertificationPath(
            'orgs/org/coachCertifications/coach/$id', 'org', 'coach'),
        isTrue);
    for (final path in [
      'orgs/other/coachCertifications/coach/$id',
      'orgs/org/coachCertifications/other/$id',
      'orgs/org/coachCertifications/coach/../$id',
      'https://example.com/$id',
      'orgs/org/coachCertifications/coach/$id/extra',
      null,
    ]) {
      expect(isPrivateCertificationPath(path, 'org', 'coach'), isFalse);
    }
  });
}
