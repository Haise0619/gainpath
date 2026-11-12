import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_mobile/app/member_typography_theme.dart';
import 'package:gainpath_mobile/features/gamification/domain/app_check_in.dart';
import 'package:gainpath_mobile/features/gamification/application/app_check_in_cubit.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/app_check_in_dashboard.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/fitness_arcade_rank.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/locked_rewards_preview.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/reward_goal_card.dart';
import '../../../test_support/fyp_render_support.dart';
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;
import 'app_check_in_test.dart' show snapshotJson;
import 'reward_goal_card_test.dart' show GoalRewards, Goals;
import 'free_rewards_locked_preview_test.dart' show PreviewContentReader;

void main() {
  setUpAll(loadDemoRenderFonts);
  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('Free rewards locked previews at $width / $scale', (t) async {
        addTearDown(await installFypOfflineFonts());
        t.view.physicalSize = Size(width, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        const coverDirectory = String.fromEnvironment('GAINPATH_GAME_COVER_DIR');
        if (coverDirectory.isNotEmpty) {
          for (final id in [
            MiniGameContent.supportedId,
            MiniGameContent.reachTapId
          ]) {
            final file = File('$coverDirectory/$id.cover');
            await t.runAsync(() async {
              final codec =
                  await ui.instantiateImageCodec(await file.readAsBytes());
              final frame = await codec.getNextFrame();
              PaintingBinding.instance.imageCache.putIfAbsent(
                  NetworkImage('https://example.invalid/$id.png'),
                  () => OneFrameImageStreamCompleter(
                      Future.value(ImageInfo(image: frame.image))));
              codec.dispose();
            });
          }
        }
        final scope =
            SessionScope(userId: 'free-render', organizationId: 'gainpath');
        final repo = GoalRewards()
          ..data = const VerifiedRewardsSnapshot(
              available: true,
              balance: 0,
              effectiveTier: 'free',
              canRedeem: false,
              items: [
                VerifiedRewardItem(
                    itemId: 'bottle',
                    title: 'Training bottle',
                    pointCost: 250,
                    stock: 3,
                    premiumOnly: false)
              ],
              redemptions: []);
        var claims = 0, plans = 0;
        const boundary = ValueKey('free-rewards-render');
        await t.pumpWidget(RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildMemberTypographyTheme(),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                      disableAnimations: true),
                  child: child!),
              home: AppCheckInDashboard(
                state: AppCheckInState(
                    status: AppCheckInStatus.ready,
                    snapshot: AppCheckInSnapshot.fromJson(
                        snapshotJson(scope), scope)),
                onClaim: () async {
                  claims++;
                },
                onRefresh: () async {},
                gamesSection: FreeMiniGamesPreview(
                    reader: PreviewContentReader(),
                    onViewPlans: () async {
                      plans++;
                    }),
                weeklyRankSection:
                    FitnessArcadeRank(repository: repo, onTap: () {}),
                rewardGoalSection: RewardGoalCard(
                    repository: repo,
                    scope: scope,
                    store: Goals(),
                    onShop: () {},
                    onViewPlans: () async {
                      plans++;
                    }),
              ),
            )));
        await t.pumpAndSettle();
        Future<void> capture(String state) async {
          expect(t.takeException(), isNull);
          final render =
              t.renderObject<RenderRepaintBoundary>(find.byKey(boundary));
          await t.runAsync(() async {
            final screenshot = await render.toImage(pixelRatio: 1);
            final bytes =
                await screenshot.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
                '../../build/free-rewards-locked-20261112/${width.toInt()}-${(scale * 100).toInt()}-$state.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            screenshot.dispose();
          });
        }

        await capture('top');
        await t.ensureVisible(find.text('Play Mini-Games'));
        await t.pumpAndSettle();
        await capture('games');
        await t.ensureVisible(find.text('View membership plans').first);
        await t.pumpAndSettle();
        await capture('games-cta');
        await t.tap(find.text('View membership plans').first);
        await t.pumpAndSettle();
        expect(plans, 1);
        await t.ensureVisible(find.text('My Reward Goal'));
        await t.pumpAndSettle();
        await capture('goal');
        await t.ensureVisible(find.text('Browse rewards'));
        await t.pumpAndSettle();
        await capture('goal-cta');
        expect(find.text('Points History'), findsOneWidget);
        expect(find.text('Earned-points weekly rank'), findsOneWidget);
        expect(repo.redemptions, 0);
        expect(claims, 0);
      });
    }
  }
}
