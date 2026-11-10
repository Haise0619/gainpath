import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_mobile/features/workout/application/workout_preferences_controller.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_prep_screen.dart';
import '../workout_preferences_test.dart' show MemoryWorkoutPreferencesStore;

/// Uses the real authentication/consent contracts; never injects a consent bool.
Future<WorkoutPreferencesController> openWorkoutConsent(
  WidgetTester tester, {
  required bool previouslyAccepted,
  required String instruction,
  String? setupLabel,
}) async {
  late AuthBloc auth;
  await tester.runAsync(() async {
    auth = AuthBloc(
        repository: InMemoryAuthRepository(organizationId: 'gainpath'));
    await Future<void>.delayed(Duration.zero);
    auth.add(const LoginSubmitted(
        email: 'member@example.com', password: 'password123'));
    await auth.stream.firstWhere((s) => s.status == AuthStatus.signedIn);
  });
  final preferences = WorkoutPreferencesController(
      scope: auth.state.session!.scope, store: MemoryWorkoutPreferencesStore());
  await preferences.load();
  if (previouslyAccepted) await preferences.grantConsent();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    preferences.dispose();
    await auth.close();
  });
  await tester.pumpWidget(BlocProvider.value(
      value: auth,
      child: MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => showWorkoutCaptureConsent(context,
                          preferences: preferences,
                          onUploadChanged: (_) {},
                          allowUpload: false,
                          exerciseInstruction: instruction,
                          setupConfirmationLabel: setupLabel),
                      child: const Text('Open test consent')))))));
  await tester.tap(find.text('Open test consent'));
  await tester.pumpAndSettle();
  if (!previouslyAccepted) {
    expect(preferences.validConsent, isFalse);
    expect(find.text('AI Tracking privacy'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Accept AI Tracking'))
            .onPressed,
        isNull);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.ensureVisible(find.text('Accept AI Tracking'));
    await tester.tap(find.text('Accept AI Tracking'));
    await tester.pumpAndSettle();
  } else {
    expect(find.text('AI Tracking privacy'), findsNothing);
  }
  expect(preferences.validConsent, isTrue);
  expect(find.text(instruction), findsOneWidget);
  expect(
      tester
          .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Ready to continue'))
          .onPressed,
      isNull);
  expect(find.text('Also allow this measured summary to be uploaded.'),
      findsNothing);
  return preferences;
}

Future<void> confirmWorkoutSetup(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(CheckboxListTile));
  await tester.tap(find.byType(CheckboxListTile));
  await tester.pump();
  expect(
      tester
          .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Ready to continue'))
          .onPressed,
      isNotNull);
  await tester.ensureVisible(find.text('Ready to continue'));
  await tester.tap(find.text('Ready to continue'));
  await tester.pumpAndSettle();
}
