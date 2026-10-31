import 'dart:io';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_admin_web/features/analytics/presentation/admin/admin_report_presentation.dart';
import 'package:gainpath_admin_web/features/analytics/presentation/admin/reports_screen.dart';
import 'admin_original_reporting_layout_test.dart' as fixture;

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final font = File('C:/Windows/Fonts/arial.ttf');
    if (await font.exists()) {
      final loader = FontLoader('ReviewArial')
        ..addFont(Future.value(ByteData.sublistView(await font.readAsBytes())));
      await loader.load();
    }
  });
  testWidgets('report methodology is collapsed and accessible at enlarged text',
      (tester) async {
    tester.view.physicalSize = const Size(700, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
                body: const SingleChildScrollView(
                    child: AdminReportDetails(
                        child: Text(
                            'Selected dates and immutable receipt coverage')))))));
    expect(
        find
            .text('Selected dates and immutable receipt coverage')
            .hitTestable(),
        findsNothing);
    await tester.tap(find.text('Definitions & coverage'));
    await tester.pumpAndSettle();
    expect(
        find
            .text('Selected dates and immutable receipt coverage')
            .hitTestable(),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'original report overview renders with refined navigation and expandable coverage',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final boundary = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
        key: boundary,
        child: ColoredBox(
            color: const Color(0xFFF7F6FB),
            child: fixture.originalLayoutApp(
                Theme(
                    data: ThemeData(fontFamily: 'ReviewArial'),
                    child: const ReportsScreen(live: true)),
                fixture.OriginalLayoutGateway()))));
    await tester.pumpAndSettle();
    expect(find.text('Reports & analytics'), findsOneWidget);
    expect(find.text('Reporting period & coverage'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final image = await (boundary.currentContext!.findRenderObject()
              as RenderRepaintBoundary)
          .toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('../../build/module12-batch-d/reports-fixture.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
