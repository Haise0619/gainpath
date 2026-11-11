import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_mobile/features/workout/application/workout_preferences_controller.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_ai_consent_guard.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_privacy_settings_screen.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'workout_preferences_test.dart'
    show scope, MemoryWorkoutPreferencesStore;

class _CaptureChild extends StatefulWidget {
  const _CaptureChild(this.onDispose);
  final VoidCallback onDispose;
  @override
  State<_CaptureChild> createState() => _CaptureChildState();
}

class _CaptureChildState extends State<_CaptureChild> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Text('camera capture mounted'));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'privacy consent and preferences are usable on a small phone with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemoryWorkoutPreferencesStore();
    final c = WorkoutPreferencesController(scope: scope, store: store);
    await c.load();
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                padding: const EdgeInsets.only(bottom: 24)),
            child: child!),
        home: WorkoutPrivacySettingsScreen(
            scope: scope,
            isCurrent: () => true,
            preferencesFactory: (_) async => c)));
    await tester.pumpAndSettle();
    expect(find.text('AI Tracking consent required'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.text('Review and enable AI Tracking'), 150);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review and enable AI Tracking'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byType(CheckboxListTile), 180,
        scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.scrollUntilVisible(find.text('Accept AI Tracking'), 180,
        scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept AI Tracking'));
    await tester.pumpAndSettle();
    expect(c.validConsent, isTrue);
    await tester.scrollUntilVisible(
        find.text('Withdraw AI Tracking consent'), 150);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Withdraw AI Tracking consent'));
    await tester.pumpAndSettle();
    expect(c.validConsent, isFalse);
    final betweenExercises =
        find.widgetWithText(SwitchListTile, 'Auto-Continue Between Exercises');
    await tester.scrollUntilVisible(betweenExercises, 150);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(betweenExercises).value, isTrue);
    await tester.tap(betweenExercises);
    await tester.pumpAndSettle();
    expect(c.autoContinue, isFalse);

    final betweenSets =
        find.widgetWithText(SwitchListTile, 'Auto-Continue Between Sets');
    await tester.scrollUntilVisible(betweenSets, 150);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(betweenSets).value, isFalse);
    await tester.tap(betweenSets);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(betweenSets).value, isTrue);
    expect(store.value!['autoContinueBetweenSets'], isTrue);
    expect(c.autoContinue, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'withdrawal disposes active capture and re-enable cannot restart it',
      (tester) async {
    final c = WorkoutPreferencesController(
        scope: scope, store: MemoryWorkoutPreferencesStore());
    await c.load();
    await c.grantConsent();
    var disposed = false;
    WorkoutPreferencesController? capturePreferences;
    await tester.pumpWidget(MaterialApp(
        home: WorkoutAiConsentGuard(
            scope: scope,
            isCurrent: () => true,
            preferencesFactory: (_) async => c,
            child: Builder(builder: (context) {
              capturePreferences = WorkoutAiConsentGuard.preferencesOf(context);
              return _CaptureChild(() => disposed = true);
            }))));
    await tester.pumpAndSettle();
    expect(find.text('camera capture mounted'), findsOneWidget);
    expect(capturePreferences, same(c));
    var withdrew = false;
    capturePreferences!.addListener(() {
      if (!capturePreferences!.validConsent) withdrew = true;
    });
    await c.updatePreferences(autoContinueBetweenSets: true);
    await tester.pumpAndSettle();
    expect(disposed, isFalse);
    expect(capturePreferences!.autoContinueBetweenSets, isTrue);
    final withdrawal = c.withdrawConsent();
    expect(withdrew, isTrue);
    await withdrawal;
    await tester.pumpAndSettle();
    expect(disposed, isTrue);
    expect(find.text('camera capture mounted'), findsNothing);
    expect(find.text('AI Tracking has stopped'), findsOneWidget);
    await c.grantConsent();
    await tester.pumpAndSettle();
    expect(find.text('camera capture mounted'), findsNothing);
  });

  testWidgets('first-time and foreign-account consent cannot mount capture',
      (tester) async {
    final c = WorkoutPreferencesController(
        scope: scope, store: MemoryWorkoutPreferencesStore());
    await c.load();
    var disposed = false;
    await tester.pumpWidget(MaterialApp(
        home: WorkoutAiConsentGuard(
            scope: scope,
            isCurrent: () => true,
            preferencesFactory: (_) async => c,
            child: _CaptureChild(() => disposed = true))));
    await tester.pumpAndSettle();
    expect(find.text('camera capture mounted'), findsNothing);
    expect(find.text('AI Tracking consent required'), findsOneWidget);
    expect(disposed, isFalse);
  });

  testWidgets('production consent guard honors authenticated scope and logout',
      (tester) async {
    late AuthBloc auth;
    await tester.runAsync(() async {
      auth = AuthBloc(
          repository: InMemoryAuthRepository(organizationId: 'gainpath'));
      await Future<void>.delayed(Duration.zero);
      auth.add(const LoginSubmitted(
          email: 'member@example.com', password: 'password123'));
      await auth.stream.firstWhere((s) => s.status == AuthStatus.signedIn);
    });
    final c = WorkoutPreferencesController(
        scope: auth.state.session!.scope,
        store: MemoryWorkoutPreferencesStore());
    await c.load();
    await c.grantConsent();
    var disposed = false;
    await tester.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
            home: WorkoutAiConsentGuard(
                scope: c.scope,
                preferencesFactory: (_) async => c,
                child: _CaptureChild(() => disposed = true)))));
    await tester.pumpAndSettle();
    expect(find.text('camera capture mounted'), findsOneWidget);
    await tester.runAsync(() async {
      auth.add(const LoggedOut());
      await auth.stream.firstWhere((s) => s.status != AuthStatus.signedIn);
    });
    await tester.pumpAndSettle();
    expect(disposed, isTrue);
    expect(find.text('camera capture mounted'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(auth.close);
  });
}
