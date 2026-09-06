import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:gainpath/app/app.dart';
import 'package:gainpath/app/shells/admin_shell.dart';
import 'package:gainpath/app/shells/coach_shell.dart';
import 'package:gainpath/app/shells/member_shell.dart';

/// The web build opens straight into the admin console, so the member and
/// coach shells are exercised here: every bottom-navigation tab must build
/// against the repositories and Blocs without throwing.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pumpShell(WidgetTester tester, Widget shell,
      {Size physicalSize = const Size(1200, 2400)}) async {
    tester.view.physicalSize = physicalSize;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AppScope(child: MaterialApp(home: shell)));
    await tester.pump();
  }

  Future<void> tapEveryDestination(WidgetTester tester) async {
    final destinations = find.byType(NavigationDestination);
    for (var i = 0; i < destinations.evaluate().length; i++) {
      await tester.tap(destinations.at(i));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }
  }

  testWidgets('member shell renders every tab', (tester) async {
    await pumpShell(tester, const MemberShell());
    expect(find.byType(NavigationBar), findsOneWidget);
    await tapEveryDestination(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('coach shell renders every tab', (tester) async {
    await pumpShell(tester, const CoachShell());
    await tapEveryDestination(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin shell renders', (tester) async {
    // The admin console is a desktop layout; give it a desktop-sized window.
    await pumpShell(tester, const AdminShell(), physicalSize: const Size(2880, 1800));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(AdminShell), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
