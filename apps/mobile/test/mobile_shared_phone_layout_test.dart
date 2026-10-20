import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_mobile/app/home/member_home_screen.dart';
import 'package:gainpath_mobile/features/analytics/presentation/coach/earnings_screen.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/gamification_dashboard_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('shared mobile hubs retain their layout on a narrow phone',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final entry in <String, Widget>{
      'member-home': const MemberHomeScreen(
          liveSession: AuthSession(email: 'member@example.test', role: AppRole.member)),
      'member-rewards': const GamificationDashboardScreen(live: true),
      'coach-earnings': const EarningsScreen(connected: true),
    }.entries) {
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
          theme: ThemeData(useMaterial3: true),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(1.3)), child: child!),
          home: RepaintBoundary(key: key, child: entry.value)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: entry.key);
      if (const bool.fromEnvironment('GAINPATH_CAPTURE_UI')) {
        await tester.runAsync(() async {
          final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final output = File('../../build/mobile-unified-ui/${entry.key}.png');
          await output.parent.create(recursive: true);
          await output.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      final scroll = find.byType(Scrollable).first;
      for (var i = 0; i < 4; i++) {
        await tester.drag(scroll, const Offset(0, -450));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '${entry.key} scroll $i');
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
