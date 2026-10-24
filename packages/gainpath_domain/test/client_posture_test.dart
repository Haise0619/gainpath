import 'package:test/test.dart';
import 'package:gainpath_domain/coaching.dart';

void main() {
  group('ClientPosture contracts', () {
    test('ClientPostureRequest serializes and deserializes', () {
      final req = ClientPostureRequest(
        organizationId: 'org-1',
        memberId: 'member-1',
      );
      final json = req.toJson();
      final parsed = ClientPostureRequest.fromJson(json);
      expect(parsed.organizationId, 'org-1');
      expect(parsed.memberId, 'member-1');
    });

    test('ClientPostureResult parses valid response', () {
      final json = {
        'schemaVersion': 1,
        'memberId': 'member-1',
        'authorized': true,
        'sharingStatus': 'granted',
        'measurementsStatus': 'measurements_pending_validation',
        'message': 'Cloud measurements pending physical model validation gate.',
        'sessions': [
          {
            'sessionId': 'sess-1',
            'exerciseId': 'ex-1',
            'completedAtMillis': 1700000000000,
            'overallScore': 85,
          }
        ],
      };

      final parsed = ClientPostureResult.fromJson(
        json,
        expectedMemberId: 'member-1',
      );

      expect(parsed.memberId, 'member-1');
      expect(parsed.authorized, true);
      expect(parsed.sharingStatus, 'granted');
      expect(parsed.sessions.length, 1);
      expect(parsed.sessions[0].overallScore, 85);
    });

    test('ClientPostureResult rejects mismatched memberId', () {
      final json = {
        'schemaVersion': 1,
        'memberId': 'member-2',
        'authorized': false,
        'sharingStatus': 'consent_not_granted',
        'measurementsStatus': 'measurements_pending_validation',
        'message': 'No consent',
        'sessions': [],
      };

      expect(
        () => ClientPostureResult.fromJson(json, expectedMemberId: 'member-1'),
        throwsFormatException,
      );
    });
  });
}
