import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_mobile/app/member_typography_theme.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/reward_shop_screen.dart';

import '../../../test_support/fyp_render_support.dart';
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;
import 'verified_rewards_screens_test.dart' show RewardsFake;

void main() {
  setUpAll(loadDemoRenderFonts);
  for (final size in [
    const Size(320, 760),
    const Size(360, 800),
    const Size(390, 844),
    const Size(844, 390)
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('reward eligibility ${size.width} x ${size.height} at $scale',
          (tester) async {
        final restore = await installFypOfflineFonts();
        addTearDown(restore);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final theme = buildMemberTypographyTheme();
        for (final (label, tier, points, stock, premiumOnly) in [
          ('free', 'free', 150, 2, false),
          ('basic-regular', 'basic', 150, 2, false),
          ('basic-locked', 'basic', 150, 2, true),
          ('premium', 'premium', 150, 2, true),
          ('insufficient', 'premium', 60, 2, true),
          ('out-of-stock', 'premium', 150, 0, true),
          ('verify', null, 150, 2, true),
          ('retry', 'premium', 150, 2, true),
        ]) {
          final repo = RewardsFake()
            ..fail = label == 'retry'
            ..value = VerifiedRewardsSnapshot(
              available: true,
              balance: points,
              effectiveTier: tier,
              canRedeem: tier == 'basic' || tier == 'premium',
              redemptions: const [],
              items: [
                VerifiedRewardItem(
                    itemId: 'fixture',
                    title: 'Training bottle',
                    pointCost: 100,
                    stock: stock,
                    premiumOnly: premiumOnly)
              ],
            );
          final key = GlobalKey();
          await tester.pumpWidget(RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme,
                home: RewardShopScreen(connected: true, repository: repo),
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(scale),
                        disableAnimations: true),
                    child: child!),
              )));
          await tester.pumpAndSettle();
          if (label != 'free' && label != 'verify') {
            await tester.scrollUntilVisible(find.text('Redeem'), 130,
                scrollable: find.byType(Scrollable).first);
            await tester.pumpAndSettle();
          }
          if (label == 'retry') {
            await tester.tap(find.text('Redeem'));
            await tester.pumpAndSettle();
            await tester.scrollUntilVisible(
                find.text('Confirm redemption'), 140,
                scrollable: find.byType(Scrollable).last);
            await tester.pumpAndSettle();
            await tester.tap(find.text('Confirm redemption'));
            await tester.pumpAndSettle();
            await tester.scrollUntilVisible(
                find.textContaining('Redemption could not be confirmed'), -140,
                scrollable: find.byType(Scrollable).first);
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull, reason: label);
          final boundary =
              tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
                '../../build/membership-renewal-premium-rewards-20261112/member-rewards/${size.width.toInt()}x${size.height.toInt()}-$scale-$label.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        }
      });
    }
  }
}
