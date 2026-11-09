import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_mobile/features/identity/presentation/coach/coach_settings_screen.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'coach_phone_settings_test.dart' show PhoneSettingsFake;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
      'notification switches toggle preferences, reminders is unavailable, and triggers sticky save bar',
      (tester) async {
    final repo = PhoneSettingsFake('+60123456789');
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: CoachSettingsScreen(repository: repo),
      ),
    );
    await tester.pumpAndSettle();

    // Verify verified email is read-only
    final emailField = tester.widget<TextField>(
      find.descendant(
        of: find.byType(TextFormField),
        matching: find.byType(TextField),
      ),
    );
    expect(emailField.readOnly, isTrue);
    expect(find.byIcon(Icons.lock_outline_rounded), findsWidgets);

    // Verify initial clean state has NO save bar
    expect(find.byKey(const Key('coach-settings-save-bar')), findsNothing);

    // Verify notification switches
    expect(find.text('New bookings'), findsOneWidget);
    expect(find.text('Cancellations'), findsOneWidget);
    expect(find.text('Session reminders'), findsOneWidget);
    expect(find.text('Unavailable'), findsOneWidget);

    // Toggle New bookings switch
    final newBookingsFinder = find.widgetWithText(SwitchListTile, 'New bookings');
    await tester.tap(newBookingsFinder);
    await tester.pumpAndSettle();

    // Save bar must appear
    expect(find.byKey(const Key('coach-settings-save-bar')), findsOneWidget);
    expect(find.text('Unsaved changes'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);

    // Tap Save changes
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(repo.saves, 1);
    expect(repo.stored.newBookings, isFalse);
    expect(find.text('Settings saved.'), findsWidgets);
    expect(find.byKey(const Key('coach-settings-save-bar')), findsNothing);
  });

  testWidgets('conflict state displays changes need attention and retry save on timeout',
      (tester) async {
    final repo = PhoneSettingsFake('+60123456789');
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: CoachSettingsScreen(repository: repo),
      ),
    );
    await tester.pumpAndSettle();

    // Make dirty
    await tester.enterText(
        find.byKey(const Key('coach-phone-national')), '0129998888');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coach-settings-save-bar')), findsOneWidget);

    // Simulate timeout error
    repo.failure = 'deadline-exceeded';
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Could not save · Retry'), findsOneWidget);
    expect(find.text('Retry save'), findsOneWidget);

    // Retry after failure resolved
    repo.failure = null;
    await tester.tap(find.text('Retry save'));
    await tester.pumpAndSettle();

    expect(repo.saves, 2);
    expect(find.text('Settings saved.'), findsWidgets);
    expect(find.byKey(const Key('coach-settings-save-bar')), findsNothing);
  });

  for (final width in [320.0, 360.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Coach settings render width $width scale $scale',
          (tester) async {
        final repo = PhoneSettingsFake('+60123456789');
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(),
            builder: (c, child) => MediaQuery(
              data: MediaQuery.of(c)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: CoachSettingsScreen(repository: repo),
          ),
        );
        await tester.pumpAndSettle();

        // Must have 0 layout exceptions when clean
        expect(tester.takeException(), isNull);

        // Edit text to trigger save bar and verify no overflow when save bar is present
        await tester.enterText(
            find.byKey(const Key('coach-phone-national')), '0198887766');
        await tester.pumpAndSettle();

        expect(
            find.byKey(const Key('coach-settings-save-bar')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
