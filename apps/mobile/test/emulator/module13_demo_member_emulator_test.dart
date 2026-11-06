import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:gainpath_mobile/app/module13_demo_app.dart';
import 'package:gainpath_mobile/app/routing/exercise_tutorial_route.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/live_coach_directory_views.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_demo_recommendation.dart';
import 'package:gainpath_mobile/features/recommendation/presentation/member/personalized_recommendation_settings_screen.dart';
import '../support/module13_demo_emulator_transport.dart';
import '../support/module13_demo_render.dart';

void main() {
  setUpAll(loadDemoRenderFonts);
  testWidgets(
      'Actual demo Member identity, owned notifications and current Coach/tutorial routes',
      (tester) async {
    final old = HttpOverrides.current;
    HttpOverrides.global = null;
    final http.Client client = IOClient(HttpClient()
      ..idleTimeout = Duration.zero
      ..connectionTimeout = const Duration(seconds: 5));
    final gateway = EmulatorDemoAuthGateway(client),
        auth = FirebaseAuthRepository(gateway);
    FirebaseDemoMemberRepositories? repo;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      client.close();
      unawaited(auth.dispose());
      unawaited(gateway.dispose());
      HttpOverrides.global = old;
    });
    tester.view.physicalSize = const Size(393, 851);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Future<void> settle() async {
      for (var i = 0; i < 800; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)));
        await tester.pump(const Duration(milliseconds: 100));
        final e = tester.takeException();
        if (e != null) {
          throw e;
        }
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty &&
            find.byType(LinearProgressIndicator).evaluate().isEmpty &&
            !tester.binding.hasScheduledFrame) {
          return;
        }
      }
      fail('Demo Member operation did not settle');
    }

    Future<void> tap(Finder f) async {
      await tester.ensureVisible(f);
      await tester.tap(f);
      await settle();
    }

    const renderKey = ValueKey('seeded-demo');
    Future<void> verifyConsentUI() async {
      await tap(find.byTooltip('Privacy & Data'));
      await tap(find.text('Personalized Recommendations'));
      for (var i = 0;
          i < 800 &&
              find
                  .byType(PersonalizedRecommendationSettingsScreen)
                  .evaluate()
                  .isEmpty;
          i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await settle();
      expect(find.byType(PersonalizedRecommendationSettingsScreen),
          findsOneWidget);
      expect(find.textContaining('Current server state · revision'),
          findsOneWidget);
      expect(
          tester
              .widget<SwitchListTile>(
                  find.byKey(const ValueKey('exerciseInsights')))
              .value,
          isTrue);
      expect(find.textContaining('could not be loaded'), findsNothing);
      await captureDemo(tester, renderKey, 'seeded-member-consent');
    }

    final restored = await tester.runAsync(gateway.restoreUser);
    expect(restored?.emailVerified, isTrue);
    await tester.pumpWidget(RepaintBoundary(
        key: renderKey,
        child: Module13DemoMemberApp(
            theme: ThemeData(
                useMaterial3: true,
                fontFamily: 'Barlow',
                colorScheme:
                    const ColorScheme.light(primary: AppColors.primary)),
            authRepository: auth,
            repositories: (session, current) => repo =
                FirebaseDemoMemberRepositories(
                    gateway.transport(session, current)))));
    await settle();
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Demo Data'), findsOneWidget);
    if (Platform.environment['MODULE13_DEMO_CONSENT_CAPTURE_ONLY'] == '1') {
      await verifyConsentUI();
      await tester.pumpWidget(const SizedBox());
      client.close();
      return;
    }

    await captureDemo(tester, renderKey, 'seeded-member-inbox-393');
    for (final size in [const Size(375, 851), const Size(851, 393)]) {
      tester.view.physicalSize = size;
      await settle();
      await captureDemo(
          tester,
          renderKey,
          size.width == 375
              ? 'seeded-member-inbox-375'
              : 'seeded-member-inbox-landscape');
    }
    tester.view.physicalSize = const Size(393, 851);
    await settle();
    debugPrint('[demo-test] inbox request');
    // Keep pumping the widget test zone while a connection created by its UI is
    // reused; awaiting it inside runAsync would starve that zone's continuations.
    Map<String, Object?>? inbox;
    Object? inboxError;
    unawaited(repo!.transport.map('member.inbox',
        {'schemaVersion': 1, 'organizationId': 'gainpath'}).then((v) {
      inbox = v;
    }, onError: (Object e) {
      inboxError = e;
    }));
    for (var i = 0; i < 800 && inbox == null && inboxError == null; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(inboxError, isNull);
    expect(inbox, isNotNull);
    debugPrint('[demo-test] inbox response');
    final records = (inbox!['records'] as List).cast<Map>();
    expect(records, hasLength(2));
    for (final notice in records) {
      debugPrint('[demo-test] open recommendation');
      await tap(find.text(notice['title'] as String).first);
      debugPrint('[demo-test] recommendation opened');
      final coach = find.text('View Coach').evaluate().isNotEmpty;
      await tap(find.text(coach ? 'View Coach' : 'View Tutorial'));
      debugPrint('[demo-test] destination opened');
      expect(
          coach
              ? find.byType(LiveCoachDetailView)
              : find.byType(ExerciseTutorialRoute),
          findsOneWidget);
      await captureDemo(tester, renderKey,
          coach ? 'seeded-member-coach' : 'seeded-member-tutorial');
      if (coach) {
        await tester.scrollUntilVisible(find.text('Book a session'), 200,
            scrollable: find.byType(Scrollable).last);
        await settle();
        await tap(find.text('Book a session'));
        expect(
            find.text(
                'Booking and payment are outside this controlled demonstration.'),
            findsOneWidget);
      }
      await tester.pageBack();
      await settle();
      await tap(find.text(coach ? 'Acknowledge' : 'Dismiss recommendation'));
      await tap(find.byTooltip('Close recommendation'));
    }
    await tap(find.byTooltip('Workout history'));
    expect(find.text('Activity timeline'), findsOneWidget);
    expect(find.textContaining('3 saved sessions'), findsOneWidget);
    await captureDemo(tester, renderKey, 'seeded-member-history');
    await tester.pageBack();
    await settle();
    await verifyConsentUI();
    await tester.pumpWidget(const SizedBox());
    client.close();
  },
      skip: Platform.environment['MODULE13_DEMO_GATEWAY'] != '127.0.0.1:15019',
      timeout: const Timeout(Duration(minutes: 5)));
}
