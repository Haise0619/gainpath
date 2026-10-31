import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/gamification/domain/app_check_in.dart';
import 'package:gainpath_mobile/features/gamification/application/app_check_in_cubit.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/app_check_in_dashboard.dart';
import 'app_check_in_test.dart' show snapshotJson;

void main() {
  testWidgets('pull refresh remains available without a toolbar refresh button',
      (tester) async {
    var calls = 0;
    final gate = Completer<void>();
    await tester.pumpWidget(MaterialApp(
        home: AppCheckInDashboard(
            state: const AppCheckInState(status: AppCheckInStatus.unavailable),
            onClaim: () async {},
            onRefresh: () {
              calls++;
              return gate.future;
            })));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Refresh rewards'), findsNothing);
    final refresh =
        tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
    final first = refresh.onRefresh();
    final second = refresh.onRefresh();
    expect(calls, 1);
    gate.complete();
    await Future.wait([first, second]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
  AppCheckInState ready({bool claimed = true, bool claiming = false}) =>
      AppCheckInState(
          status: AppCheckInStatus.ready,
          claiming: claiming,
          snapshot: AppCheckInSnapshot.fromJson(
              snapshotJson(scope, claimed: claimed), scope));
  Future<void> show(WidgetTester tester, AppCheckInState state,
      {double width = 375,
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
    if (state.claiming) {
      await tester.pump();
    } else {
      await tester.pumpAndSettle();
    }
  }

  if (const bool.fromEnvironment('GAINPATH_EXPORT_ARCADE_UI')) {
    testWidgets('export compact arcade visual fixture', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final entry in {
        'ArcadePreview': 'C:/Windows/Fonts/segoeui.ttf',
        'MaterialIcons':
            'C:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'
      }.entries) {
        final loader = FontLoader(entry.key)
          ..addFont(Future.value(
              ByteData.sublistView(File(entry.value).readAsBytesSync())));
        await loader.load();
      }
      final boundary = GlobalKey();
      await tester.pumpWidget(MaterialApp(
          theme: ThemeData(
              useMaterial3: true,
              fontFamily: 'ArcadePreview',
              colorScheme:
                  ColorScheme.fromSeed(seedColor: const Color(0xFF6D28D9))),
          home: RepaintBoundary(
              key: boundary,
              child: AppCheckInDashboard(
                  state: ready(),
                  onClaim: () async {},
                  onRefresh: () async {}))));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final image = await (boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary)
            .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('../../build/fitness-arcade-p1a-20261029/hub-preview.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'arcade puts confirmed wallet check-in and both games before secondary records',
      (tester) async {
    await show(tester, ready());
    expect(find.text('50'), findsOneWidget);
    expect(find.text('Move & Catch'), findsOneWidget);
    expect(find.text('Reach & Tap'), findsOneWidget);
    final play = tester.getTopLeft(find.text('Play Mini-Games')).dy;
    expect(play, lessThan(500),
        reason: 'Games must be near the top on a normal phone');
    expect(find.text('RECENT CHECK-INS'), findsNothing);
    expect(find.text('Check-in badges'), findsNothing);
    expect(find.text('1 camera game'), findsNothing);
    expect(find.text('1840'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('badges open separately using only real check-in progress',
      (tester) async {
    await show(tester, ready());
    await tester.ensureVisible(find.text('Badges'));
    await tester.tap(find.text('Badges'));
    await tester.pumpAndSettle();
    expect(find.text('Check-in badges'), findsOneWidget);
    expect(find.text('Three-day streak'), findsOneWidget);
    expect(find.text('1/3 days'), findsOneWidget);
    expect(find.textContaining('Workout master'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('320px double text keeps secondary navigation reachable',
      (tester) async {
    await show(tester, ready(), width: 320, scale: 2);
    for (final label in [
      'Redeem points',
      'My Rewards',
      'Badges',
      'Points History',
      'Leaderboards'
    ]) {
      await tester.ensureVisible(find.text(label));
    }
    expect(find.textContaining('Squat Rush'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('unavailable wallet never invents a balance claim or ranking',
      (tester) async {
    await show(
        tester, const AppCheckInState(status: AppCheckInStatus.unavailable));
    expect(find.text('—'), findsWidgets);
    expect(find.text('Claim 50 points'), findsNothing);
    expect(find.text('1840'), findsNothing);
    expect(find.text('Rank #4'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'existing daily claim callback remains direct and pending blocks another tap',
      (tester) async {
    var claims = 0;
    await show(tester, ready(claimed: false), claim: () async {
      claims++;
    });
    await tester.tap(find.text('Claim 50 points'));
    expect(claims, 1);
    await show(tester, ready(claimed: false, claiming: true), claim: () async {
      claims++;
    });
    expect(
        tester
            .widget<FilledButton>(find
                .ancestor(
                    of: find.text('Claiming…'),
                    matching: find.byWidgetPredicate((w) => w is FilledButton))
                .first)
            .onPressed,
        isNull);
    expect(claims, 1);
  });
}
