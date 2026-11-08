import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_data/gainpath_data.dart' show InMemoryAuthRepository;
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_mobile/features/identity/presentation/coach/coach_account_screen.dart';
import 'coach_profile_data_preview_test.dart'
    show MetricsAccount, PublishedProfileFake;
import 'coach_shared_account_test.dart' show draft;
import '../../../test_support/fyp_render_support.dart';
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;

void main() {
  setUpAll(loadDemoRenderFonts);
  for (final width in [320.0, 360.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
          'Coach original preview and visible labels render $width $scale',
          (t) async {
        final restore = await installFypOfflineFonts();
        addTearDown(restore);
        t.view.physicalSize = Size(width, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final key = GlobalKey();
        await t.pumpWidget(RepaintBoundary(
            key: key,
            child: BlocProvider(
                create: (_) => AuthBloc(repository: InMemoryAuthRepository()),
                child: MaterialApp(
                    debugShowCheckedModeBanner: false,
                    theme: AppTheme.build(),
                    builder: (c, child) => MediaQuery(
                        data: MediaQuery.of(c)
                            .copyWith(textScaler: TextScaler.linear(scale)),
                        child: child!),
                    home: CoachAccountScreen(
                        profileRepository: PublishedProfileFake()
                          ..profile = draft(),
                        accountRepository: MetricsAccount())))));
        await t.pumpAndSettle();
        Future<void> capture(String label) async {
          expect(t.takeException(), isNull);
          final boundary =
              t.renderObject<RenderRepaintBoundary>(find.byKey(key));
          await t.runAsync(() async {
            final img = await boundary.toImage();
            final data = await img.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
                '../../build/coach-preview-restore-20261108/renders/$label-${width.toInt()}-${scale.toInt()}x.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(data!.buffer.asUint8List());
            img.dispose();
          });
        }

        await capture('profile');
        await t.scrollUntilVisible(find.text('Preview public profile'), 150);
        await Scrollable.ensureVisible(
            t.element(find.text('Preview public profile')),
            alignment: 0.5);
        await t.pumpAndSettle();
        await t.tap(find.text('Preview public profile'));
        await t.pumpAndSettle();
        await capture('preview');
        await t.pumpWidget(const SizedBox());
      });
    }
  }
}
