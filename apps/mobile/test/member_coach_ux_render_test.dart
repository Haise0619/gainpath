import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/app/member_typography_theme.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/browse_coaches_screen.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/coach_profile_screen.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/published_coach_presentation.dart';
import '../../../test_support/fyp_render_support.dart';
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;
import 'member_coach_ux_test.dart' show coachProfile, MemberDirectoryFake;

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
      for (final dark in [false, true]) {
        testWidgets('member coach render $width $scale dark=$dark',
            (tester) async {
          final restore = await installFypOfflineFonts();
          addTearDown(restore);
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final key = GlobalKey();
          final base = dark
              ? ThemeData(
                  useMaterial3: true,
                  colorScheme: ColorScheme.fromSeed(
                      seedColor: const Color(0xff6d28d9),
                      brightness: Brightness.dark),
                  fontFamily: 'Barlow')
              : buildMemberTypographyTheme();
          final theme = base;
          Widget page(Widget child) => RepaintBoundary(
              key: key,
              child: MaterialApp(
                  theme: theme,
                  debugShowCheckedModeBanner: false,
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                          textScaler:
                              memberTextScaler(TextScaler.linear(scale))),
                      child: child!),
                  home: child));
          Future<void> capture(String kind) async {
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final boundary =
                tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
            await tester.runAsync(() async {
              final image = await boundary.toImage();
              final bytes =
                  await image.toByteData(format: ui.ImageByteFormat.png);
              final file = File(
                  '../../build/member-coach-ux-20261108/renders/$kind-${width.toInt()}-${scale.toInt()}x-${dark ? 'dark' : 'light'}.png');
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }

          final p = coachProfile(name: 'Jackson Alexander');
          await tester.pumpWidget(page(CoachProfileScreen(
              coach: publishedCoachPresentation(p),
              published: p,
              photo: const Icon(Icons.person_outline, size: 48),
              onOpenBooking: () {},
              onOpenSchedule: () {})));
          await capture('profile');
          expect(find.text('Book a session').hitTestable(), findsOneWidget);
          await tester.drag(
              find.byType(Scrollable).first, const Offset(0, -1800));
          await capture('profile-details');
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(page(BrowseCoachesScreen(
              live: true,
              liveRepository: MemberDirectoryFake(),
              isCurrent: () => true,
              onOpenBookings: () {},
              onOpenPublished: (_) {})));
          await capture('directory');
        });
      }
    }
  }
}
