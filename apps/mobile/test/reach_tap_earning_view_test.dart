import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/mini_game_details_screen.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/mini_game_participation_panel.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/reach_tap_view.dart';
import 'package:gainpath_mobile/features/gamification/domain/mini_game_launch.dart';
import 'package:gainpath_mobile/features/gamification/application/reach_tap_controller.dart';
import 'fitness_arcade_games_test.dart' show Reader;
import 'reach_tap_controller_test.dart' show TapCamera, TapHistory;
import 'arcade_p1b_results_test.dart' show FinishedEngine;
import 'reach_tap_earning_test.dart' show EarningTiming;
import 'support/reach_tap_participation_fixture.dart';
import 'support/mini_game_participation_fixture.dart';

class ReachParticipation implements MiniGameParticipationRepository {
  @override
  final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
  @override
  bool current = true;
  int claims = 0, earned = 0, claimCalls = 0;
  bool fail = false, wrongGame = false;
  @override
  Future<MiniGameParticipation> overview() async {
    if (fail) throw StateError('offline');
    return MiniGameParticipation.fromJson(
        wrongGame
            ? participationFixture(active: true)
            : reachParticipationFixture(claims: claims, earned: earned),
        scope);
  }

  @override
  Future<MiniGameParticipation> claim(String id) async {
    claimCalls++;
    return MiniGameParticipation.fromJson(
        reachParticipationFixture(
            status: 'awarded',
            attemptId: id,
            balance: 20,
            earned: 20,
            claims: 1),
        scope);
  }
}

void main() {
  testWidgets(
      'Reach Details offers explicit Earn from own game availability and preserves Fun default',
      (t) async {
    final repo = ReachParticipation();
    Object? args;
    await t.pumpWidget(MaterialApp(
        home: MiniGameDetailsScreen(
            content: MiniGameContent.defaults('gainpath',
                gameId: MiniGameContent.reachTapId),
            reader: Reader(),
            participation: repo),
        onGenerateRoute: (settings) {
          args = settings.arguments;
          return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Camera consent')));
        }));
    await t.pumpAndSettle();
    expect(
        t
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Play for fun'))
            .selected,
        true);
    await t.ensureVisible(find.text('Play & Earn'));
    await t.tap(find.text('Play & Earn'));
    await t.pump();
    await t.ensureVisible(find.text('Start playing'));
    await t.tap(find.text('Start playing'));
    await t.pumpAndSettle();
    expect(args, isA<MiniGameLaunchArguments>());
    expect((args as MiniGameLaunchArguments).content.gameId,
        MiniGameContent.reachTapId);
    expect((args as MiniGameLaunchArguments).playAndEarn, true);
    expect(repo.claimCalls, 0);
  });
  for (final failure in ['claimed', 'shared-cap', 'offline', 'other-game']) {
    testWidgets('Reach unavailable $failure never advertises Earn', (t) async {
      final repo = ReachParticipation()
        ..claims = (failure == 'claimed' ? 1 : 0)
        ..earned = (failure == 'shared-cap' ? 60 : 0)
        ..fail = (failure == 'offline')
        ..wrongGame = (failure == 'other-game');
      await t.pumpWidget(MaterialApp(
          home: MiniGameDetailsScreen(
              content: MiniGameContent.defaults('gainpath',
                  gameId: MiniGameContent.reachTapId),
              reader: Reader(),
              participation: repo)));
      await t.pumpAndSettle();
      expect(find.text('Play & Earn'), findsNothing);
      expect(find.text('Play for fun'), findsOneWidget);
      expect(repo.claimCalls, 0);
    });
  }
  testWidgets(
      'Reach points panel shows real selected-game limits without assuming Move claims',
      (t) async {
    final repo = ReachParticipation();
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: MiniGameParticipationPanel(repository: repo)))));
    await t.pumpAndSettle();
    expect(find.text('Complete a round to earn 20 points.'), findsOneWidget);
    expect(
        find.text(
            '20 points per completed round · 1 per game/day · 60 shared daily points.'),
        findsOneWidget);
    expect(repo.claimCalls, 0);
  });
  for (final earn in [false, true]) {
    testWidgets(
        'Reach results show participation status only in explicit Earn $earn',
        (t) async {
      final scope = SessionScope(userId: 'a', organizationId: 'gym');
      final c = ReachTapController(
          scope: scope,
          activeScope: () => scope,
          camera: TapCamera(),
          history: TapHistory(),
          clockMicros: () => 0,
          autoTick: false,
          engine: FinishedEngine(),
          roundTiming: EarningTiming());
      addTearDown(c.dispose);
      c.setRoundTimingConsent(earn);
      c.hasConsent = true;
      await t.pumpWidget(MaterialApp(
          home: ReachTapView(
              controller: c,
              viewport: const SizedBox(),
              participationStatus: const Text('+20 points server confirmed'))));
      await t.pumpAndSettle();
      expect(find.text('+20 points server confirmed'),
          earn ? findsOneWidget : findsNothing);
      expect(find.text('Reward Points · Not participating'),
          earn ? findsNothing : findsOneWidget);
      expect(find.text('30'), findsOneWidget);
    });
  }
}
