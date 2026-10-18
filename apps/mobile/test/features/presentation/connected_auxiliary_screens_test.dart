import 'package:gainpath_mobile/features/membership/presentation/shared/billplz_checkout_screen.dart';
import 'package:gainpath_mobile/features/chatbot/presentation/member/saved_advice_screen.dart';
import 'package:gainpath_mobile/features/membership/presentation/member/renew_screen.dart';
import 'package:gainpath_mobile/features/membership/presentation/member/refund_request_screen.dart';
import 'package:gainpath_mobile/features/membership/presentation/member/billing_history_screen.dart';
import 'package:gainpath_mobile/features/membership/presentation/member/browse_plans_screen.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/reward_shop_screen.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/mini_games_screen.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/badges_screen.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/leaderboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/membership/presentation/shared/membership_dashboard_screen.dart';
import 'package:gainpath_mobile/features/chatbot/presentation/member/chatbot_screen.dart';
import 'package:gainpath_mobile/features/analytics/presentation/member/body_metrics_screen.dart';
import 'package:gainpath_mobile/features/analytics/presentation/member/goal_progress_screen.dart';

void main() {
  testWidgets('connected catalogues and body metric widgets fit a phone',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final screen in const <Widget>[
      MiniGamesScreen(connected: true),
      BrowsePlansScreen(connected: true),
      BodyMetricsScreen(live: true, weightKg: 80, heightCm: 200),
      GoalProgressScreen(live: true),
      BillplzCheckoutScreen(connected: true, amount: 0, description: '-'),
    ]) {
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!),
          home: screen));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
          reason: screen.runtimeType.toString());
    }
  });
  for (final entry in <String, Widget>{
    'Leaderboard': const LeaderboardScreen(connected: true),
    'Badges': const BadgesScreen(connected: true),
    'Mini-games': const MiniGamesScreen(connected: true),
    'Redeem points': const RewardShopScreen(connected: true),
    'Membership plans': const BrowsePlansScreen(connected: true),
    'Billing history': const BillingHistoryScreen(connected: true),
    'Request a refund': const RefundRequestScreen(connected: true),
    'Renew membership': const RenewScreen(connected: true),
    'Saved advice': const SavedAdviceScreen(connected: true),
  }.entries) {
    testWidgets('connected ${entry.key} renders without mock providers',
        (tester) async {
      await tester.pumpWidget(MaterialApp(home: entry.value));
      await tester.pump();
      expect(find.text(entry.key), findsWidgets);
      expect(find.text('-'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('connected checkout cannot submit payment', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: BillplzCheckoutScreen(
            connected: true, amount: 0, description: '-')));
    await tester.tap(find.text('Maybank2u'));
    await tester.pump();
    final pay = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Payment unavailable'));
    expect(pay.onPressed, isNull);
    expect(find.text('billplz.com/bill/checkout'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('connected membership retains actions without seeded billing',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: MembershipDashboardScreen(
            connected: true, planName: 'Standard', status: 'active')));
    expect(find.text('Standard'), findsOneWidget);
    expect(find.text('Renew now'), findsOneWidget);
    expect(find.text('Change plan'), findsOneWidget);
    expect(find.text('View all billing history'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('connected chat keeps composer without an AI repository',
      (tester) async {
    await tester
        .pumpWidget(const MaterialApp(home: ChatbotScreen(connected: true)));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('AI coach unavailable. Conversation: -'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('connected body metrics derives BMI from real profile only',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: BodyMetricsScreen(live: true, weightKg: 80, heightCm: 200)));
    await tester.pumpAndSettle();
    expect(find.text('80.0 kg'), findsOneWidget);
    expect(find.text('20.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('connected goal report retains three gauges with missing values',
      (tester) async {
    await tester
        .pumpWidget(const MaterialApp(home: GoalProgressScreen(live: true)));
    expect(find.text('3 of 4'), findsNothing);
    expect(find.text('84 of 85'), findsNothing);
    expect(find.text('-'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
