import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_mobile/features/identity/presentation/member/account_settings_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class _FakeAuthBloc extends Fake implements AuthBloc {
  _FakeAuthBloc(this.state);
  final _controller = StreamController<AuthState>.broadcast();

  @override
  AuthState state;

  @override
  Stream<AuthState> get stream => _controller.stream;

  @override
  Future<void> close() async {
    await _controller.close();
  }
}

class _MockPreferencesRepository implements MemberPreferencesRepository {
  @override
  final scope = SessionScope(userId: 'member-1', organizationId: 'gym-1');
  MemberPreferences value = const MemberPreferences(
    pushNotifications: true,
    emailUpdates: false,
    voiceCoaching: true,
  );

  @override
  Future<MemberPreferences> load() async => value;

  @override
  Future<void> save(MemberPreferences preferences) async {
    value = preferences;
  }
}

class _MockContactRepository
    implements MemberContactDetailsRepository, MemberDisplayNameRepository {
  MemberContactDetails details = const MemberContactDetails(
    displayName: 'Alex Morgan',
    value: '+1 (555) 234-5678',
    editBaseline: 1,
  );

  @override
  Future<MemberContactDetails> load() async => details;

  @override
  Future<MemberContactDetails> save(
      MemberContactDetails original, String value) async {
    return details = MemberContactDetails(
      displayName: details.displayName,
      value: value,
      editBaseline: 2,
    );
  }

  @override
  Future<MemberContactDetails> saveDisplayName(
      MemberContactDetails original, String value) async {
    return details = MemberContactDetails(
      displayName: value,
      value: details.value,
      editBaseline: 3,
    );
  }
}

MemberAccountLifecycle _makeLifecycle({bool pending = false}) =>
    MemberAccountLifecycle(
      state: pending ? 'pendingDeletion' : 'active',
      revision: pending ? 1 : 0,
      requestedAtMillis: pending ? 1000000 : null,
      retentionEndsAtMillis: pending ? 2593000000 : null,
      policy: pending ? 'grace30Days' : 'pendingApproval',
      sessionNotBeforeSeconds: pending ? 1001 : 0,
      sessionRevocationPending: false,
      reactivationAllowed: false,
      reactivationAvailableAtMillis: pending ? 4900000 : null,
      currentTimeMillis: 1200000,
      lastRequestId: pending ? 'request_0001' : null,
      editBaseline: Object(),
    );

class _MockLifecycleRepository implements MemberAccountLifecycleRepository {
  MemberAccountLifecycle current = _makeLifecycle();

  @override
  Future<MemberAccountLifecycle> load() async => current;

  @override
  Future<void> verifyCurrentPassword(String password) async {}

  @override
  Future<MemberAccountLifecycle> requestDeactivation(
      MemberAccountLifecycle original) async {
    return current = _makeLifecycle(pending: true);
  }

  @override
  Future<MemberAccountLifecycle> cancelDeactivation(
      MemberAccountLifecycle original) async {
    return current = _makeLifecycle(pending: false);
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('render redesigned Member Settings page and capture screenshot',
      (tester) async {
    tester.view.physicalSize = const Size(412 * 2.0, 1400 * 2.0);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final prefRepo = _MockPreferencesRepository();
    final contactRepo = _MockContactRepository();
    final lifecycleRepo = _MockLifecycleRepository();

    const session = AuthSession(
      userId: 'member-1',
      organizationId: 'gym-1',
      email: 'alex.morgan@gainpath.com',
      displayName: 'Alex Morgan',
      role: AppRole.member,
    );

    final authBloc = _FakeAuthBloc(
      const AuthState(
        status: AuthStatus.signedIn,
        role: AppRole.member,
        session: session,
      ),
    );
    addTearDown(authBloc.close);

    final repaintKey = GlobalKey();

    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF9F7FC),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF5C19D9),
              surface: Colors.white,
              brightness: Brightness.light,
            ),
          ),
          builder: (context, child) => RepaintBoundary(
            key: repaintKey,
            child: child!,
          ),
          home: Scaffold(
            body: AccountSettingsScreen(
              repository: prefRepo,
              contactSession: session,
              contactRepository: contactRepo,
              lifecycleRepository: lifecycleRepo,
              verifyCurrentPassword: (_) async {},
              saveNewPassword: (_) async {},
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: 4,
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.home_outlined), label: 'Home'),
                NavigationDestination(
                    icon: Icon(Icons.fitness_center), label: 'Workout'),
                NavigationDestination(
                    icon: Icon(Icons.emoji_events_outlined),
                    label: 'Rewards'),
                NavigationDestination(
                    icon: Icon(Icons.people_outline), label: 'Coaches'),
                NavigationDestination(
                    icon: Icon(Icons.person), label: 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify all 5 sections are present
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(find.text('Alex Morgan'), findsOneWidget);
    expect(find.text('+1 (555) 234-5678'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);

    expect(find.text('NOTIFICATIONS'), findsOneWidget);
    expect(find.text('Push notifications'), findsOneWidget);
    expect(find.text('Email updates'), findsOneWidget);

    expect(find.text('WORKOUT'), findsOneWidget);
    expect(find.text('Privacy & AI Tracking'), findsOneWidget);
    expect(find.text('Voice coaching'), findsOneWidget);

    expect(find.text('SECURITY'), findsOneWidget);
    expect(find.text('Change password'), findsOneWidget);
    expect(find.text('Privacy and data'), findsOneWidget);

    expect(find.text('ACCOUNT DEACTIVATION'), findsOneWidget);
    expect(find.text('Deactivate account'), findsNWidgets(2)); // Title and Button

    // Capture Settings page screenshot
    final outDir = Directory('build/member-ui-renders');
    await tester.runAsync(() async {
      final boundary =
          repaintKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final file = File('${outDir.path}/member_settings_screen_redesigned_full.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      image.dispose();
    });

    // Tap Profile Summary Card to open Edit Profile screen
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Profile & Contact'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Display name'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Contact details'), findsOneWidget);
    expect(find.text('Save display name'), findsOneWidget);
    expect(find.text('Save contact details'), findsOneWidget);

    // Capture Edit Profile screen screenshot
    await tester.runAsync(() async {
      final boundary =
          repaintKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final file = File('${outDir.path}/member_settings_edit_profile_screen.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      image.dispose();
    });
  });
}
