import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/features/identity/presentation/member/account_settings_screen.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:google_fonts/google_fonts.dart';

class _PreferencesRepository implements MemberPreferencesRepository {
  @override
  final scope = SessionScope(userId: 'member', organizationId: 'gym');
  MemberPreferences value = const MemberPreferences();
  bool failLoad = false;
  bool failSave = false;

  @override
  Future<MemberPreferences> load() async {
    if (failLoad) throw const MemberPreferencesException('Load failed.');
    return value;
  }

  @override
  Future<void> save(MemberPreferences preferences) async {
    if (failSave) throw const MemberPreferencesException('Save failed.');
    value = preferences;
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> mount(WidgetTester tester, _PreferencesRepository repository,
      {Future<void> Function(String)? verify,
      Future<void> Function(String)? change}) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(),
      home: AccountSettingsScreen(
          repository: repository,
          verifyCurrentPassword: verify,
          saveNewPassword: change),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'preferences persist across screen recreation and failed writes do not change values',
      (tester) async {
    final repository = _PreferencesRepository();
    await mount(tester, repository);
    expect(find.text('Deactivate account'), findsNothing);
    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();
    expect(find.text('Current password'), findsNothing);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Push notifications'));
    await tester.pumpAndSettle();
    expect(repository.value.pushNotifications, isTrue);
    repository.failSave = true;
    await tester.tap(find.widgetWithText(SwitchListTile, 'Email updates'));
    await tester.pumpAndSettle();
    expect(repository.value.emailUpdates, isFalse);
    repository.failSave = false;
    await tester.pumpWidget(const SizedBox());
    await mount(tester, repository);
    expect(
        tester
            .widget<SwitchListTile>(
                find.widgetWithText(SwitchListTile, 'Push notifications'))
            .value,
        isTrue);
    expect(
        tester
            .widget<SwitchListTile>(
                find.widgetWithText(SwitchListTile, 'Email updates'))
            .value,
        isFalse);
  });

  testWidgets('load failure offers retry instead of showing defaults',
      (tester) async {
    final repository = _PreferencesRepository()..failLoad = true;
    await mount(tester, repository);
    expect(find.text('Load failed.'), findsOneWidget);
    expect(find.text('Push notifications'), findsNothing);
    repository.failLoad = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Push notifications'), findsOneWidget);
  });

  testWidgets('change password uses supplied authentication callbacks',
      (tester) async {
    final repository = _PreferencesRepository();
    String? verified;
    String? saved;
    await mount(tester, repository, verify: (password) async {
      verified = password;
    }, change: (password) async {
      saved = password;
    });
    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Current password'), 'old-secret');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(verified, 'old-secret');
    await tester.enterText(
        find.widgetWithText(TextField, 'New password'), 'new-secret-123');
    await tester.enterText(
        find.widgetWithText(TextField, 'Confirm new password'),
        'new-secret-123');
    await tester.tap(find.text('Save new password'));
    await tester.pumpAndSettle();
    expect(saved, 'new-secret-123');
  });
}
