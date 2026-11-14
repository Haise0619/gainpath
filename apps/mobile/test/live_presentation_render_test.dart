import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/app/member_typography_theme.dart';
import 'package:gainpath_mobile/features/recommendation/application/member_recommendation_repository.dart';
import 'package:gainpath_mobile/features/recommendation/presentation/member/member_recommendation_sheet.dart';
import 'package:gainpath_mobile/features/recommendation/presentation/member/member_recommendations_view.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_demo_recommendation.dart';
import '../../../test_support/live_presentation_bridge.dart';
import '../../../test_support/fyp_render_support.dart';
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;

void main() {
  testWidgets('live Firebase Member recommendation presentation', (t) async {
    await t.runAsync(loadDemoRenderFonts);
    addTearDown(await installFypOfflineFonts());
    final bridge = LivePresentationBridge('member');
    final repos = FirebaseDemoMemberRepositories(bridge.transport);
    final records = <MemberRecommendationDetail>[];
    await t.runAsync(() async {
      final inbox = await repos.inbox.loadInbox();
      for (final notice in inbox.records) {
        final reference = notice.recommendation;
        if (reference == null) continue;
        final detail =
            await repos.recommendation.get(reference.recommendationId);
        if (detail.deliveredAt != null && detail.available) records.add(detail);
      }
    });
    expect(bridge.failures, isEmpty);
    expect(records, isNotEmpty,
        reason:
            'Live delivered recommendation records required; no fixtures allowed.');
    final dir =
        Directory('../../build/module13-presentation/live-renders/member')
          ..createSync(recursive: true);
    File('${dir.path}/evidence.json').writeAsStringSync(
        '{"actualDeliveredRows":${records.length},"readRequests":${bridge.requests}}');
    for (final width in [320.0, 360.0, 390.0]) {
      for (final scale in [1.0, 2.0]) {
        for (final stage in [
          'feed',
          ...records.map((r) => r.recommendationId)
        ]) {
          t.view.physicalSize = Size(width, 844);
          t.view.devicePixelRatio = 1;
          final key = GlobalKey();
          final body = stage == 'feed'
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: MemberRecommendationsView(
                      repository: repos.recommendation,
                      isCurrent: () => true,
                      loadPage: (
                              {required bool history, String? afterId}) async =>
                          MemberRecommendationPage(records: records),
                      onOpenTarget: (_, __) async {}))
              : MemberRecommendationSheet(
                  recommendationId: stage,
                  repository: repos.recommendation,
                  isCurrent: () => true,
                  onOpenTarget: (_, __) async {});
          await t.pumpWidget(RepaintBoundary(
              key: key,
              child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: buildMemberTypographyTheme(),
                  builder: (c, child) => MediaQuery(
                      data: MediaQuery.of(c).copyWith(
                          textScaler:
                              memberTextScaler(TextScaler.linear(scale))),
                      child: child!),
                  home: Scaffold(body: SafeArea(child: body)))));
          for (var attempt = 0; attempt < 120; attempt++) {
            await t.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 100)));
            await t.pump(const Duration(milliseconds: 100));
            if (bridge.pending == 0 && attempt > 2) break;
          }
          await t.pumpAndSettle();
          expect(bridge.failures, isEmpty);
          expect(t.takeException(), isNull);
          expect(
              find.text(
                  'Could not open this recommendation. Please try again.'),
              findsNothing);
          var part = 0;
          final scroll =
              t.state<ScrollableState>(find.byType(Scrollable).first);
          while (true) {
            await t.runAsync(() async {
              final image = await (key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
              final bytes =
                  await image.toByteData(format: ui.ImageByteFormat.png);
              await File(
                      '${dir.path}/$stage-${width.toInt()}-${(scale * 100).round()}-$part.png')
                  .writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
            if (scroll.position.pixels >= scroll.position.maxScrollExtent) {
              break;
            }
            scroll.position.jumpTo((scroll.position.pixels + 600)
                .clamp(0, scroll.position.maxScrollExtent));
            await t.pumpAndSettle();
            part++;
          }
          await t.pumpWidget(const SizedBox());
        }
      }
    }
    t.view.reset();
  },
      skip: !const bool.fromEnvironment('GAINPATH_RENDER_LIVE_PRESENTATION'),
      timeout: const Timeout(Duration(minutes: 5)));
}
