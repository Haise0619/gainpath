import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/workout/domain/real_workout_contract.dart';
import 'package:gainpath_mobile/features/workout/domain/real_workout_sync.dart';
import 'package:gainpath_mobile/infrastructure/local/file_real_workout_sync_store.dart';

void main() {
  final scope = SessionScope(userId: 'member-1', organizationId: 'gainpath');
  late Directory directory;
  late FileRealWorkoutSyncStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('gainpath-sync-store-');
    store = FileRealWorkoutSyncStore(directory: directory, scope: scope);
  });
  tearDown(() async => directory.delete(recursive: true));

  Future<File> snapshotFile() async => (await directory
          .list(recursive: true)
          .where((item) => item is File && item.path.endsWith('.json'))
          .toList())
      .single as File;

  test('a missing snapshot starts empty without granting consent', () async {
    final state = await store.read();
    expect(state.entries, isEmpty);
    expect(state.consent, isNull);
    expect(state.consentDesired, false);
  });

  test('restart preserves consent and a typed server acceptance', () async {
    final submission = _submission(scope, 'one');
    await store.exclusive(() => store.write(RealWorkoutSyncState(
          consentDesired: true,
          consent: _consent(scope),
          entries: [
            RealWorkoutSyncEntry(
                submission: submission,
                status: RealWorkoutSyncStatus.accepted,
                acceptance: WorkoutAcceptance.fromJson({
                  'schemaVersion': 2,
                  'requestId': 'request-one',
                  'sessionId': 'one',
                  'status': 'accepted',
                  'acceptedAtMillis': 3000,
                })),
          ],
        )));
    final restarted =
        FileRealWorkoutSyncStore(directory: directory, scope: scope);
    final state = await restarted.exclusive(restarted.read);
    expect(state.consentDesired, true);
    expect(state.consent!.acknowledgementId, 'ack-1');
    expect(state.entries.single.status, RealWorkoutSyncStatus.accepted);
    expect(state.entries.single.acceptance!.acceptedAtMillis, 3000);
    expect(state.entries.single.acceptance!.matches(submission), true);
    expect(state.entries.single.submission.scope, scope);
  });

  test('pending revocation and retry information survive replacement',
      () async {
    await store.write(RealWorkoutSyncState(
        consentDesired: true, pendingConsentRequestId: 'first-request'));
    await store.exclusive(() => store.write(RealWorkoutSyncState(
          pendingRevocation: PendingWorkoutRevocation(
              acknowledgement: _consent(scope), requestId: 'revoke-1'),
          entries: [
            RealWorkoutSyncEntry(
                submission: _submission(scope, 'retry'),
                status: RealWorkoutSyncStatus.retryable,
                failureCode: 'unavailable'),
          ],
        )));
    final state =
        await FileRealWorkoutSyncStore(directory: directory, scope: scope)
            .read();
    expect(state.pendingConsentRequestId, isNull);
    expect(state.pendingRevocation!.requestId, 'revoke-1');
    expect(state.entries.single.failureCode, 'unavailable');
    expect(state.consentDesired, false);
  });

  test('case-distinct accounts and organizations never share snapshots',
      () async {
    final scopes = [
      SessionScope(userId: 'Member', organizationId: 'Org'),
      SessionScope(userId: 'member', organizationId: 'Org'),
      SessionScope(userId: 'Member', organizationId: 'org'),
      SessionScope(userId: '../Member', organizationId: 'Org'),
    ];
    for (var i = 0; i < scopes.length; i++) {
      await FileRealWorkoutSyncStore(directory: directory, scope: scopes[i])
          .write(RealWorkoutSyncState(
              consentDesired: true, pendingConsentRequestId: 'consent-$i'));
    }
    for (var i = 0; i < scopes.length; i++) {
      final state =
          await FileRealWorkoutSyncStore(directory: directory, scope: scopes[i])
              .read();
      expect(state.pendingConsentRequestId, 'consent-$i');
    }
  });

  test('cross-account writes are refused without replacing valid state',
      () async {
    await store.write(RealWorkoutSyncState(
        consentDesired: true, pendingConsentRequestId: 'keep-me'));
    final other = SessionScope(userId: 'other', organizationId: 'gainpath');
    for (final state in [
      RealWorkoutSyncState(consentDesired: true, consent: _consent(other)),
      RealWorkoutSyncState(
          pendingRevocation: PendingWorkoutRevocation(
              acknowledgement: _consent(other), requestId: 'revoke-other')),
      RealWorkoutSyncState(entries: [
        RealWorkoutSyncEntry(
            submission: _submission(other, 'other'),
            status: RealWorkoutSyncStatus.pending)
      ]),
    ]) {
      await expectLater(store.write(state), throwsStateError);
      expect((await store.read()).pendingConsentRequestId, 'keep-me');
    }
  });

  test('cross-account state copied onto this path is refused on read',
      () async {
    await store.write(RealWorkoutSyncState());
    final other = SessionScope(userId: 'other', organizationId: 'gainpath');
    await (await snapshotFile()).writeAsString(jsonEncode(
        RealWorkoutSyncState(consentDesired: true, consent: _consent(other))
            .toJson()));
    await expectLater(store.read(), throwsStateError);
  });

  test('forged acceptance and unknown fields fail closed on read', () async {
    await store.write(RealWorkoutSyncState());
    final file = await snapshotFile();
    final pending = RealWorkoutSyncState(entries: [
      RealWorkoutSyncEntry(
          submission: _submission(scope, 'one'),
          status: RealWorkoutSyncStatus.pending)
    ]).toJson();
    final entry = (pending['entries'] as List).single as Map<String, Object?>;
    entry['status'] = 'accepted';
    for (final forged in [
      pending,
      {...RealWorkoutSyncState().toJson(), 'rawPose': []},
      {...RealWorkoutSyncState().toJson(), 'schemaVersion': 999},
      {
        ...RealWorkoutSyncState().toJson(),
        'entries': ['not-an-entry']
      },
    ]) {
      await file.writeAsString(jsonEncode(forged));
      await expectLater(store.read(), throwsFormatException);
    }
  });

  test('corruption is reported instead of silently losing the outbox',
      () async {
    await store.write(RealWorkoutSyncState());
    final file = await snapshotFile();
    await file.writeAsString('{broken');
    await expectLater(store.exclusive(store.read), throwsFormatException);
    expect(await file.readAsString(), '{broken');
  });

  test('an oversized snapshot is refused before decoding', () async {
    await store.write(RealWorkoutSyncState());
    final file = await snapshotFile();
    // Valid JSON must still be rejected by the byte limit, not by decoding.
    await file.writeAsString(
        '${jsonEncode(RealWorkoutSyncState().toJson())}${' ' * (8 * 1024 * 1024)}');
    await expectLater(store.read(), throwsFormatException);
  });

  test('orphan pending data never replaces the last committed snapshot',
      () async {
    await store.write(RealWorkoutSyncState(
        consentDesired: true, pendingConsentRequestId: 'committed'));
    final file = await snapshotFile();
    await File('${file.path}.pending').writeAsString('{interrupted');
    final restarted =
        FileRealWorkoutSyncStore(directory: directory, scope: scope);
    expect((await restarted.read()).pendingConsentRequestId, 'committed');
    await restarted.exclusive(() => restarted.write(RealWorkoutSyncState(
        consentDesired: true, pendingConsentRequestId: 'replacement')));
    expect((await store.read()).pendingConsentRequestId, 'replacement');
  });

  test(
      'independent instances serialize read modify write without losing entries',
      () async {
    final second = FileRealWorkoutSyncStore(directory: directory, scope: scope);
    await Future.wait(List.generate(20, (i) {
      final instance = i.isEven ? store : second;
      return instance.exclusive(() async {
        final state = await instance.read();
        await Future<void>.delayed(const Duration(milliseconds: 2));
        await instance.write(RealWorkoutSyncState(entries: [
          ...state.entries,
          RealWorkoutSyncEntry(
              submission: _submission(scope, 'session-$i'),
              status: RealWorkoutSyncStatus.pending),
        ]));
      });
    }));
    final state = await store.read();
    expect(state.entries, hasLength(20));
    expect(state.entries.map((entry) => entry.submission.sessionId).toSet(),
        {for (var i = 0; i < 20; i++) 'session-$i'});
  });

  test('a failed transaction releases the lock for another instance', () async {
    await expectLater(
        store.exclusive<void>(
            () async => throw StateError('failed transaction')),
        throwsStateError);
    final second = FileRealWorkoutSyncStore(directory: directory, scope: scope);
    await second.exclusive(() => second.write(RealWorkoutSyncState(
        consentDesired: true, pendingConsentRequestId: 'after-failure')));
    expect((await store.read()).pendingConsentRequestId, 'after-failure');
  });
}

WorkoutConsentAcknowledgement _consent(SessionScope scope) =>
    WorkoutConsentAcknowledgement.fromJson({
      'schemaVersion': 1,
      'requestId': 'consent-request-1',
      'organizationId': scope.organizationId,
      'memberId': scope.userId,
      'consentVersion': 'pose-local-summary-v1',
      'acknowledgementId': 'ack-1',
      'acknowledgedAtMillis': 900,
    });

RealWorkoutSubmission _submission(SessionScope scope, String session) =>
    RealWorkoutSubmission.fromJson({
      'schemaVersion': 2,
      'requestId': 'request-$session',
      'organizationId': scope.organizationId,
      'memberId': scope.userId,
      'sessionId': session,
      'exerciseId': 'squat-1',
      'publishedRoutineId': 'routine-1',
      'scoringVersion': 'bodyweight-squat-side-v1',
      'detectorId': 'blazepose-tflite',
      'detectorVersion': 'v1',
      'consentVersion': 'pose-local-summary-v1',
      'consentAcknowledgementId': 'ack-1',
      'provenance': 'real_camera',
      'cameraView': 'side',
      'startedAtMillis': 1000,
      'endedAtMillis': 2000,
      'repetitions': 1,
      'formScorePercent': 95,
      'trackedDurationMillis': 800,
      'rejectedDurationMillis': 200,
    });
