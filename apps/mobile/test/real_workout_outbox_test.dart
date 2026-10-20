import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/workout/domain/real_workout_contract.dart';
import 'package:gainpath_mobile/features/workout/domain/real_workout_sync.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_contracts.dart';
import 'package:gainpath_mobile/features/workout/data/real_workout_outbox_repository.dart';

final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
final ackJson = <String, Object?>{
  'schemaVersion': 1,
  'requestId': 'consent-request',
  'organizationId': 'gainpath',
  'memberId': 'member',
  'consentVersion': workoutConsentVersion,
  'acknowledgementId': 'ack',
  'acknowledgedAtMillis': 1000
};
WorkoutSessionSummary measured(
        {WorkoutProvenance provenance = WorkoutProvenance.realCamera,
        int start = 2000}) =>
    WorkoutSessionSummary(
        sessionId: 'session',
        userId: 'member',
        organizationId: 'gainpath',
        exerciseId: 'squat',
        repetitions: 1,
        accuracy: 90,
        startedAt: DateTime.fromMillisecondsSinceEpoch(start, isUtc: true),
        endedAt: DateTime.fromMillisecondsSinceEpoch(start + 2000, isUtc: true),
        provenance: provenance,
        poseMetrics: WorkoutPoseMetrics(
            partialRepetitions: 0,
            trackedDurationMicros: 1800000,
            rejectedDurationMicros: 200000,
            formScorePercent: 90,
            scoringVersion: 'bodyweight-squat-side-v1',
            detectorId: 'blazepose-tflite',
            detectorVersion: 'v1',
            cameraView: 'side',
            consentVersion: workoutConsentVersion,
            consentedAt:
                DateTime.fromMillisecondsSinceEpoch(start, isUtc: true),
            publishedRoutineId: 'routine'));

class Gateway implements RealWorkoutGateway {
  int submissions = 0, grants = 0, revocations = 0;
  String? failure;
  Completer<void>? pending;
  bool badReceipt = false;
  @override
  Future<WorkoutConsentAcknowledgement> acknowledge(
      SessionScope s, String requestId) async {
    grants++;
    await pending?.future;
    return WorkoutConsentAcknowledgement.fromJson(
        {...ackJson, 'requestId': requestId});
  }

  @override
  Future<void> revoke(
      WorkoutConsentAcknowledgement ack, String requestId) async {
    revocations++;
  }

  @override
  Future<WorkoutAcceptance> submit(RealWorkoutSubmission payload) async {
    submissions++;
    await pending?.future;
    if (failure != null) throw WorkoutGatewayFailure(failure!);
    return WorkoutAcceptance.fromJson({
      'schemaVersion': 2,
      'requestId': payload.toJson()['requestId'],
      'sessionId': badReceipt ? 'wrong' : payload.sessionId,
      'status': 'accepted',
      'acceptedAtMillis': 5000
    });
  }
}

class ReceiptFailingStore extends MemoryRealWorkoutSyncStore {
  ReceiptFailingStore({required super.scope});
  bool failReceipt = true;
  @override
  Future<void> write(RealWorkoutSyncState state) async {
    if (failReceipt &&
        state.entries.any((e) => e.status == RealWorkoutSyncStatus.accepted)) {
      throw StateError('receipt disk full');
    }
    await super.write(state);
  }
}

void main() {
  late Gateway gateway;
  late MemoryRealWorkoutSyncStore store;
  late RealWorkoutOutboxRepository repo;
  SessionScope? active;
  int ids = 0;
  void setup() {
    active = scope;
    ids = 0;
    gateway = Gateway();
    store = MemoryRealWorkoutSyncStore(scope: scope);
    repo = RealWorkoutOutboxRepository(
        scope: scope,
        activeScope: () => active,
        store: store,
        gateway: gateway,
        newRequestId: () => 'request-${++ids}');
  }

  test('accepted status is never published before its receipt is durable',
      () async {
    setup();
    repo.dispose();
    final disk = ReceiptFailingStore(scope: scope);
    repo = RealWorkoutOutboxRepository(
        scope: scope,
        activeScope: () => active,
        store: disk,
        gateway: gateway,
        newRequestId: () => 'receipt-request');
    await repo.load();
    final ack = (await repo.acknowledgeConsent())!;
    await repo.enqueue(measured(), ack);
    final request = repo.entries.single.submission.toJson()['requestId'];
    await expectLater(repo.sync(), throwsStateError);
    expect(repo.entries.single.status, RealWorkoutSyncStatus.pending);
    expect((await disk.read()).entries.single.acceptance, isNull);
    disk.failReceipt = false;
    await repo.sync();
    expect(repo.entries.single.status, RealWorkoutSyncStatus.accepted);
    expect(repo.entries.single.submission.toJson()['requestId'], request);
    expect(gateway.submissions, 2);
    repo.dispose();
  });
  test(
      'immediate revocation wins over consent initialization before load returns',
      () async {
    setup();
    final grant = repo.acknowledgeConsent();
    final revoke = repo.revokeConsent();
    await revoke;
    expect(await grant, isNull);
    expect(repo.consent, isNull);
    expect((await store.read()).consentDesired, false);
    expect(gateway.grants, 0);
    repo.dispose();
  });

  test(
      'consent before capture is mandatory; fixture and legacy cannot enter v2 outbox',
      () async {
    setup();
    await repo.load();
    final ack = await repo.acknowledgeConsent();
    expect(ack, isNotNull);
    expect(await repo.enqueue(measured(start: 500), ack!), false);
    expect(
        await repo.enqueue(
            measured(provenance: WorkoutProvenance.recordedFixture), ack),
        false);
    expect(await repo.enqueue(measured(), ack), true);
    expect(repo.entries.single.status, RealWorkoutSyncStatus.pending);
    expect(
        repo.entries.single.submission
            .toJson()
            .containsKey('partialRepetitions'),
        false);
    repo.dispose();
  });
  test('retry persists immutable request and acceptance across restart',
      () async {
    setup();
    await repo.load();
    final ack = (await repo.acknowledgeConsent())!;
    await repo.enqueue(measured(), ack);
    final payload = repo.entries.single.submission.toJson();
    gateway.failure = 'unavailable';
    await repo.sync();
    expect(repo.entries.single.status, RealWorkoutSyncStatus.retryable);
    repo.dispose();
    repo = RealWorkoutOutboxRepository(
        scope: scope,
        activeScope: () => active,
        store: store,
        gateway: gateway,
        newRequestId: () => 'new-id');
    await repo.load();
    expect(repo.entries.single.submission.toJson(), payload);
    gateway.failure = null;
    await repo.sync();
    expect(repo.entries.single.status, RealWorkoutSyncStatus.accepted);
    expect(repo.entries.single.acceptance!.sessionId, 'session');
    await repo.sync();
    expect(gateway.submissions, 2);
    repo.dispose();
  });
  test('permanent rejection and mismatched receipt never claim acceptance',
      () async {
    setup();
    await repo.load();
    final ack = (await repo.acknowledgeConsent())!;
    await repo.enqueue(measured(), ack);
    gateway.badReceipt = true;
    await repo.sync();
    expect(repo.entries.single.status, RealWorkoutSyncStatus.rejected);
    expect(repo.entries.single.acceptance, isNull);
    await repo.sync();
    expect(gateway.submissions, 1);
    repo.dispose();
  });
  test('revocation preserves a valid late receipt without restoring consent',
      () async {
    setup();
    await repo.load();
    final ack = (await repo.acknowledgeConsent())!;
    await repo.enqueue(measured(), ack);
    gateway.pending = Completer<void>();
    final syncing = repo.sync();
    await Future<void>.delayed(Duration.zero);
    await repo.revokeConsent();
    expect(repo.consent, isNull);
    gateway.pending!.complete();
    await syncing;
    expect(repo.entries.single.status, RealWorkoutSyncStatus.accepted);
    expect(repo.consent, isNull);
    repo.dispose();
  });
  test('durable pre-capture intent recovers save-before-enqueue after restart',
      () async {
    setup();
    await repo.load();
    final ack = (await repo.acknowledgeConsent())!;
    await repo.prepareCapture('session', ack);
    repo.dispose();
    repo = RealWorkoutOutboxRepository(
        scope: scope,
        activeScope: () => active,
        store: store,
        gateway: gateway,
        newRequestId: () => 'recovered-request');
    await repo.load();
    expect(await repo.enqueueFromIntent(measured()), true);
    expect(repo.entries.single.submission.sessionId, 'session');
    expect((await store.read()).captureIntents, isEmpty);
    repo.dispose();
  });
  test('account change drops delayed consent and submission publication',
      () async {
    setup();
    await repo.load();
    gateway.pending = Completer<void>();
    final grant = repo.acknowledgeConsent();
    await Future<void>.delayed(Duration.zero);
    active = SessionScope(userId: 'other', organizationId: 'gainpath');
    gateway.pending!.complete();
    expect(await grant, isNull);
    expect(repo.consent, isNull);
    repo.dispose();
  });
  test('revocation while consent is in flight records a durable revoke command',
      () async {
    setup();
    await repo.load();
    gateway.pending = Completer<void>();
    final grant = repo.acknowledgeConsent();
    await Future<void>.delayed(Duration.zero);
    await repo.revokeConsent();
    gateway.pending!.complete();
    expect(await grant, isNull);
    expect(repo.consent, isNull);
    await repo.sync();
    expect(gateway.revocations, 1);
    repo.dispose();
  });
}
