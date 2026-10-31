import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show AuthSession, AppRole, SessionScope;
import 'package:gainpath_mobile/app/home/member_home_screen.dart';
import 'package:gainpath_mobile/features/gamification/application/app_check_in_cubit.dart';
import 'package:gainpath_mobile/features/gamification/domain/app_check_in.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const testSession = AuthSession(
    userId: 'm1',
    organizationId: 'gym1',
    email: 'zy@gainpath.test',
    role: AppRole.member,
    branchIds: ['main'],
  );

  Widget createWidgetUnderTest({
    VoidCallback? onOpenNotifications,
    AppCheckInState? appCheckIn,
    Future<void> Function()? onAppClaim,
  }) {
    return MaterialApp(
      theme: AppTheme.build(),
      home: MemberHomeScreen(
        liveSession: testSession,
        onOpenNotifications: onOpenNotifications,
        appCheckIn: appCheckIn,
        onAppClaim: onAppClaim,
      ),
    );
  }

  testWidgets('home content starts with rounded corners and breathing room',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    final cap = find.byKey(const ValueKey('home-content-top'));
    expect(cap, findsOneWidget);
    final decoration =
        tester.widget<DecoratedBox>(cap).decoration as BoxDecoration;
    expect(decoration.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(24)));
    expect(
        tester.getTopLeft(find.text('DAILY CHECK-IN')).dy -
            tester.getTopLeft(cap).dy,
        greaterThanOrEqualTo(24));
  });

  testWidgets('AI Coach button is circular, larger and shows the mascot',
      (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    final button = find.byType(FloatingActionButton);
    expect(tester.getSize(button), const Size(72, 72));
    final fab = tester.widget<FloatingActionButton>(button);
    expect(fab.shape, isA<CircleBorder>());
    expect(fab.tooltip, 'AI Coach');
    expect(find.descendant(of: button, matching: find.byType(Image)),
        findsOneWidget);
  });

  testWidgets('home section headings have consistent content spacing',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    final weeklyTitle = find.text('THIS WEEK');
    final recentTitle = find.text('RECENT ACTIVITY');
    final quickTitle = find.text('QUICK ACCESS');
    final weeklyCard = find
        .ancestor(of: find.text('Sessions'), matching: find.byType(Panel))
        .first;
    final recentCard = find
        .ancestor(
            of: find.text('Loading saved camera sessions…'),
            matching: find.byType(Panel))
        .first;
    final grid = find.byType(GridView);
    double gap(Finder title, Finder content) =>
        tester.getTopLeft(content).dy - tester.getBottomLeft(title).dy;
    expect(gap(weeklyTitle, weeklyCard), 10);
    expect(gap(recentTitle, recentCard), 10);
    expect(gap(quickTitle, grid), 10);
    final title = tester.widget<Text>(quickTitle);
    expect(title.style!.fontSize, greaterThanOrEqualTo(16));
    expect(title.style!.fontWeight, FontWeight.w800);
    expect(title.style!.fontFamily, 'BarlowCondensed');
  });

  testWidgets(
      'Member Home header contains exactly ONE notification bell icon that opens notifications',
      (tester) async {
    var notificationsOpened = false;

    await tester.pumpWidget(createWidgetUnderTest(
      onOpenNotifications: () => notificationsOpened = true,
    ));
    await tester.pumpAndSettle();

    final bellFinder = find.byIcon(Icons.notifications_none_rounded);
    expect(bellFinder, findsOneWidget);
    expect(find.byIcon(Icons.notifications_active_outlined), findsNothing);

    await tester.tap(bellFinder);
    await tester.pumpAndSettle();
    expect(notificationsOpened, isTrue);
  });

  testWidgets(
      'Narrow screen (360x640) with 1.5x font scale renders Daily Check-in claim action cleanly without overlap',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var claimTriggered = false;
    final now = DateTime.now().millisecondsSinceEpoch;
    final checkInState = AppCheckInState(
      status: AppCheckInStatus.ready,
      snapshot: AppCheckInSnapshot(
        scope: SessionScope(userId: 'm1', organizationId: 'gym1'),
        policyVersion: '1.0',
        timezone: 'Asia/Kuala_Lumpur',
        balance: 300,
        currentStreak: 5,
        longestStreak: 10,
        claimedToday: false,
        pointsPerClaim: 10,
        today: '2026-10-31',
        totalClaims: 15,
        serverNowMillis: now,
        nextResetMillis: now + 86400000,
        days: const [
          AppCheckInDay('2026-10-26', true),
          AppCheckInDay('2026-10-27', true),
          AppCheckInDay('2026-10-28', true),
          AppCheckInDay('2026-10-29', true),
          AppCheckInDay('2026-10-30', true),
          AppCheckInDay('2026-10-31', false),
          AppCheckInDay('2026-11-01', false),
        ],
        recentClaims: const [],
        badges: const [],
      ),
    );

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 640),
          textScaler: TextScaler.linear(1.5),
        ),
        child: createWidgetUnderTest(
          appCheckIn: checkInState,
          onAppClaim: () async {
            claimTriggered = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);

    final claimTextFinder = find.text('Claim 10 points');
    await tester.ensureVisible(claimTextFinder);
    await tester.pumpAndSettle();

    expect(claimTextFinder, findsOneWidget);

    await tester.tap(claimTextFinder);
    await tester.pumpAndSettle();
    expect(claimTriggered, isTrue);
  });
}
