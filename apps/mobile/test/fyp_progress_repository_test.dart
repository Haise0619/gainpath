import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_fyp_progress_repository.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_contracts.dart';
import 'local_member_progress_repository_test.dart' show measured;
import 'package:gainpath_mobile/features/workout/presentation/member/workout_result_screen.dart';

void main() {
  testWidgets('fixture result never claims a device save or physical capture', (tester) async {
    final summary = WorkoutSessionSummary.fromJson({...measured('fixture-result').toJson(), 'provenance': 'recordedFixture'});
    await tester.pumpWidget(MaterialApp(home: WorkoutResultScreen.measured(summary: summary, fictionalObservation: true)));
    await tester.pumpAndSettle();
    expect(find.text('Fictional recorded observation'), findsOneWidget);
    expect(find.textContaining('no physical camera capture, local save'), findsOneWidget);
    expect(find.text('Saved on this device'), findsNothing);
  });
  final scope = SessionScope(
      userId: 'member',
      organizationId: 'gainpath',
      datasetScope: const VerifiedDatasetScope(
          datasetId: 'fyp-v1',
          seedId: 'gainpath-fyp-v1',
          revision: 1,
          rootPath: 'orgs/gainpath/cohorts/fyp-v1'));
  Map<String, Object?> response(
          {String provenance = 'recordedFixture', String userId = 'member'}) =>
      {
        'schemaVersion': 1,
        'fictional': true,
        'provenance': 'recordedFixture',
        'nextCursor': null,
        'records': [
          {
            'kind': 'session',
            'payload': {
              ...measured('fixture-1').toJson(),
              'provenance': provenance,
              'userId': userId
            }
          }
        ]
      };
  FirebaseFypProgressRepository repository(Object? raw) =>
      FirebaseFypProgressRepository(FypDatasetTransport(
          scope: scope,
          isCurrent: () => true,
          invoke: (name, input) async {
            expect(name, 'fypDatasetCommand');
            expect(input['operation'], 'member.history');
            return raw;
          }));
  test(
      'owned fictional summaries reuse progress calculations and retain fixture provenance',
      () async {
    final snapshot = await repository(response()).load();
    expect(snapshot.records.single.scope, scope);
    expect(snapshot.records.single.status, LocalWorkoutRecordStatus.unknown);
    expect(snapshot.summaries.values.single.provenance,
        WorkoutProvenance.recordedFixture);
    expect(snapshot.warnings.single, contains('not physical camera'));
    final progress = calculateLocalMemberProgress(
        scope: scope,
        records: snapshot.records,
        asOf: DateTime.utc(2026, 10, 13));
    expect(progress.allTimeRepetitions, 4);
    expect(progress.allTimeSessions, 1);
  });
  test(
      'fictional progress rejects camera claims foreign owners and missing provenance',
      () async {
    for (final raw in [
      response(provenance: 'realCamera'),
      response(userId: 'foreign'),
      {...response(), 'fictional': false}
    ]) {
      await expectLater(
          repository(raw).load(), throwsA(isA<FormatException>()));
    }
  });
  test('canonical sessions cannot read fixture progress', () async {
    var called = false;
    final repo = FirebaseFypProgressRepository(FypDatasetTransport(
        scope: SessionScope(userId: 'member', organizationId: 'gainpath'),
        isCurrent: () => true,
        invoke: (_, __) async {
          called = true;
          return response();
        }));
    await expectLater(repo.load(), throwsStateError);
    expect(called, isFalse);
  });
}
