import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/app/member_typography_theme.dart';
import 'package:gainpath_mobile/features/recommendation/application/member_recommendation_repository.dart';
import 'package:gainpath_mobile/features/recommendation/presentation/member/member_recommendation_sheet.dart';
import 'package:gainpath_mobile/features/recommendation/presentation/member/member_recommendations_view.dart';
import '../../../test_support/fyp_render_support.dart';
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;
import 'member_recommendation_repository_test.dart' show memberDetail;

void main() {
  testWidgets('member recommendation actual renders', (t) async {
    await t.runAsync(loadDemoRenderFonts);
    addTearDown(await installFypOfflineFonts());
    final dir = Directory(
        '../../build/module13-consumer/member-${const String.fromEnvironment('M13_RENDER_PHASE', defaultValue: 'after')}')
      ..createSync(recursive: true);
    for (final width in [320.0, 360.0, 390.0]) {
      for (final scale in [1.0, 2.0]) {
        for (final stage in ['detail', 'feed', 'empty', 'content']) {
          t.view.physicalSize = Size(width, 844);
          t.view.devicePixelRatio = 1;
          final key = GlobalKey();
          final raw = memberDetail();
          if (stage == 'content') {
            raw.addAll({
              'kind': 'content',
              'title': 'Exercise technique guide',
              'targetLabel': 'Biceps Curl foundations',
              'exerciseLabel': 'Biceps Curl',
              'summary':
                  'Explore a guide matched to your recent assessed sessions.',
              'explanations': [
                'This guide offers practice for your assessed Biceps Curl sessions.'
              ],
              'target': {
                'kind': 'content',
                'destination': {
                  'kind': 'published_routine_exercise_tutorial',
                  'organizationId': 'gym1',
                  'routineId': 'routine1',
                  'exerciseId': 'curl',
                  'exerciseIndex': 0,
                  'dayNumber': 1
                }
              }
            });
          }
          final repo = RpcMemberRecommendationRepository(
              scope: SessionScope(userId: 'm1', organizationId: 'gym1'),
              isCurrent: () => true,
              invoke: (q) async => raw);
          final detail = MemberRecommendationDetail.parse(raw, 'gym1', 'r1');
          final Widget body = stage == 'detail'
              ? MemberRecommendationSheet(
                  recommendationId: 'r1',
                  repository: repo,
                  isCurrent: () => true,
                  onOpenTarget: (_, __) async {})
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: MemberRecommendationsView(
                      repository: repo,
                      isCurrent: () => true,
                      compact: true,
                      loadPage: (
                              {required bool history, String? afterId}) async =>
                          MemberRecommendationPage(
                              records: stage == 'empty' ? [] : [detail]),
                      onOpenTarget: (_, __) async {},
                      onViewAll: () {},
                      onSettings: () {}));
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
          await t.pumpAndSettle();
          var part = 0;
          final scroll =
              t.state<ScrollableState>(find.byType(Scrollable).first);
          while (true) {
            expect(t.takeException(), isNull, reason: '$stage $width $scale');
            await t.runAsync(() async {
              final rendered = await (key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
              final data =
                  await rendered.toByteData(format: ui.ImageByteFormat.png);
              await File(
                      '${dir.path}/$stage-${width.toInt()}-${(scale * 100).round()}-$part.png')
                  .writeAsBytes(data!.buffer.asUint8List());
              rendered.dispose();
            });
            if (scroll.position.pixels >= scroll.position.maxScrollExtent) {
              break;
            }
            scroll.position.jumpTo((scroll.position.pixels + 450)
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
      skip: !const bool.fromEnvironment(
          'GAINPATH_RENDER_MEMBER_RECOMMENDATIONS'));
}
