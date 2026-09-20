import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_admin_web/app/di/app_repositories.dart';
import 'package:gainpath_admin_web/app/shells/admin_shell.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('admin shell renders full navigation', (tester) async {
    tester.view.physicalSize = const Size(2880, 1800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const AppRepositories(child: MaterialApp(home: AdminShell())));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(AdminShell), findsOneWidget);
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Members'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
