import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/recommendation/application/canonical_admin_recommendation_repository.dart';
import 'package:gainpath_admin_web/features/recommendation/presentation/admin/admin_recommendation_screens.dart';
import '../../../test_support/fyp_render_support.dart';

/// Captures emulator-delivered fixture records in the production Admin widgets.
/// Authenticated browser acceptance is reported separately.
void main() {
  testWidgets('emulator outreach records render in Admin details', (t) async {
    addTearDown(await installFypOfflineFonts());
    await (FontLoader('Barlow')
          ..addFont(Future.value(ByteData.sublistView(
              File('../mobile/assets/fonts/Barlow-Regular.ttf')
                  .readAsBytesSync()))))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(Future.value(ByteData.sublistView(File(
                  'C:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
              .readAsBytesSync()))))
        .load();
    final raw = jsonDecode(
        File('../../build/module13-admin-ai/emulator-delivered.json')
            .readAsStringSync()) as Map;
    final rows = (raw['records'] as List).cast<Map>();
    expect(rows.length, 3);
    t.view.physicalSize = const Size(1440, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final directory = Directory('../../build/module13-admin-ai/screenshots')
      ..createSync(recursive: true);
    for (final row in rows) {
      final saved = Map<String, Object?>.from(row['saved'] as Map);
      final repository = CanonicalAdminRecommendationRepository(
        organizationId: 'gainpath',
        isCurrent: () => true,
        invoke: (op, data) async {
          if (op == 'admin.queue.list') {
            return {
              'schemaVersion': 1,
              'mode': 'workout_backup',
              'organizationId': 'gainpath',
              'records': [saved],
              'nextAfterId': null,
            };
          }
          if (op == 'admin.queue.detail') return saved;
          throw StateError('Unsupported read in capture');
        },
      );
      final key = GlobalKey();
      await t.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(fontFamily: 'Barlow'),
            home: Scaffold(
                backgroundColor: const Color(0xfffaf7ff),
                body: RiskLeaderboardScreen(canonicalRepository: repository)),
          )));
      await t.pumpAndSettle();
      await t.tap(find.text('View Details'));
      await t.pumpAndSettle();
      expect(find.text('Gemini'), findsWidgets);
      final drawer =
          find.byKey(const ValueKey('recommendation-details-drawer'));
      await t.ensureVisible(
          find.descendant(of: drawer, matching: find.text('Source')));
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('recommendation-details-drawer')),
              matching: find.text('Admin Outreach')),
          findsOneWidget);
      for (final part in ['details', 'ranking']) {
        if (part == 'ranking') {
          await t.ensureVisible(find.text('Recommendation selection'));
          await t.pumpAndSettle();
        }
        expect(t.takeException(), isNull);
        await t.runAsync(() async {
          final image = await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final name =
              'admin-${row['saved']['suggestion']['target']['kind'] as String}-$part.png';
          await File('${directory.path}/$name')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await t.pumpWidget(const SizedBox());
    }
  }, skip: !const bool.fromEnvironment('GAINPATH_RENDER_ADMIN_AI'));
}
