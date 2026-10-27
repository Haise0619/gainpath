import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/gamification/domain/app_check_in.dart';
import 'package:gainpath_mobile/features/gamification/application/app_check_in_cubit.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/app_check_in_dashboard.dart';
import 'app_check_in_test.dart' show snapshotJson;

void main() {
  final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
  AppCheckInState ready() => AppCheckInState(
      status: AppCheckInStatus.ready,
      snapshot: AppCheckInSnapshot.fromJson(
          snapshotJson(scope, claimed: true), scope));
  Future<void> show(WidgetTester tester, AppCheckInState state,
      {double width = 390,
      double scale = 1,
      Future<void> Function()? claim}) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: AppCheckInDashboard(
            state: state,
            onClaim: claim ?? () async {},
            onRefresh: () async {})));
  }

  testWidgets(
      'reference layout uses live points, next real badge and a two-column Explore grid',
      (tester) async {
    await show(tester, ready());
    expect(find.text('50'), findsOneWidget);
    expect(find.text('1 day streak'), findsOneWidget);
    expect(find.text('1 badge'), findsOneWidget);
    expect(find.text('Progress to 3-day badge'), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
    expect(find.text('1840'), findsNothing);
    expect(find.textContaining('14-day'), findsNothing);
    await tester.ensureVisible(find.text('Mini-games'));
    expect(tester.getTopLeft(find.text('Mini-games')).dy,
        closeTo(tester.getTopLeft(find.text('Badges')).dy, 1));
    expect(find.text('1 camera game'), findsOneWidget);
    expect(find.text('1/3 unlocked'), findsOneWidget);
    await tester.ensureVisible(find.text('My Rewards'));
    expect(find.text('My Rewards'), findsOneWidget);
    expect(find.byTooltip('Points History'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'small screen with large text keeps all actions and confirmed check-ins readable',
      (tester) async {
    await show(tester, ready(), width: 320, scale: 2);
    await tester.ensureVisible(find.text('Redeem points'));
    await tester.ensureVisible(find.text('My Rewards'));
    await tester.ensureVisible(find.text('RECENT CHECK-INS'));
    expect(find.text('Daily check-in claimed'), findsOneWidget);
    expect(find.text('+50 pts'), findsOneWidget);
    expect(find.textContaining('Squat Rush'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('unavailable rewards show no invented balance or claim action',
      (tester) async {
    await show(
        tester, const AppCheckInState(status: AppCheckInStatus.unavailable));
    expect(find.text('—'), findsWidgets);
    expect(find.text('Claim 50 points'), findsNothing);
    expect(find.text('1840'), findsNothing);
    expect(find.text('Rank #4'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
