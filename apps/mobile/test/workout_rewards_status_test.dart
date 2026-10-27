import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show SessionScope, BookingException;
import 'package:gainpath_mobile/features/workout/domain/workout_rewards.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/widgets/routine_workout_reward_panel.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_app_check_readiness.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_workout_rewards_repository.dart';

void main() {
  final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
  WorkoutRewardAttemptReference reference({int day = 1, SessionScope? owner}) =>
      WorkoutRewardAttemptReference(
          scope: owner ?? scope,
          attemptId: 'attempt-1',
          routineId: 'routine-1',
          day: day);
  FirebaseAppCheckReadiness ready() => FirebaseAppCheckReadiness(
      mode: 'production',
      supported: true,
      activate: (_) async {},
      token: () async => 'synthetic-token');
  Map<String, dynamic> response() => {
        'schemaVersion': 1,
        'organizationId': 'gainpath',
        'memberId': 'member',
        'status': 'disabled',
        'reason': 'physical_validation_required',
        'policyVersion': 'draft-unconfigured',
        'draftPoints': 100
      };
  test(
      'immutable attempt reference carries identifiers only; local status never grants an award',
      () async {
    final r = reference();
    expect(r.toStatusFields(), {
      'schemaVersion': 1,
      'organizationId': 'gainpath',
      'action': 'status',
      'attemptId': 'attempt-1',
      'routineId': 'routine-1',
      'day': 1
    });
    final local =
        DisabledWorkoutRewardsRepository(scope: scope, isCurrent: () => true);
    final status = await local.status(r);
    expect(status.status, 'disabled');
    expect(status.reason, 'physical_validation_required');
    expect(status.draftPoints, 100);
    expect((await local.status(reference(day: 15))).status, 'disabled');
    final legacy = WorkoutRewardAttemptReference(
        scope: scope,
        attemptId: 'legacy:attempt',
        routineId: 'legacy:routine',
        day: 15);
    expect((await local.status(legacy)).status, 'disabled');
    expect(() => reference(day: 0), throwsArgumentError);
  });
  test(
      'future status operation uses protected exact scoped input without local metrics or claim',
      () async {
    Map<String, dynamic>? sent;
    final repo = FirebaseWorkoutRewardsRepository(
        scope: scope,
        isCurrent: () => true,
        currentUid: () => 'member',
        readiness: ready(),
        call: (name, input) async {
          expect(name, 'workoutRewardCommand');
          sent = input;
          return response();
        });
    expect((await repo.status(reference())).status, 'disabled');
    expect(sent, reference().toStatusFields());
  });
  test(
      'future adapter rejects foreign owner and an activating response during physical hold',
      () async {
    for (final patch in [
      {'memberId': 'other'},
      {'organizationId': 'other'},
      {'schemaVersion': 2},
      {'status': 'awarded'},
      {'reason': 'eligible'},
      {'draftPoints': 0}
    ]) {
      final repo = FirebaseWorkoutRewardsRepository(
          scope: scope,
          isCurrent: () => true,
          currentUid: () => 'member',
          readiness: ready(),
          call: (_, __) async => {...response(), ...patch});
      await expectLater(
          repo.status(reference()), throwsA(isA<BookingException>()));
    }
  });
  test(
      'future status operation rejects unsupported day and foreign reference without sending',
      () async {
    var sent = 0;
    final repo = FirebaseWorkoutRewardsRepository(
        scope: scope,
        isCurrent: () => true,
        currentUid: () => 'member',
        readiness: ready(),
        call: (_, __) async {
          sent++;
          return response();
        });
    await expectLater(
        repo.status(reference(day: 15)), throwsA(isA<BookingException>()));
    await expectLater(
        repo.status(WorkoutRewardAttemptReference(
            scope: scope,
            attemptId: 'legacy:attempt',
            routineId: 'legacy:routine',
            day: 1)),
        throwsA(isA<BookingException>()));
    await expectLater(
        repo.status(reference(
            owner: SessionScope(userId: 'other', organizationId: 'gainpath'))),
        throwsA(isA<BookingException>()));
    expect(sent, 0);
  });
  test('future status discards an in-flight response after account change',
      () async {
    var current = true;
    final entered = Completer<void>(),
        received = Completer<Map<String, dynamic>>();
    final repo = FirebaseWorkoutRewardsRepository(
        scope: scope,
        isCurrent: () => current,
        currentUid: () => 'member',
        readiness: ready(),
        call: (_, __) {
          entered.complete();
          return received.future;
        });
    final pending = repo.status(reference());
    await entered.future;
    current = false;
    received.complete(response());
    await expectLater(pending, throwsA(isA<BookingException>()));
  });
  test(
      'status remains protected by App Check and local status by account scope',
      () async {
    final repo = FirebaseWorkoutRewardsRepository(
        scope: scope,
        isCurrent: () => true,
        currentUid: () => 'member',
        readiness: FirebaseAppCheckReadiness(supported: false),
        call: (_, __) async => throw StateError('Must not send'));
    await expectLater(
        repo.status(reference()), throwsA(isA<BookingException>()));
    final local =
        DisabledWorkoutRewardsRepository(scope: scope, isCurrent: () => false);
    await expectLater(local.status(reference()), throwsStateError);
  });
  testWidgets(
      'hold panel stays distinct, has no claim control and supports large text',
      (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(
        builder: (_, child) => MediaQuery(
            data: const MediaQueryData(
                size: Size(320, 640), textScaler: TextScaler.linear(2)),
            child: child!),
        home: Scaffold(
            body: ListView(children: [
          RoutineWorkoutRewardPanel(
              reference: reference(),
              difficulty: 'Intermediate',
              isCurrent: () => true)
        ]))));
    await t.pumpAndSettle();
    expect(find.text('Workout rewards · Not active'), findsOneWidget);
    expect(find.text('Difficulty: Intermediate'), findsOneWidget);
    expect(find.textContaining('physical validation'), findsOneWidget);
    expect(find.textContaining('Mixed and manual'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(t.takeException(), isNull);
  });
}
