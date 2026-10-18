import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_mobile/features/identity/presentation/coach/coach_settings_screen.dart';
import 'package:gainpath_mobile/features/identity/application/coach_account_gateway.dart';

CoachAccountSettings settings(String phone, [int revision = 0]) =>
    CoachAccountSettings(
        revision: revision,
        contactPhone: phone,
        newBookings: true,
        cancellations: true,
        reminders: false);

class PhoneSettingsFake extends Fake implements CoachAccountGateway {
  PhoneSettingsFake([String phone = '']) : stored = settings(phone);
  @override
  SessionScope get scope =>
      SessionScope(userId: 'coach', organizationId: 'gym');
  @override
  bool Function() get isCurrent => () => true;
  @override
  bool get passwordManagementAvailable => false;
  CoachAccountSettings stored;
  int saves = 0, loads = 0;
  String? savedPhone, failure;
  Completer<CoachAccountSettings>? readback;
  @override
  String get email => 'coach@example.test';
  @override
  void check() {}
  @override
  Future<CoachAccountSettings> loadSettings() async {
    loads++;
    if (loads > 1 && readback != null) return readback!.future;
    return stored;
  }

  @override
  Future<CoachAccountSettings> saveSettings(
      CoachAccountSettings baseline,
      String phone,
      bool bookings,
      bool cancellations,
      bool reminders,
      String requestId) async {
    saves++;
    savedPhone = phone;
    if (failure != null) throw CoachRepositoryException(failure!);
    stored = CoachAccountSettings(
        revision: baseline.revision + 1,
        contactPhone: phone,
        newBookings: bookings,
        cancellations: cancellations,
        reminders: reminders);
    return stored;
  }
}

Future<void> mount(WidgetTester tester, PhoneSettingsFake repository) async {
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
      MaterialApp(home: CoachSettingsScreen(repository: repository)));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'Malaysia default normalizes local phone and waits for readback without duplicate submissions',
      (tester) async {
    final repository = PhoneSettingsFake()
      ..readback = Completer<CoachAccountSettings>();
    await mount(tester, repository);
    expect(find.textContaining('Malaysia'), findsOneWidget);
    expect(find.textContaining('+60'), findsWidgets);
    await tester.enterText(
        find.byKey(const Key('coach-phone-national')), '012-3456789');
    await tester.pump();
    await tester.pump();
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pump();
    await tester.pump();
    expect(repository.savedPhone, '+60123456789');
    expect(repository.loads, 2);
    expect(repository.saves, 1);
    expect(find.text('Settings saved.'), findsNothing);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Save changes'))
            .onPressed,
        isNull);
    repository.readback!.complete(repository.stored);
    await tester.pumpAndSettle();
    expect(find.text('Settings saved.'), findsWidgets);
  });
  testWidgets(
      'invalid local number is inline and duplicate claim is meaningful without losing input',
      (tester) async {
    final repository = PhoneSettingsFake();
    await mount(tester, repository);
    await tester.enterText(
        find.byKey(const Key('coach-phone-national')), '123');
    await tester.pump();
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(repository.saves, 0);
    expect(find.textContaining('valid phone number'), findsWidgets);
    repository.failure = 'already-exists';
    await tester.enterText(
        find.byKey(const Key('coach-phone-national')), '012-3456789');
    await tester.pump();
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.textContaining('already linked'), findsWidgets);
    expect(
        tester
            .widget<TextField>(find.byKey(const Key('coach-phone-national')))
            .controller!
            .text,
        '012-3456789');
    expect(find.text('Settings saved.'), findsNothing);
  });
  testWidgets(
      'stored Singapore E164 restores selection and blank input clears it',
      (tester) async {
    final repository = PhoneSettingsFake('+6581234567');
    await mount(tester, repository);
    expect(find.textContaining('Singapore'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('coach-phone-national')), '');
    await tester.pump();
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(repository.savedPhone, '');
    expect(find.text('Settings saved.'), findsWidgets);
  });
  testWidgets('readback mismatch never reports a successful save',
      (tester) async {
    final repository = PhoneSettingsFake()
      ..readback = Completer<CoachAccountSettings>();
    await mount(tester, repository);
    await tester.enterText(
        find.byKey(const Key('coach-phone-national')), '0123456789');
    await tester.pump();
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pump();
    await tester.pump();
    repository.readback!.complete(settings('+6581234567', 1));
    await tester.pumpAndSettle();
    expect(find.text('Settings saved.'), findsNothing);
    expect(find.textContaining('changed elsewhere'), findsWidgets);
    expect(
        tester
            .widget<TextField>(find.byKey(const Key('coach-phone-national')))
            .controller!
            .text,
        '0123456789');
  });
  testWidgets('unavailable save displays a visible actionable error',
      (tester) async {
    final repository = PhoneSettingsFake()..failure = 'unavailable';
    await mount(tester, repository);
    await tester.enterText(
        find.byKey(const Key('coach-phone-national')), '0123456789');
    await tester.pump();
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Check your connection'), findsWidgets);
    expect(find.text('Settings saved.'), findsNothing);
  });
  testWidgets('searchable country selector supports a UK local number',
      (tester) async {
    final repository = PhoneSettingsFake();
    await mount(tester, repository);
    expect(find.textContaining('🇲🇾'), findsOneWidget);
    await tester.tap(find.byKey(const Key('coach-phone-country')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byWidgetPredicate((widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Search country or calling code'),
        'United Kingdom');
    await tester.pump();
    await tester.tap(find.text('United Kingdom (GB)'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('coach-phone-national')), '020 7946 0018');
    await tester.pump();
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(repository.savedPhone, '+442079460018');
    expect(find.textContaining('🇬🇧'), findsOneWidget);
  });
}
