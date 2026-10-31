import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/analytics/application/member_progress_cubit.dart';
import 'package:gainpath_mobile/features/analytics/domain/local_member_progress_repository.dart';

final scope = SessionScope(userId: 'one', organizationId: 'gainpath');

class Repository implements LocalMemberProgressRepository {
  @override
  SessionScope get scope => scopeValue;
  final scopeValue = SessionScope(userId: 'one', organizationId: 'gainpath');
  Future<LocalMemberProgressSnapshot> Function() read =
      () async => LocalMemberProgressSnapshot(records: []);
  @override
  Future<LocalMemberProgressSnapshot> load() => read();
}

LocalMemberProgressSnapshot sample() => LocalMemberProgressSnapshot(records: [
      LocalWorkoutProgressRecord(
          scope: scope,
          sessionId: 'one',
          exerciseId: 'squat',
          startedAt: DateTime.utc(2026, 10, 11, 15, 59),
          endedAt: DateTime.utc(2026, 10, 11, 15, 59, 10),
          repetitions: 2,
          partialRepetitions: 0,
          trackedDurationMicros: 5000000,
          rejectedDurationMicros: 0,
          formScorePercent: null,
          scoringVersion: 'v1',
          detectorId: 'pose',
          detectorVersion: 'one',
          cameraView: 'side',
          status: LocalWorkoutRecordStatus.localOnly)
    ]);
void main() {
  test(
      'refresh retains readable local snapshot during delayed read and failure',
      () async {
    final repo = Repository()..read = () async => sample();
    final c = MemberProgressCubit(repository: repo, activeScope: () => scope);
    await c.load();
    final snapshot = c.state.snapshot;
    final waiting = Completer<LocalMemberProgressSnapshot>();
    repo.read = () => waiting.future;
    final refresh = c.load();
    expect(c.state.progress!.allTimeSessions, 1);
    expect(c.state.snapshot, same(snapshot));
    waiting.completeError(StateError('offline local storage'));
    await refresh;
    expect(c.state.progress!.allTimeSessions, 1);
    expect(c.state.error, isNotNull);
    await c.close();
  });
  test(
      'ready state uses clock and explicit Malaysia week instead of machine timezone',
      () async {
    final repo = Repository()..read = () async => sample();
    var now = DateTime.utc(2026, 10, 11, 15, 59, 30);
    final c = MemberProgressCubit(
        repository: repo, activeScope: () => scope, clock: () => now);
    await c.load();
    expect(c.state.progress!.weeklySessions, 1);
    now = DateTime.utc(2026, 10, 11, 16);
    await c.load();
    expect(c.state.progress!.weeklySessions, 0);
    expect(c.state.progress!.allTimeSessions, 1);
    await c.close();
  });
  test(
      'account invalidation hides data immediately and discards pending results',
      () async {
    final repo = Repository()..read = () async => sample();
    SessionScope? active = scope;
    final c = MemberProgressCubit(repository: repo, activeScope: () => active);
    await c.load();
    expect(c.state.progress, isNotNull);
    final waiting = Completer<LocalMemberProgressSnapshot>();
    repo.read = () => waiting.future;
    final pending = c.load();
    active = null;
    c.accountChanged();
    expect(c.state.progress, isNull);
    expect(c.state.status, MemberProgressStatus.inactive);
    waiting.complete(sample());
    await pending;
    expect(c.state.progress, isNull);
    await c.close();
  });
  test('newer refresh wins over old asynchronous snapshot', () async {
    final repo = Repository();
    final old = Completer<LocalMemberProgressSnapshot>();
    repo.read = () => old.future;
    final c = MemberProgressCubit(repository: repo, activeScope: () => scope);
    final pending = c.load();
    repo.read = () async => LocalMemberProgressSnapshot(records: []);
    await c.load();
    old.complete(sample());
    await pending;
    expect(c.state.progress!.allTimeSessions, 0);
    await c.close();
  });
  test(
      'local read errors show failure rather than a fabricated empty dashboard',
      () async {
    final repo = Repository()
      ..read = () => Future.error(const FormatException('broken'));
    final c = MemberProgressCubit(repository: repo, activeScope: () => scope);
    await c.load();
    expect(c.state.status, MemberProgressStatus.failure);
    expect(c.state.progress, isNull);
    expect(c.state.error, isNotNull);
    await c.close();
  });
}
