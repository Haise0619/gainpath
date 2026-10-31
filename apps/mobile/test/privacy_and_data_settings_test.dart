import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/features/identity/presentation/member/account_settings_screen.dart';
import 'package:gainpath_mobile/features/identity/presentation/member/privacy_and_data_settings_screen.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:google_fonts/google_fonts.dart';

class _FakePreferencesRepo implements MemberPreferencesRepository {
  @override
  final scope = SessionScope(userId: 'member1', organizationId: 'gym1');
  @override
  Future<MemberPreferences> load() async => const MemberPreferences();
  @override
  Future<void> save(MemberPreferences preferences) async {}
}

class FakeModule9Sharing implements Module9Repository {
  @override
  Stream<void> watchInbox() => const Stream.empty();
  CoachSharing sharing = const CoachSharing(false, 0);
  bool failSave = false;
  int? expectedRevision;

  @override
  Future<CoachSharing> loadSharing() async => sharing;

  @override
  Future<CoachSharing> saveSharing(bool enabled, int revision) async {
    expectedRevision = revision;
    if (failSave) throw StateError('offline');
    return sharing = CoachSharing(enabled, revision + 1);
  }

  @override
  Future<NoticePage> loadInbox({String? afterId}) async =>
      const NoticePage([], null);

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<CoachReport> loadPerformance() => throw UnimplementedError();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
      'Privacy & Data screen: grants sharing, revision checks, and failure retains verified state',
      (tester) async {
    final repo = FakeModule9Sharing();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(),
      home: PrivacyAndDataSettingsScreen(
        repository: repo,
        isCurrent: () => true,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Privacy & Data'), findsOneWidget);
    expect(find.text('POSTURE & CAMERA DATA'), findsOneWidget);
    expect(find.text('Share posture history with my Coaches'), findsOneWidget);

    final switchFinder = find.byType(SwitchListTile);
    expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);

    // Toggle on
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    expect(repo.expectedRevision, 0);
    expect(repo.sharing.enabled, isTrue);
    expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);

    // Toggle fail
    repo.failSave = true;
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);
    expect(find.text('Could not verify this change. Reload before trying again.'),
        findsOneWidget);
  });

  testWidgets('AccountSettings navigates to Privacy & Data with Posture sharing',
      (tester) async {
    final prefRepo = _FakePreferencesRepo();
    final module9Repo = FakeModule9Sharing();

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(),
      home: AccountSettingsScreen(
        repository: prefRepo,
        module9Repository: module9Repo,
        isSessionCurrent: () => true,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Privacy and data'), findsOneWidget);
    expect(find.text('Posture & camera data sharing'), findsOneWidget);

    await tester.tap(find.text('Privacy and data'));
    await tester.pumpAndSettle();

    expect(find.text('Privacy & Data'), findsOneWidget);
    expect(find.text('Your posture privacy'), findsOneWidget);
  });

  testWidgets('Session changed blocks privacy view', (tester) async {
    var sessionCurrent = false;
    final repo = FakeModule9Sharing();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(),
      home: PrivacyAndDataSettingsScreen(
        repository: repo,
        isCurrent: () => sessionCurrent,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Session changed. Return to sign in.'), findsOneWidget);
  });
}
