import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_module9_repository.dart';

void main() {
  test('one malformed notice cannot hide a valid automatic or outreach notice',
      () {
    final valid = {
      'id': 'notice',
      'title': 'Jackson',
      'message': 'View recommendation',
      'read': false,
      'createdAtMillis': 1794997895479,
      'bookingId': null,
      'recommendation': {
        'schemaVersion': 1,
        'recommendationId': 'a' * 64,
        'kind': 'trainer',
        'state': 'available',
        'expiresAtMillis': 1796207495479,
        'target': {
          'kind': 'trainer',
          'coachId': 'coach',
          'branchId': 'main',
          'observedStartAtMillis': 1795057200000,
          'observedEndAtMillis': 1795060800000
        }
      }
    };
    final page = parseMemberNoticePage({
      'records': [
        {'id': 'broken'},
        valid
      ],
      'nextAfterId': 'cursor'
    }, 'gainpath');
    expect(page.records.length, 1);
    expect(page.records.single.recommendation!.recommendationId, 'a' * 64);
    expect(page.nextAfterId, 'cursor');
  });
}
