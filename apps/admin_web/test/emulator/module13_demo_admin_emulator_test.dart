import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:gainpath_admin_web/app/module13_demo_app.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_demo_recommendation.dart';
import '../support/module13_demo_emulator_transport.dart';
import '../support/module13_demo_render.dart';

void main() {
  setUpAll(loadDemoRenderFonts);
  testWidgets(
      'Actual demo Admin identity, seeded queues, review Send and controlled delivery',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final old = HttpOverrides.current;
    HttpOverrides.global = null;
    final http.Client client = IOClient(HttpClient()
      ..idleTimeout = Duration.zero
      ..connectionTimeout = const Duration(seconds: 5));
    final gateway = EmulatorDemoAuthGateway(client),
        auth = FirebaseAuthRepository(gateway);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      client.close();
      unawaited(auth.dispose());
      unawaited(gateway.dispose());
      HttpOverrides.global = old;
    });
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Future<void> settle() async {
      for (var i = 0; i < 1200; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)));
        await tester.pump(const Duration(milliseconds: 100));
        final e = tester.takeException();
        if (e != null) {
          throw e;
        }
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty &&
            find.byType(LinearProgressIndicator).evaluate().isEmpty &&
            find.text('Delivering…').evaluate().isEmpty &&
            !tester.binding.hasScheduledFrame) {
          return;
        }
      }
      fail('Demo Admin request did not settle');
    }

    Future<void> tap(Finder f) async {
      await tester.ensureVisible(f);
      await tester.tap(f);
      await settle();
    }

    final restored = await tester.runAsync(gateway.restoreUser);
    expect(restored?.emailVerified, isTrue);
    const renderKey = ValueKey('seeded-demo');
    await tester.pumpWidget(RepaintBoundary(
        key: renderKey,
        child: Module13DemoAdminApp(
            theme: ThemeData(
                useMaterial3: true,
                fontFamily: 'CReview',
                colorScheme:
                    const ColorScheme.light(primary: AppColors.primary)),
            authRepository: auth,
            repositories: (session, current) => FirebaseDemoAdminRepositories(
                gateway.transport(session, current)))));
    await settle();
    await captureDemo(tester, renderKey, 'seeded-admin-insights-1400');
    tester.view.physicalSize = const Size(600, 1600);
    await settle();
    await captureDemo(tester, renderKey, 'seeded-admin-insights-600');
    tester.view.physicalSize = const Size(1400, 1600);
    await settle();
    expect(find.text('Exercise Insights'), findsWidgets);
    expect(find.textContaining('could not be loaded'), findsNothing);
    for (final tab in ['Trainer Matching', 'Content Recommendations']) {
      await tap(find.text(tab).first);
      expect(find.text('Demo Learner 02'), findsOneWidget);
      await captureDemo(
          tester,
          renderKey,
          tab == 'Trainer Matching'
              ? 'seeded-admin-trainer-1400'
              : 'seeded-admin-content-1400');
      final card = find
          .ancestor(
              of: find.text('Demo Learner 02'), matching: find.byType(Panel))
          .first;
      await tap(find.descendant(of: card, matching: find.text('View details')));
      expect(find.byType(AdminDialog), findsOneWidget);
      await captureDemo(
          tester,
          renderKey,
          tab == 'Trainer Matching'
              ? 'seeded-admin-trainer-details'
              : 'seeded-admin-content-details');
      await tap(find.text('Close').last);
      await tap(find.descendant(of: card, matching: find.text('Send')));
      expect(find.byType(AdminDialog), findsOneWidget);
      await tap(find.text('Confirm Send').last);
      expect(find.textContaining('Prepared locally. No notification'),
          findsOneWidget);
    }
    await tap(find.text('Deliver prepared'));
    expect(find.textContaining('Delivery confirmed for 2'), findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data)
            .whereType<String>()
            .take(20)
            .join(' | '));
    await tester.pumpWidget(const SizedBox());
    client.close();
  },
      skip: Platform.environment['MODULE13_DEMO_GATEWAY'] != '127.0.0.1:15019',
      timeout: const Timeout(Duration(minutes: 5)));
}
