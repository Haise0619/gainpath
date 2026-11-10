import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_mobile/features/workout/application/workout_preferences_controller.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_prep_screen.dart';
import 'package:gainpath_mobile/navigation/workout_navigation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pose_preview_authorization_test.dart'
    show PreviewAuthRepository, PreviewAuthBloc, previewAuthState;
import 'workout_preferences_test.dart' show MemoryWorkoutPreferencesStore;

class HandoffObserver extends NavigatorObserver {
  HandoffObserver(this.interrupt);
  final VoidCallback interrupt;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) interrupt();
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final accepted in [false, true]) {
    for (final interruption in [
      'none',
      'account-return',
      'background',
      'handoff-background'
    ]) {
      testWidgets(
          'preview launch persisted=$accepted interruption=$interruption',
          (tester) async {
        final repository = PreviewAuthRepository(), auth = PreviewAuthBloc();
        whenListen(auth, repository.changes.stream.map(previewAuthState),
            initialState: previewAuthState(repository.current));
        final preferences = WorkoutPreferencesController(
            scope: repository.current!.scope,
            store: MemoryWorkoutPreferencesStore());
        await preferences.load();
        if (accepted) await preferences.grantConsent();
        var navigations = 0;
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await auth.close();
          await repository.dispose();
          preferences.dispose();
        });
        await tester.pumpWidget(BlocProvider<AuthBloc>.value(
            value: auth,
            child: MaterialApp(
                navigatorObservers: [
                  HandoffObserver(() {
                    if (interruption == 'handoff-background' && accepted) {
                      tester.binding.handleAppLifecycleStateChanged(
                          AppLifecycleState.paused);
                      tester.binding.handleAppLifecycleStateChanged(
                          AppLifecycleState.resumed);
                    }
                  })
                ],
                home: WorkoutPrepScreen(
                    live: true,
                    preferencesFactory: (_) async => preferences,
                    routes: WorkoutPrepRoutes(posePreviewBuilder: (_) {
                      navigations++;
                      return const Scaffold(body: Text('Authorized preview'));
                    })))));
        await tester.scrollUntilVisible(
            find.text('Try live camera preview'), 200);
        await tester.tap(find.text('Try live camera preview'));
        await tester.pumpAndSettle();
        if (!accepted) {
          expect(navigations, 0);
          expect(find.text('AI Tracking privacy'), findsOneWidget);
          if (interruption == 'account-return') {
            final original = repository.current!;
            repository.change(const AuthSession(
                userId: 'other',
                organizationId: 'gainpath',
                email: 'fixture@example.invalid',
                role: AppRole.member));
            await tester.pump();
            repository.change(original);
            await tester.pump();
          } else if (interruption == 'background') {
            tester.binding
                .handleAppLifecycleStateChanged(AppLifecycleState.paused);
            tester.binding
                .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          }
          await tester.tap(find.byType(CheckboxListTile));
          await tester.pump();
          await tester.ensureVisible(find.text('Accept AI Tracking'));
          await tester.tap(find.text('Accept AI Tracking'));
          await tester.pumpAndSettle();
          expect(
              navigations,
              interruption == 'none' || interruption == 'handoff-background'
                  ? 1
                  : 0);
        } else {
          expect(find.text('AI Tracking privacy'), findsNothing);
          expect(navigations, interruption == 'handoff-background' ? 0 : 1);
        }
      }, skip: !const bool.fromEnvironment('GAINPATH_POSE_PREVIEW'));
    }
  }
}
