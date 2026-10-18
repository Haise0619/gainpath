import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_data/identity.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/identity/application/coach_account_gateway.dart';
import 'package:gainpath_mobile/features/identity/presentation/coach/coach_settings_screen.dart';
import 'package:gainpath_mobile/infrastructure/local/mock_coach_module8_repository.dart';
import 'coach_phone_settings_test.dart' show PhoneSettingsFake;

final settingsCaptureKey = GlobalKey();

class EquivalentSettingsFake extends PhoneSettingsFake {
  EquivalentSettingsFake(super.phone, this.address);
  final String address;
  @override
  String get email => address;
}

Future<void> captureSettings(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary = settingsCaptureKey.currentContext!.findRenderObject()
        as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('../../build/module-8-architecture');
      await dir.create(recursive: true);
      await File('${dir.path}/$name.png')
          .writeAsBytes(data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

Future<void> mountSettings(
    WidgetTester tester, CoachAccountGateway repository) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(RepaintBoundary(
      key: settingsCaptureKey,
      child: MaterialApp(home: CoachSettingsScreen(repository: repository))));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final useMock in [true, false]) {
    testWidgets(
        '${useMock ? 'Mock' : 'authoritative fake'} uses the canonical grouped Settings layout at 360px',
        (tester) async {
      final seed = InMemoryCoachRepository();
      final CoachAccountGateway repository = useMock
          ? MockCoachModule8Repository(
              legacy: seed,
              scope: SessionScope(userId: 'coach', organizationId: 'gym'),
              isCurrent: () => true)
          : EquivalentSettingsFake(seed.coachPhone, seed.coachEmail);
      await mountSettings(tester, repository);
      await captureSettings(
          tester, useMock ? 'mock-settings' : 'firebase-contract-settings');
      final contact = find.byKey(const Key('coach-settings-contact'));
      expect(
          find.descendant(
              of: contact,
              matching: find.byKey(const Key('coach-phone-country'))),
          findsOneWidget);
      expect(
          find.descendant(
              of: contact,
              matching: find.byKey(const Key('coach-phone-national'))),
          findsOneWidget);
      expect(
          tester
              .widget<TextField>(find.descendant(
                  of: find.descendant(
                      of: contact, matching: find.byType(TextFormField)),
                  matching: find.byType(TextField)))
              .readOnly,
          isTrue);
      expect(find.textContaining('An SMS'), findsNothing);
      expect(find.text('Deactivate account'), findsNothing);
      for (final key in [
        'coach-settings-notifications',
        'coach-settings-security',
        'coach-settings-account'
      ]) {
        await tester.scrollUntilVisible(find.byKey(Key(key)), 200,
            scrollable: find.byType(Scrollable).first);
        expect(find.byKey(Key(key)), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.scrollUntilVisible(find.text('Save changes'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Save changes'))
              .onPressed,
          isNull);
      await tester.scrollUntilVisible(find.text('Change password'), -200,
          scrollable: find.byType(Scrollable).first);
      expect(
          tester
              .widget<ListTile>(
                  find.widgetWithText(ListTile, 'Change password'))
              .onTap,
          isNull);
      await tester.scrollUntilVisible(find.text('Account access'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'Discard asks for confirmation and restores authoritative settings',
      (tester) async {
    final repository = PhoneSettingsFake('+60123456789');
    await mountSettings(tester, repository);
    await tester.enterText(
        find.byKey(const Key('coach-phone-national')), '0129876543');
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Discard and reload'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Discard and reload'));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(repository.loads, 1);
    await tester.scrollUntilVisible(
        find.byKey(const Key('coach-phone-national')), -200,
        scrollable: find.byType(Scrollable).first);
    expect(
        tester
            .widget<TextField>(find.byKey(const Key('coach-phone-national')))
            .controller!
            .text,
        '0129876543');
    await tester.scrollUntilVisible(find.text('Discard and reload'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Discard and reload'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(repository.loads, 2);
    expect(repository.saves, 0);
    await tester.scrollUntilVisible(
        find.byKey(const Key('coach-phone-national')), -200,
        scrollable: find.byType(Scrollable).first);
    expect(
        tester
            .widget<TextField>(find.byKey(const Key('coach-phone-national')))
            .controller!
            .text,
        '12-345 6789');
    expect(tester.takeException(), isNull);
  });
}
