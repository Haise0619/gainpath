import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_mobile/app/member_typography_theme.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/reward_shop_screen.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_mobile/features/membership/presentation/member/billing_history_screen.dart';
import 'package:gainpath_mobile/features/membership/presentation/member/browse_plans_screen.dart';
import 'package:gainpath_mobile/features/membership/presentation/member/purchase_plan_screen.dart';
import 'package:gainpath_mobile/features/membership/presentation/member/refund_request_screen.dart';
import 'package:gainpath_mobile/features/membership/presentation/shared/membership_dashboard_screen.dart';
import '../../../test_support/fyp_render_support.dart';
import 'membership_commercial_ui_test.dart';
import 'membership_screens_test.dart' as fixture;
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;
import 'verified_rewards_screens_test.dart' show RewardsFake;

class _RenderCommerce extends CommercialMembershipFake {
  Map<String, dynamic>? receipt;
  @override
  Future<Map<String, dynamic>> payment(String id) async => receipt!;
}

void main() {
  setUpAll(loadDemoRenderFonts);
  final scenarios = [
    'free',
    'basic',
    'premium',
    'expired',
    'unknown',
    'plans',
    'basic-plan',
    'premium-plan',
    'checkout',
    'promo',
    'price-changed',
    'pending',
    'activated',
    'review',
    'billing',
    'refund',
    'free-rewards',
    'premium-rewards'
  ];
  for (final size in [
    const Size(320, 760),
    const Size(360, 800),
    const Size(390, 844),
    const Size(844, 390)
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('membership ${size.width} x ${size.height} at $scale',
          (tester) async {
        final restoreFonts = await installFypOfflineFonts();
        addTearDown(restoreFonts);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final theme = buildMemberTypographyTheme();
        for (final name in scenarios) {
          final repo = _RenderCommerce();
          if (['basic', 'premium'].contains(name)) {
            repo.overview['entitlement'] =
                fixture.entitlement(tier: name, paidStatus: 'active');
          } else if (name == 'expired') {
            repo.overview['entitlement'] =
                fixture.entitlement(paidStatus: 'expired');
          } else if (name == 'unknown') {
            repo.overview['entitlement'] = fixture.entitlement(unknown: true);
          }
          final paid = ['activated', 'billing', 'refund'].contains(name);
          final row = <String, dynamic>{
            'transactionId': 'fixture-membership-payment',
            'kind': 'MembershipPurchase',
            'planName': 'Basic',
            'amountMinor': 8900,
            'paymentStatus': paid ? 'cleared' : 'pending',
            'fulfilmentStatus': name == 'review'
                ? 'reconciliation_required'
                : paid
                    ? 'confirmed'
                    : 'awaiting_payment',
            'createdAtMillis': 1799999000000,
            'clearedAtMillis': paid ? 1799999900000 : null,
            if (paid) 'expiresAtMillis': 1802591900000,
            if (name == 'pending')
              'checkoutUrl': 'https://www.billplz-sandbox.com/bills/fixture'
          };
          repo.receipt = row;
          repo.overview['transactions'] = [row];
          final rewardTier = name == 'premium-rewards' ? 'premium' : 'free';
          final rewards = RewardsFake()
            ..value = VerifiedRewardsSnapshot(
                available: true,
                balance: 150,
                effectiveTier: rewardTier,
                canRedeem: rewardTier == 'premium',
                items: const [
                  VerifiedRewardItem(
                      itemId: 'regular',
                      title: 'Training bottle',
                      pointCost: 100,
                      stock: 1,
                      premiumOnly: false),
                  VerifiedRewardItem(
                      itemId: 'exclusive',
                      title: 'Exclusive fixture reward',
                      pointCost: 120,
                      stock: 1,
                      premiumOnly: true),
                ],
                redemptions: const []);
          final page = switch (name) {
            'plans' || 'basic-plan' || 'premium-plan' =>
              BrowsePlansScreen(repository: repo),
            'checkout' || 'promo' || 'price-changed' => PurchasePlanScreen(
                repository: repo,
                plan: MembershipPlan('basic', 'Basic', 89, '30 days', [])),
            'pending' ||
            'activated' ||
            'review' =>
              MembershipPaymentScreen(repository: repo, initial: row),
            'billing' => BillingHistoryScreen(repository: repo),
            'refund' => RefundRequestScreen(
                repository: repo,
                preselectedTransactionId: row['transactionId'] as String),
            'free-rewards' ||
            'premium-rewards' =>
              RewardShopScreen(connected: true, repository: rewards),
            _ => MembershipDashboardScreen(repository: repo),
          };
          final key = GlobalKey();
          await tester.pumpWidget(RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme,
                home: page,
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(scale),
                        disableAnimations: true),
                    child: child!),
              )));
          await tester.pumpAndSettle();
          if (name == 'basic-plan' || name == 'premium-plan') {
            final tier = name == 'basic-plan' ? 'Basic' : 'Premium';
            await tester.scrollUntilVisible(find.text('Choose $tier'), 120,
                scrollable: find.byType(Scrollable).first);
            await tester.pumpAndSettle();
          }
          Future<void> tap(String label) async {
            final finder = find.text(label);
            await tester.scrollUntilVisible(finder, 120,
                scrollable: find.byType(Scrollable).first);
            await tester.pumpAndSettle();
            await tester.tap(finder);
            await tester.pumpAndSettle();
          }

          if (name == 'promo') {
            await tester.scrollUntilVisible(find.byType(TextField), 100,
                scrollable: find.byType(Scrollable).first);
            await tester.enterText(find.byType(TextField), 'FIXTURE');
            await tap('Verify price / apply code');
          }
          if (name == 'price-changed') {
            repo.error = 'membership-quote-changed';
            await tap('Continue to Payment');
          }
          expect(tester.takeException(), isNull, reason: name);
          final boundary =
              tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
                '../../build/membership-commercial-20261112/renders/${size.width.toInt()}x${size.height.toInt()}-$scale-$name.png');
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
