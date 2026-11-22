import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/identity/presentation/admin/coach_provision_page.dart';

void main() {
  testWidgets('opens an unpublished multi-branch Coach through all three steps',
      (tester) async {
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const render = bool.fromEnvironment('GAINPATH_RENDER_COACH_PROVISION');
    if (render) {
      await tester.runAsync(() async {
        final font = await File('../mobile/assets/fonts/Barlow-Regular.ttf')
            .readAsBytes();
        await (FontLoader('CoachProvisionFixture')
              ..addFont(Future.value(ByteData.sublistView(font))))
            .load();
      });
    }
    final key = GlobalKey();
    Map<String, Object?>? payload;
    String? createdId;
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: render ? 'CoachProvisionFixture' : null),
        home: RepaintBoundary(
            key: key,
            child: Scaffold(
                body: Center(
                    child: CoachProvisionPage(
              branches: const {'main': 'Main Branch', 'second': 'GainPath 2'},
              onCancel: () {},
              onCreated: (id) => createdId = id,
              create: (input) async {
                payload = input;
                return 'test-coach';
              },
            ))))));
    Future<void> press(String text) async {
      final button = find.widgetWithText(FilledButton, text);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    await tester.enterText(find.byType(TextField).at(0), 'Fixture Coach');
    await tester.enterText(find.byType(TextField).at(1), 'coach@example.test');
    await press('Continue');
    await tester.enterText(find.byType(TextField).at(0), 'Strength');
    await tester.enterText(find.byType(TextField).at(1), '5');
    await tester.enterText(find.byType(TextField).at(2), '120.50');
    await press('Continue');
    await press('Create Coach');
    expect(find.text('Choose 1–8 enabled branches.'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    await press('Continue');
    await tester.tap(find.text('Main Branch'));
    await tester.tap(find.text('GainPath 2'));
    await tester.pumpAndSettle();
    if (const bool.fromEnvironment('GAINPATH_RENDER_COACH_PROVISION')) {
      await tester.runAsync(() async {
        final image = await (key.currentContext!.findRenderObject()!
                as RenderRepaintBoundary)
            .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
                '../../build/multi-branch-release/coach-provision-fixture.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await press('Create Coach');
    expect(createdId, 'test-coach');
    expect(payload, containsPair('branchIds', ['main', 'second']));
    expect(payload, containsPair('consultationFeeMinor', 12050));
    expect(payload!.containsKey('role'), isFalse);
    expect(payload!.containsKey('password'), isFalse);
  });
}
