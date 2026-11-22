import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/recommendation/presentation/admin/canonical_admin_recommendation_panel.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_admin_web/features/recommendation/presentation/admin/recommendation_monitor.dart';

import '../../../test_support/fyp_render_support.dart';
import 'module13_ai_monitor_test.dart' show aiMonitorRecord;
import 'support/canonical_admin_recommendation_fixture.dart';
import 'support/recommendation_queue_fixture.dart';

const _message = 'Practice the selected movement with a controlled tempo. '
    'Your saved strength goal and recent sessions were used to choose this recommendation.';
const _name = 'Amelia Nur Aisyah Binti Muhammad Zainal Abidin';
const _capture = bool.fromEnvironment('CAPTURE_RECOMMENDATIONS_OVERVIEW');

Map<String, Object?> _row(String id, String kind, String member, int days,
    {String method = 'gemini',
    String status = 'delivered',
    bool outreach = false}) {
  final result = aiMonitorRecord(
      id: id,
      kind: kind,
      member: member,
      daysAgo: days,
      status: status,
      method: method);
  final suggestion = result['suggestion']! as Map<String, Object?>;
  (suggestion['ai']! as Map<String, Object?>).addAll({
    'fitnessGoals': ['buildMuscle'],
    'factors': ['goal_match', 'coach_specialization'],
    'candidateCount': 4,
    'ruleFirstLabel': 'Foundation option',
    if (method == 'gemini') 'geminiFirstLabel': 'Selected option',
    if (method == 'rule_fallback') 'fallbackReason': 'provider_unavailable',
  });
  suggestion['summary'] = _message;
  if (outreach) {
    suggestion['source'] = {'kind': 'admin_outreach'};
    suggestion['outreach'] = {'sentBy': 'test-admin'};
  }
  return result;
}

final _rows = [
  _row('a', 'trainer', _name, 1, outreach: true),
  _row('b', 'content', 'Hana Lee', 2),
  _row('c', 'routine', 'Aaron Chan', 3),
  _row('d', 'content', 'Ravi Kumar', 4,
      method: 'rule_fallback', status: 'prepared'),
  _row('e', 'content', 'Sandra Foo', 6, status: 'pending'),
  _row('f', 'trainer', 'Jia Chen', 9),
  _row('1', 'content', 'Historic Fixture Member', 44, status: 'dismissed'),
];

Future<CanonicalAdminHarness> _show(WidgetTester tester, GlobalKey capture,
    {Size size = const Size(1440, 900),
    bool fonts = false,
    ValueNotifier<bool>? activity,
    List<Map<String, Object?>>? records}) async {
  if (fonts) {
    addTearDown(await installFypOfflineFonts());
    final icons = File(
        'C:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      final bytes = ByteData.sublistView(icons.readAsBytesSync());
      await (FontLoader('MaterialIcons')..addFont(Future.value(bytes))).load();
    }
  }
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = CanonicalAdminHarness()..records = records ?? _rows;
  final panel = CanonicalAdminRecommendationPanel(
      repository: h.repository, clock: () => queueNow);
  await tester.pumpWidget(RepaintBoundary(
    key: capture,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: fonts ? AppTheme.build() : ThemeData(useMaterial3: true),
      home: Scaffold(
          body: Stack(
        children: [
          if (activity == null)
            panel
          else
            ValueListenableBuilder<bool>(
              valueListenable: activity,
              child: panel,
              builder: (_, active, child) =>
                  RecommendationMonitorActivity(active: active, child: child!),
            ),
          if (fonts)
            const Positioned(
                bottom: 5,
                left: 8,
                child: IgnorePointer(
                  child: Chip(label: Text('Fixture data')),
                )),
        ],
      )),
    ),
  ));
  await tester.pumpAndSettle();
  return h;
}

Future<void> _open(
    WidgetTester tester, CanonicalAdminHarness h, int index) async {
  h.record = _rows[index];
  final button = find.byKey(ValueKey('recommendation-open-${h.record['id']}'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester, GlobalKey capture, String name) async {
  final boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(capture));
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final output =
        File('../../build/recommendations-overview-redesign/fixture-$name.png');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  testWidgets(
      'preserves loaded metrics and shows the saved message once in a right drawer',
      (tester) async {
    final h = await _show(tester, GlobalKey(), size: const Size(1440, 1200));
    expect(find.text('Recommendations Overview'), findsOneWidget);
    expect(find.textContaining('7 loaded'), findsOneWidget);
    for (final metric in {
      'Total recommendations': '7',
      'Delivered': '4',
      'Delivery issues': '1',
      'Tutorials': '4',
      'Coaches': '2',
      'Routines': '1',
    }.entries) {
      final count = tester.widget<Text>(
          find.byKey(ValueKey('recommendation-metric-${metric.key}')));
      expect(count.data, metric.value);
    }
    final existingButton = find.text('View Details').first;
    h.record = _rows.first;
    await tester.ensureVisible(existingButton);
    await tester.tap(existingButton);
    await tester.pumpAndSettle();
    expect(find.text(_message), findsOneWidget);
    expect(find.text('Goal match'), findsOneWidget);
    expect(find.text('Coach specialization'), findsOneWidget);
    final drawer = find.byKey(const ValueKey('recommendation-details-drawer'));
    expect(tester.getRect(drawer).right, 1440);
    final close = find.byTooltip('Close details');
    final fixed = tester.getTopLeft(close);
    await tester.ensureVisible(find.text('Technical Details'));
    await tester.tap(find.text('Technical Details'));
    await tester.pumpAndSettle();
    expect(find.textContaining('goal_match'), findsOneWidget);
    expect(tester.getTopLeft(close), fixed);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(drawer, findsNothing);
    await tester.pump();
    final button =
        find.ancestor(of: existingButton, matching: find.byType(TextButton));
    expect(tester.widget<TextButton>(button.first).focusNode!.hasFocus, isTrue);
    expect(h.requests.map((r) => r['operation']),
        ['admin.queue.list', 'admin.queue.detail']);
  });

  testWidgets(
      'renders all required desktop widths and a narrow full-screen drawer',
      (tester) async {
    final h = await _show(tester, GlobalKey(), size: const Size(1920, 1080));
    for (final size in <Size>[
      Size(1920, 1080),
      Size(1536, 864),
      Size(1440, 900),
      Size(1366, 768),
      Size(1280, 720),
      Size(1024, 768),
      Size(390, 844),
      Size(320, 680),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: size.toString());
      if (size.width == 1024) {
        final firstRow = find.byKey(ValueKey(_rows.first['id']! as String));
        expect(tester.getSize(firstRow).width, greaterThan(940));
      }
    }
    await _open(tester, h, 0);
    expect(
        tester
            .getSize(
                find.byKey(const ValueKey('recommendation-details-drawer')))
            .width,
        320);
    expect(tester.takeException(), isNull);
  });

  testWidgets('combines filters, resets them, and reverses Malaysia date order',
      (tester) async {
    final h = await _show(tester, GlobalKey(), size: const Size(1440, 1200));
    Future<void> select(String key, String value) async {
      await tester.tap(find.byKey(ValueKey('monitor-$key')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(value).last);
      await tester.pumpAndSettle();
    }

    await select('source', 'Admin Outreach');
    await select('type', 'Coach');
    await select('status', 'Delivered');
    await tester.enterText(find.byType(TextField), 'Amelia');
    await tester.pumpAndSettle();
    expect(find.text('View Details'), findsOneWidget);
    expect(find.textContaining('7 loaded'), findsOneWidget);
    await tester.tap(find.text('Reset filters'));
    await tester.pumpAndSettle();
    expect(find.text('View Details'), findsNWidgets(7));
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
    await tester.tap(find.text('Created Date · MYT'));
    await tester.pumpAndSettle();
    final oldest = find.text('Historic Fixture Member');
    final newest = find.text(_name);
    expect(
        tester.getTopLeft(oldest).dy, lessThan(tester.getTopLeft(newest).dy));
    expect(h.requests.map((r) => r['operation']), ['admin.queue.list']);
  });

  testWidgets(
      'withheld history remains visible without assigning a false source',
      (tester) async {
    final withheld = canonicalAdminRecord()
      ..remove('suggestion')
      ..addAll({
        'status': 'withdrawn',
        'redacted': true,
        'kind': 'content',
      });
    await _show(tester, GlobalKey(), records: [withheld, _rows[1]]);
    expect(find.text('Withheld').hitTestable(), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('monitor-source')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Automatic').last);
    await tester.pumpAndSettle();
    expect(find.text('View Details'), findsOneWidget);
    expect(find.text('Withheld').hitTestable(), findsNothing);
    expect(find.textContaining('2 loaded'), findsOneWidget);
  });

  testWidgets(
      'a retained inactive page neither opens nor keeps a detail drawer',
      (tester) async {
    final activity = ValueNotifier(true);
    addTearDown(activity.dispose);
    final h = await _show(tester, GlobalKey(), activity: activity);
    h.record = _rows.first;
    final response = Completer<Object?>();
    h.pendingDetail = response;
    await tester.tap(find.text('View Details').first);
    await tester.pump();
    activity.value = false;
    await tester.pump();
    response.complete(h.record);
    await tester.pumpAndSettle();
    final drawer = find.byKey(const ValueKey('recommendation-details-drawer'));
    expect(drawer, findsNothing);
    activity.value = true;
    await tester.pumpAndSettle();
    h.pendingDetail = null;
    await _open(tester, h, 0);
    expect(drawer, findsOneWidget);
    activity.value = false;
    await tester.pumpAndSettle();
    expect(drawer, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'wraps long stored content on a narrow viewport without altering it',
      (tester) async {
    final long = _row('e', 'content', _name, 2);
    final suggestion = long['suggestion']! as Map<String, Object?>;
    final title =
        List.filled(4, 'Full-body movement control tutorial').join(' ');
    final message = List.filled(5, _message).join(' ');
    suggestion['targetLabel'] = title;
    suggestion['summary'] = message;
    final h = await _show(tester, GlobalKey(),
        size: const Size(390, 844), records: [long]);
    h.record = long;
    final button = find.text('View Details');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    final drawer = find.byKey(const ValueKey('recommendation-details-drawer'));
    expect(find.descendant(of: drawer, matching: find.text(title)),
        findsOneWidget);
    expect(find.descendant(of: drawer, matching: find.text(message)),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('captures the overview and four recommendation types',
      (tester) async {
    final key = GlobalKey();
    final h = await _show(tester, key, fonts: true);
    await _save(tester, key, '01-dashboard');
    await tester
        .ensureVisible(find.byKey(const ValueKey('recommendation-table')));
    await tester.pumpAndSettle();
    await _save(tester, key, '02-table');
    await tester.ensureVisible(find.byKey(const ValueKey('monitor-type')));
    await tester.tap(find.byKey(const ValueKey('monitor-type')));
    await tester.pumpAndSettle();
    await _save(tester, key, '03-filters');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    for (final entry in [
      '04-coach',
      '05-tutorial',
      '06-routine',
      '07-rule-fallback'
    ].indexed) {
      await _open(tester, h, entry.$1);
      await _save(tester, key, entry.$2);
      await tester.tap(find.byTooltip('Close details'));
      await tester.pumpAndSettle();
    }
    tester.view.physicalSize = const Size(1024, 768);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Recommendations Overview'));
    await tester.pumpAndSettle();
    await _save(tester, key, '08-responsive');
    expect(tester.takeException(), isNull);
  }, skip: !_capture);
}
