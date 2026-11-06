import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_mobile/features/recommendation/application/recommendation_consent_repository.dart';
import 'package:gainpath_mobile/features/recommendation/presentation/member/personalized_recommendation_settings_screen.dart';
import 'support/recommendation_consent_fixture.dart';

void main() {
  setUpAll(() async {
    for (final family in ['Barlow', 'BarlowCondensed']) {
      final file = File('assets/fonts/$family-Regular.ttf');
      await (FontLoader(family)
            ..addFont(
                Future.value(ByteData.sublistView(await file.readAsBytes()))))
          .load();
    }
    await (FontLoader('MaterialIcons')
          ..addFont(Future.value(ByteData.sublistView(await File(
                  'C:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
              .readAsBytes()))))
        .load();
  });
  for (final name in [
    'preview-375',
    'preview-393',
    'accessible-393',
    'landscape-851',
    'synthetic-granted',
    'grant-confirmation',
    'delivery-scope'
  ]) {
    testWidgets('actual consent widget render $name', (tester) async {
      final landscape = name == 'landscape-851';
      final local = name == 'synthetic-granted' || name == 'grant-confirmation';
      tester.view.physicalSize = Size(
          landscape
              ? 851
              : name == 'preview-375'
                  ? 375
                  : 393,
          landscape ? 393 : 851);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const boundaryKey = ValueKey('consent-render');
      final repository = local
          ? RpcRecommendationConsentRepository(
              scope: consentScope,
              isCurrent: () => true,
              read: (_) async => name == 'synthetic-granted'
                  ? consentWire(revision: 1, granted: true)
                  : null,
              command: (q) async => consentReceipt(q))
          : null;
      await tester.pumpWidget(RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                  useMaterial3: true,
                  fontFamily: 'Barlow',
                  colorScheme: const ColorScheme.light(
                      primary: AppColors.primary,
                      surface: AppColors.surface,
                      onSurface: AppColors.ink),
                  scaffoldBackgroundColor: AppColors.bg),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(
                          name == 'accessible-393' ? 1.6 : 1)),
                  child: child!),
              home: PersonalizedRecommendationSettingsScreen(
                  isCurrent: () => true,
                  repository: repository,
                  notice: local ? consentNotice : null))));
      await tester.pumpAndSettle();
      if (name == 'grant-confirmation') {
        await tester.tap(find.byKey(const ValueKey('exerciseInsights')));
        await tester.pumpAndSettle();
      }
      if (name == 'delivery-scope') {
        await tester.ensureVisible(
            find.byKey(const ValueKey('recommendationDelivery')));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      final boundary =
          tester.renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
      await tester.runAsync(() async {
        final rendered = await boundary.toImage(pixelRatio: 1);
        final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
        final output = File('../../build/module13-e/consent-$name.png');
        await output.parent.create(recursive: true);
        await output.writeAsBytes(bytes!.buffer.asUint8List());
        rendered.dispose();
      });
      await tester.pumpWidget(const SizedBox());
    });
  }
}
