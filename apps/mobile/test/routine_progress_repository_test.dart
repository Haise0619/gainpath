import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/analytics/data/local_member_progress_repository.dart';
import 'package:gainpath_mobile/features/analytics/application/member_progress_cubit.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'package:gainpath_mobile/features/workout/domain/real_workout_sync.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_journey.dart';
import 'routine_journey_controller_test.dart' as support;
import 'routine_history_ui_test.dart' as ui;

class ControlledStore extends support.MemoryJourneyStore {
  ControlledStore(super.scope);
  final wait = Completer<void>();
  bool delayed = false, broken = false;
  @override
  Future<List<RoutineCheckpoint>> load() async {
    if (delayed) await wait.future;
    if (broken) throw StateError('broken');
    return super.load();
  }
}

void main() {
  final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
  late ControlledStore journeys;
  SessionScope? active;
  StoredLocalMemberProgressRepository repository() =>
      StoredLocalMemberProgressRepository(
          scope: scope,
          workoutStore: InMemoryWorkoutSessionStore(scope: scope),
          syncStore: MemoryRealWorkoutSyncStore(scope: scope),
          routineStore: journeys,
          activeScope: () => active);
  setUp(() {
    active = scope;
    journeys = ControlledStore(scope);
  });
  void seed() {
    final a = ui.attempt();
    journeys.records[a.id] = RoutineCheckpoint(
        id: a.id,
        scope: scope,
        routineId: a.routine.id,
        planSignature: 'test',
        day: a.day,
        selectedIndex: 0,
        updatedAtMicros: a.updatedAtMicros,
        startedAtMicros: a.startedAtMicros,
        finished: a.finished,
        attempt: a);
  }

  test('routine activity appears without creating camera results', () async {
    seed();
    final repo = repository();
    final snapshot = await repo.load();
    expect(snapshot.attempts.single.isComplete, true);
    expect(snapshot.records, isEmpty);
    expect(snapshot.routineHistoryAvailable, true);
    final c = MemberProgressCubit(
        repository: repo,
        activeScope: () => active,
        clock: () => DateTime.utc(2026, 10, 25, 15, 1));
    await c.load();
    expect(c.state.routines!.weeklyCompleted, 1);
    expect(c.state.progress!.weeklySessions, 0);
    await c.close();
  });
  test('unreadable routine history does not invent zero completion', () async {
    journeys.broken = true;
    final c = MemberProgressCubit(
        repository: repository(), activeScope: () => active);
    await c.load();
    expect(c.state.status, MemberProgressStatus.ready);
    expect(c.state.routines, isNull);
    expect(c.state.snapshot!.warnings.single, contains('Routine history'));
    await c.close();
  });
  test('account switch during routine read discards delayed data', () async {
    seed();
    journeys.delayed = true;
    final c = MemberProgressCubit(
        repository: repository(), activeScope: () => active);
    final reading = c.load();
    await Future<void>.delayed(Duration.zero);
    active = null;
    c.accountChanged();
    journeys.wait.complete();
    await reading;
    expect(c.state.status, MemberProgressStatus.inactive);
    expect(c.state.routines, isNull);
    await c.close();
  });
}
