import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_mobile/app/notifications/member_notifications_screen.dart';
import 'package:gainpath_mobile/app/member_typography_theme.dart';
import 'package:gainpath_mobile/features/recommendation/application/member_recommendation_repository.dart';
import 'package:gainpath_mobile/features/recommendation/presentation/member/member_recommendations_view.dart';
import 'package:gainpath_mobile/features/recommendation/presentation/member/member_recommendation_sheet.dart';
import '../../../test_support/fyp_render_support.dart';
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;

/// Actual local Emulator delivery outputs; inference uses explicitly labeled fixtures.
void main() {
  testWidgets(
      'emulator outreach deliveries render in existing Member cards and details',
      (t) async {
    addTearDown(await installFypOfflineFonts());
    await t.runAsync(loadDemoRenderFonts);
    final raw = jsonDecode(
        File('../../build/module13-admin-ai/emulator-delivered.json')
            .readAsStringSync()) as Map;
    final records = (raw['records'] as List).cast<Map>();
    expect(records.length, 3);
    final repository = RpcMemberRecommendationRepository(
        scope: SessionScope(userId: 'learner', organizationId: 'gainpath'),
        isCurrent: () => true,
        fixtureOnly: false,
        invoke: (q) async => records
            .firstWhere((r) => r['id'] == q['recommendationId'])['resolved']);
    t.view.physicalSize = const Size(390, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    for (final row in records) {
      final detail = MemberRecommendationDetail.parse(
          Map<String, Object?>.from(row['resolved'] as Map),
          'gainpath',
          row['id'] as String);
      for (final details in [false, true]) {
        final key = GlobalKey();
        await t.pumpWidget(RepaintBoundary(
            key: key,
            child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: buildMemberTypographyTheme(),
                home: Scaffold(
                    appBar: AppBar(
                        title: const Text('Outreach · Emulator fixture')),
                    body: details
                        ? MemberRecommendationSheet(
                            recommendationId: detail.recommendationId,
                            repository: repository,
                            isCurrent: () => true,
                            onOpenTarget: (_, __) async {})
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: RecommendationCard(
                                detail: detail,
                                onOpen: () {},
                                onDetails: () {}))))));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.runAsync(() async {
          final image = await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final f = File(
              '../../build/module13-admin-ai/screenshots/member-${detail.kind.name}-${details ? 'details' : 'card'}.png');
          f.parent.createSync(recursive: true);
          f.writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
    final items = <UnifiedNotificationItem>[];
    for (final n in raw['notifications'] as List) {
      final row = records.firstWhere((r) => r['id'] == n['recommendationId']);
      final detail = MemberRecommendationDetail.parse(
          Map<String, Object?>.from(row['resolved'] as Map),
          'gainpath',
          row['id'] as String);
      items.add(UnifiedNotificationItem(
          id: n['id'],
          category: NotificationCategoryFilter.recommendations,
          title: n['title'],
          message: n['message'],
          timestamp: DateTime.fromMillisecondsSinceEpoch(n['createdAtMillis']),
          isRead: n['read'],
          recommendation: RecommendationNotice(
              recommendationId: detail.recommendationId,
              kind: detail.kind,
              state: detail.state,
              expiresAt: detail.expiresAt,
              target: detail.target)));
    }
    final key = GlobalKey();
    await t.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildMemberTypographyTheme(),
            home: MemberNotificationsScreen(
                isCurrent: () => true,
                initialItems: items,
                recommendationRepository: repository))));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.runAsync(() async {
      final image = await (key.currentContext!.findRenderObject()
              as RenderRepaintBoundary)
          .toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('../../build/module13-admin-ai/screenshots/member-inbox.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await t.tap(find.text(items.first.title).first);
    await t.pumpAndSettle();
    expect(find.byType(MemberRecommendationSheet), findsOneWidget);
  }, skip: !const bool.fromEnvironment('GAINPATH_RENDER_ADMIN_AI'));
}
