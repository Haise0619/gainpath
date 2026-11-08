import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/app/member_typography_theme.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/pair_chat_screen.dart';
import '../../../test_support/fyp_render_support.dart';
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;
import 'pair_chat_test.dart' show PairChatFake;

void main() {
  setUpAll(() async {
    await loadDemoRenderFonts();
    for (final family in ['Barlow', 'BarlowCondensed']) {
      final loader = FontLoader(family);
      for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
        loader.addFont(Future.value(ByteData.sublistView(
            await File('assets/fonts/$family-$weight.ttf').readAsBytes())));
      }
      await loader.load();
    }
  });
  for (final width in [320.0, 360.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('shared chat render $width $scale', (t) async {
        final restore = await installFypOfflineFonts();
        addTearDown(restore);
        t.view.physicalSize = Size(width, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final key = GlobalKey(), repo = PairChatFake();
        Widget app(Widget home) => RepaintBoundary(
            key: key,
            child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: buildMemberTypographyTheme(),
                builder: (c, child) => MediaQuery(
                    data: MediaQuery.of(c).copyWith(
                        textScaler: memberTextScaler(TextScaler.linear(scale))),
                    child: child!),
                home: home));
        Future<void> capture(String name) async {
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          final boundary =
              t.renderObject<RenderRepaintBoundary>(find.byKey(key));
          await t.runAsync(() async {
            final img = await boundary.toImage();
            final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
                '../../build/pair-chat-20261108/renders/$name-${width.toInt()}-${scale.toInt()}x.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            img.dispose();
          });
        }

        await t.pumpWidget(app(PairChatScreen(
            repository: repo,
            isCurrent: () => true,
            ownRole: 'member',
            bookingId: 'b')));
        await capture('member');
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(app(PairChatScreen(
            repository: repo,
            isCurrent: () => true,
            ownRole: 'coach',
            bookingId: 'b')));
        await capture('coach');
        await t.pumpWidget(const SizedBox());
        repo.writable = false;
        await t.pumpWidget(app(PairChatScreen(
            repository: repo,
            isCurrent: () => true,
            ownRole: 'member',
            bookingId: 'b',
            onBookAgain: (_) {})));
        await capture('readonly');
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(app(PairChatInboxScreen(
            repository: repo, isCurrent: () => true, ownRole: 'member')));
        await capture('inbox');
        await t.pumpWidget(const SizedBox());
      });
    }
  }
}
