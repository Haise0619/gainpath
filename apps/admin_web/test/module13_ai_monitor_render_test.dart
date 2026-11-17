// Actual Flutter widgets with fictional saved records. Offline renders substitute
// Arial for production Poppins/Inter through the existing render infrastructure.
import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_admin_web/features/recommendation/presentation/admin/admin_recommendation_screens.dart';
import '../../../test_support/fyp_render_support.dart';
import 'support/module13_demo_render.dart';
import 'support/canonical_admin_recommendation_fixture.dart';
import 'support/recommendation_queue_fixture.dart';
import 'module13_ai_monitor_test.dart' show aiMonitorRecord;

void main() {
  final metrics = <Map<String, Object?>>[];
  setUpAll(loadDemoRenderFonts);
  for (final layout in [
    (1440.0, 1.0),
    (1024.0, 1.0),
    (390.0, 1.0),
    (320.0, 1.0),
    (390.0, 2.0)
  ]) {
    testWidgets('AI monitor real Flutter render ${layout.$1} ${layout.$2}',
        (tester) async {
      addTearDown(await installFypOfflineFonts());
      tester.view.physicalSize = Size(layout.$1, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final boundary = GlobalKey();
      final records = [
        aiMonitorRecord(member: 'Alex Lim'),
        aiMonitorRecord(
            kind: 'content', member: 'Jia Chen', id: 'e', daysAgo: 2),
        aiMonitorRecord(
            kind: 'trainer',
            member: 'Sam Tan',
            method: 'rule_fallback',
            status: 'prepared',
            id: 'f',
            daysAgo: 3),
      ];
      final routine = records.first['suggestion']! as Map<String, Object?>;
      (routine['ai']! as Map<String, Object?>).addAll({
        'changedOrder': true,
        'candidateCount': 12,
        'latencyMillis': 826,
      });
      final harness = CanonicalAdminHarness()
        ..records = records
        ..record = records.first;
      final base = AppTheme.build();
      final typography =
          ThemeData(useMaterial3: true).textTheme.apply(fontFamily: 'CReview');
      final elapsed = Stopwatch()..start();
      await tester.pumpWidget(RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: base.copyWith(
                textTheme: typography
                    .merge(base.textTheme.apply(fontFamily: 'CReview')),
                primaryTextTheme: typography
                    .merge(base.primaryTextTheme.apply(fontFamily: 'CReview'))),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(layout.$2)),
                child: child!),
            home: ColoredBox(
                color: AppColors.bg,
                child: RiskLeaderboardScreen(
                    canonicalRepository: harness.repository,
                    queueClock: () => queueNow)),
          )));
      await tester.pumpAndSettle();
      elapsed.stop();
      metrics.add({
        'width': layout.$1,
        'textScale': layout.$2,
        'widgetLoadMillis': elapsed.elapsedMilliseconds,
        'records': records.length,
        'listRequests': harness.requests.length
      });
      expect(tester.takeException(), isNull);
      final suffix = '${layout.$1.toInt()}-${(layout.$2 * 100).toInt()}';
      Future<void> capture(String name) async {
        await tester.runAsync(() async {
          final image = await tester
              .renderObject<RenderRepaintBoundary>(find.byKey(boundary))
              .toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file =
              File('../../build/module13-ai/evidence/admin-$name-$suffix.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('overview');
      await tester.ensureVisible(find.text('View').first);
      await tester.pumpAndSettle();
      if (layout.$1 < 1100) {
        await Scrollable.ensureVisible(
            tester.element(find.byKey(ValueKey(records.first['id']! as String))),
            alignment: 0);
        await tester.pumpAndSettle();
        await capture('records');
      }
      await tester.tap(find.text('View').first);
      await tester.pumpAndSettle();
      expect(find.text('Workout context'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture('details');
      await tester.ensureVisible(find.text('Technical Details'));
      await tester.tap(find.text('Technical Details'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.textContaining('Member account:'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture('technical');
      await tester.ensureVisible(find.text('Close'));
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delivery Issues'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture('issues');
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture('history');
      await tester.runAsync(() =>
          File('../../build/module13-ai/evidence/admin-render-metrics.json')
              .writeAsString(const JsonEncoder.withIndent('  ').convert({
            'source':
                'Fictional saved-record widget harness. Excludes Firebase, Gemini and network time.',
            'fontSubstitution':
                'Arial replaces production Poppins/Inter for offline renders.',
            'scenarios': metrics,
          })));
    }, skip: !const bool.fromEnvironment('GAINPATH_RENDER_MODULE13_AI'));
  }
}
