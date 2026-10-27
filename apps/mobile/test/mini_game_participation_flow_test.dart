import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_mobile/features/gamification/application/mini_game_round_coordinator.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/mini_game_participation_panel.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_mini_game_participation_repository.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_app_check_readiness.dart';
import 'mini_game_round_coordinator_test.dart' show Repo;
import 'support/mini_game_participation_fixture.dart';

class ParticipationRepo implements MiniGameParticipationRepository {
  @override
  final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
  @override
  bool current = true;
  var claims = 0;
  bool active = true, fail = false;
  String status = 'awarded';
  Completer<MiniGameParticipation>? pending;
  MiniGameParticipation response(
          {String status = 'overview', String? attemptId}) =>
      MiniGameParticipation.fromJson(
          participationFixture(
              status: status,
              active: active,
              attemptId: attemptId,
              balance: claims == 0 ? 0 : 20,
              earned: claims == 0 ? 0 : 20),
          scope);
  @override
  Future<MiniGameParticipation> overview() async => response();
  @override
  Future<MiniGameParticipation> claim(String attemptId) async {
    claims++;
    if (fail) throw const MiniGameParticipationUnavailable();
    return pending == null
        ? response(status: active ? status : 'not-active', attemptId: attemptId)
        : await pending!.future;
  }
}

class SwitchingReadiness extends FirebaseAppCheckReadiness {
  SwitchingReadiness(this.switchUser);
  final void Function() switchUser;
  bool afterCheck = false;
  @override
  Future<bool> ensureReady({void Function()? check}) async {
    switchUser();
    check?.call();
    afterCheck = true;
    return true;
  }
}

void main() {
  testWidgets(
      'details show used per-game allowance before playing another round',
      (tester) async {
    final repo = ParticipationRepo()..claims = 1;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: MiniGameParticipationPanel(repository: repo)))));
    await tester.pump();
    expect(
        find.text(
            'Today’s points earned. Keep playing for your personal best.'),
        findsOneWidget);
    expect(find.text('Complete a round to earn 20 points.'), findsNothing);
  });
  testWidgets(
      'failed round timing finish can retry before claiming participation',
      (tester) async {
    final timingRepo = Repo()..failFinish = true, repo = ParticipationRepo();
    var now = 0;
    final timing = MiniGameRoundCoordinator(
        repository: timingRepo,
        clockMillis: () => now,
        requestId: () => 'c' * 32);
    addTearDown(timing.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: MiniGameParticipationPanel(
                    repository: repo, roundTiming: timing)))));
    await tester.pump();
    timing.start();
    await tester.pump();
    for (var i = 1; i <= 20; i++) {
      now = i * 2000;
      timing.observe(activeMillis: now, playing: true);
      await tester.pump();
    }
    timing.finish();
    await tester.pump();
    await tester.pump();
    expect(repo.claims, 0);
    expect(find.text('Retry round timing'), findsOneWidget);
    timingRepo.failFinish = false;
    await tester.ensureVisible(find.text('Retry round timing'));
    await tester.tap(find.text('Retry round timing'));
    await tester.pump();
    await tester.pump();
    expect(repo.claims, 1);
    expect(find.text('+20 points earned'), findsOneWidget);
  });
  for (final claimStatus in ['awarded', 'already-awarded'])
    testWidgets(
        'complete round shows $claimStatus once and opens shared history',
        (tester) async {
      final timingRepo = Repo(),
          repo = ParticipationRepo()..status = claimStatus;
      var openedHistory = 0;
      var now = 0;
      final timing = MiniGameRoundCoordinator(
          repository: timingRepo,
          clockMillis: () => now,
          requestId: () => 'c' * 32);
      addTearDown(timing.dispose);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: MiniGameParticipationPanel(
                      repository: repo,
                      roundTiming: timing,
                      onHistory: () => openedHistory++)))));
      await tester.pump();
      expect(repo.claims, 0);
      timing.start();
      await tester.pump();
      for (var i = 1; i <= 20; i++) {
        now = i * 2000;
        timing.observe(activeMillis: now, playing: true);
        await tester.pump();
      }
      timing.finish();
      await tester.pump();
      await tester.pump();
      expect(repo.claims, 1);
      expect(
          find.text(claimStatus == 'awarded'
              ? '+20 points earned'
              : 'This round’s 20 points were already credited.'),
          findsOneWidget);
      expect(find.text('20 points balance'), findsOneWidget);
      expect(find.text('40 remaining today'), findsOneWidget);
      expect(find.text('Demo · Not redeemable'), findsNothing);
      await tester.ensureVisible(find.text('View Points History'));
      await tester.tap(find.text('View Points History'));
      expect(openedHistory, 1);
      timing.finish();
      await tester.pump();
      expect(repo.claims, 1);
      expect(tester.takeException(), isNull);
    });
  testWidgets(
      'inactive, capped and failed claims never invent award confirmation',
      (tester) async {
    final repo = ParticipationRepo()..active = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: MiniGameParticipationPanel(repository: repo))));
    await tester.pump();
    expect(find.text('Game rewards are not active yet.'), findsOneWidget);
    expect(find.text('+20 points earned'), findsNothing);
    expect(find.textContaining('not physically verified'), findsNothing);
  });
  testWidgets(
      'uncertain claim retains attempt for explicit retry without automatic repeat',
      (tester) async {
    final timingRepo = Repo(), repo = ParticipationRepo()..fail = true;
    var now = 0;
    final timing = MiniGameRoundCoordinator(
        repository: timingRepo,
        clockMillis: () => now,
        requestId: () => 'c' * 32);
    addTearDown(timing.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: MiniGameParticipationPanel(
                    repository: repo, roundTiming: timing)))));
    await tester.pump();
    timing.start();
    await tester.pump();
    for (var i = 1; i <= 20; i++) {
      now = i * 2000;
      timing.observe(activeMillis: now, playing: true);
      await tester.pump();
    }
    timing.finish();
    await tester.pump();
    await tester.pump();
    expect(repo.claims, 1);
    expect(find.textContaining('No new points are confirmed'), findsOneWidget);
    repo.fail = false;
    await tester.ensureVisible(find.text('Retry participation update'));
    await tester.tap(find.text('Retry participation update'));
    await tester.pump();
    expect(repo.claims, 2);
    expect(find.text('+20 points earned'), findsOneWidget);
  });
  testWidgets(
      'participation panel fits320px double text and hides expired scope',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = ParticipationRepo();
    Widget app() => MaterialApp(
        builder: (_, child) => MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: child!),
        home: Scaffold(
            body: SingleChildScrollView(
                child: MiniGameParticipationPanel(repository: repo))));
    await tester.pumpWidget(app());
    await tester.pump();
    expect(tester.takeException(), isNull);
    repo.current = false;
    await tester.pumpWidget(app());
    await tester.pump();
    expect(find.text('Participation points'), findsNothing);
  });
  test(
      'Firebase UID change during readiness never submits a claim as a different account',
      () async {
    String? uid = 'member';
    final readiness = SwitchingReadiness(() => uid = 'other');
    final repo = FirebaseMiniGameParticipationRepository(
        scope: SessionScope(userId: 'member', organizationId: 'gainpath'),
        isCurrent: () => true,
        currentUid: () => uid,
        readiness: readiness);
    await expectLater(repo.claim('a' * 32),
        throwsA(isA<MiniGameParticipationSessionChanged>()));
    expect(readiness.afterCheck, false);
  });
}
