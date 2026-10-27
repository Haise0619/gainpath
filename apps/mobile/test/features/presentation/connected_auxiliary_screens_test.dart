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
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/chatbot.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_mobile/features/analytics/presentation/member/goal_comparison_report.dart';
import 'package:gainpath_mobile/features/analytics/presentation/member/goal_progress_screen.dart';
import '../../membership_screens_test.dart' show MembershipFake;
import '../../verified_rewards_screens_test.dart' show RewardsFake;
import '../../goal_comparison_report_test.dart' show Targets;
import 'package:gainpath_mobile/features/membership/presentation/shared/membership_dashboard_screen.dart';
import 'package:gainpath_mobile/features/chatbot/presentation/member/chatbot_screen.dart';
import 'package:gainpath_mobile/features/analytics/presentation/member/body_metrics_screen.dart';

class _UnavailableChat extends ChatRepository {
  @override
  bool get isLive => true;
  @override
  List<ChatMessage> get chatSeed => const [];
  @override
  List<String> get savedAdvice => const [];
  @override
  List<FaqPrompt> get faqPrompts => const [];
  @override
  String buildProgressAuditReply() => throw StateError('Unavailable');
  @override
  Future<ChatSessionInfo> initialize() async =>
      throw const ChatFailure('unavailable', 'AI coach unavailable.');
}

Widget _app(Widget screen, {bool scaled = false}) =>
    RepositoryProvider<ChatRepository>(
        create: (_) => _UnavailableChat(),
        child: MaterialApp(
            builder: scaled
                ? (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(1.3)),
                    child: child!)
                : null,
            home: screen));

Widget _goals() => GoalComparisonReport(
    repository: Targets(), progress: null, isCurrent: () => true);

void main() {
  testWidgets('connected catalogues and body metric widgets fit a phone',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final screen in <Widget>[
      const MiniGamesScreen(connected: true),
      BrowsePlansScreen(connected: true, repository: MembershipFake()),
      const BodyMetricsScreen(live: true, weightKg: 80, heightCm: 200),
      _goals(),
      const BillplzCheckoutScreen(connected: true, amount: 0, description: '-'),
    ]) {
      await tester.pumpWidget(_app(screen, scaled: true));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
          reason: screen.runtimeType.toString());
    }
  });
  for (final entry in <String, Widget>{
    'Leaderboard': const LeaderboardScreen(connected: true),
    'Badges': const BadgesScreen(connected: true),
    'Mini-games': const MiniGamesScreen(connected: true),
    'Reward shop':
        RewardShopScreen(connected: true, repository: RewardsFake()),
    'Membership plans':
        BrowsePlansScreen(connected: true, repository: MembershipFake()),
    'Billing history':
        BillingHistoryScreen(connected: true, repository: MembershipFake()),
    'Refund requests':
        RefundRequestScreen(connected: true, repository: MembershipFake()),
    'Renew membership':
        RenewScreen(connected: true, repository: MembershipFake()),
    'Saved advice': const SavedAdviceScreen(connected: true),
  }.entries) {
    testWidgets('connected ${entry.key} renders without mock providers',
        (tester) async {
      await tester.pumpWidget(_app(entry.value));
      await tester.pumpAndSettle();
      expect(find.text(entry.key), findsWidgets);
      expect(find.textContaining('RM '), findsNothing);
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
  testWidgets(
      'connected membership uses verified Free entitlement without seeded billing',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: MembershipDashboardScreen(
            connected: true, repository: MembershipFake())));
    await tester.pumpAndSettle();
    expect(find.text('Free'), findsOneWidget);
    expect(find.text('Upgrade'), findsOneWidget);
    expect(find.text('No membership payments yet.'), findsOneWidget);
    expect(find.text('View all billing history'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'connected chat keeps a disabled composer when the AI service is unavailable',
      (tester) async {
    await tester.pumpWidget(_app(const ChatbotScreen(connected: true)));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('AI coach unavailable.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('connected body metrics derives BMI from real profile only',
      (tester) async {
    await tester.pumpWidget(
        _app(const BodyMetricsScreen(live: true, weightKg: 80, heightCm: 200)));
    await tester.pumpAndSettle();
    expect(find.text('80.0 kg'), findsOneWidget);
    expect(find.text('20.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('connected goal report shows the actual empty target state',
      (tester) async {
    await tester.pumpWidget(_app(_goals()));
    await tester.pumpAndSettle();
    expect(find.text('3 of 4'), findsNothing);
    expect(find.text('84 of 85'), findsNothing);
    expect(find.text('No active numeric targets yet. Set targets in Profile.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('connected goal route requires the current authenticated session',
      (tester) async {
    final repository = InMemoryAuthRepository();
    final auth = AuthBloc(repository: repository);
    addTearDown(() async {
      await auth.close();
      await repository.dispose();
    });
    await tester.pumpWidget(BlocProvider.value(
        value: auth, child: _app(const GoalProgressScreen(live: true))));
    await tester.pumpAndSettle();
    expect(
        find.text('Sign in to view this account’s targets.'), findsOneWidget);
    expect(find.text('3 of 4'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
