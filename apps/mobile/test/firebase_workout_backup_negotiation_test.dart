import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/workout/domain/workout_backup.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_workout_backup_gateway.dart';
import 'routine_journey_controller_test.dart' as fixture;

void main() {
  final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
  test(
      'gateway lists with schema-six capability and preserves empty-page cursor',
      () async {
    final calls = <Map<String, Object?>>[];
    final gateway = FirebaseWorkoutBackupGateway(
        scope: scope,
        activeAccount: () => true,
        invoke: (input) async {
          calls.add(input);
          return {
            'schemaVersion': 1,
            'records': <Object?>[],
            'nextCursor': 'session-c'
          };
        });
    final page = await gateway.list('session-a');
    expect(calls.single, {
      'action': 'list',
      'command': {
        'schemaVersion': 1,
        'organizationId': 'gainpath',
        'memberId': 'member',
        'consented': true,
        'after': 'session-a',
        'maxPoseMetricsSchemaVersion': 6,
      }
    });
    expect(page.records, isEmpty);
    expect(page.nextCursor, 'session-c');
  });
  test('gateway keeps schema negotiation out of save requests', () async {
    final record = WorkoutBackupRecord.session(fixture.measured(scope, 's'));
    final calls = <Map<String, Object?>>[];
    final gateway = FirebaseWorkoutBackupGateway(
        scope: scope,
        activeAccount: () => true,
        invoke: (input) async {
          calls.add(input);
          return {
            'schemaVersion': 1,
            'status': 'backed_up',
            'kind': record.kind,
            'id': record.id,
            'digest': record.digest
          };
        });
    expect(await gateway.save(record, null), record.digest);
    expect(calls.single, {
      'action': 'save',
      'command': {
        'schemaVersion': 1,
        'organizationId': 'gainpath',
        'memberId': 'member',
        'consented': true,
        'kind': record.kind,
        'id': record.id,
        'baseDigest': null,
        'payload': record.payload,
      }
    });
  });
}
