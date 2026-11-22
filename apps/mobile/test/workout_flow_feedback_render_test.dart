import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_mobile/app/member_typography_theme.dart';
import 'package:gainpath_mobile/features/workout/application/between_exercise_rest_controller.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/between_exercise_rest_screen.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/real_workout_view.dart';
import 'support/workout_visual_feedback_fixture.dart';
import 'workout_flow_visual_feedback_test.dart' show nextExercise;
import '../../../test_support/fyp_render_support.dart'
    show installFypOfflineFonts;

void main() {
  testWidgets(
      'render actual rest and tracking pages across sizes and animation phases',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final restoreFonts = await tester.runAsync(installFypOfflineFonts);
    addTearDown(restoreFonts!);
    Future<void> font(String family, String path) async {
      final loader = FontLoader(family)
        ..addFont(File(path).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }

    await tester.runAsync(() async {
      await font('MaterialIcons',
          'C:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
      await font('Barlow', 'assets/fonts/Barlow-Regular.ttf');
      // Flutter tester uses Ahem for styles that inherit the platform font.
      await font('Ahem', 'assets/fonts/Barlow-Regular.ttf');
      await font('BarlowCondensed', 'assets/fonts/BarlowCondensed-Regular.ttf');
    });
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    final assets = _LocalRenderAssets();
    await tester.runAsync(() async {
      final bytes = await File(nextExercise.imageUrl).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final assetKey = await AssetImage(nextExercise.imageUrl, bundle: assets)
          .obtainKey(ImageConfiguration(bundle: assets));
      PaintingBinding.instance.imageCache.putIfAbsent(
          assetKey,
          () => OneFrameImageStreamCompleter(
              Future.value(ImageInfo(image: frame.image))));
      codec.dispose();
    });
    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final dir = Directory('build/workout-flow-feedback')
          ..createSync(recursive: true);
        await File('${dir.path}/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
    }

    Widget app(Widget child, double scale) => MaterialApp(
        theme: buildMemberTypographyTheme(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                padding: const EdgeInsets.only(top: 24, bottom: 24)),
            child: DefaultAssetBundle(bundle: assets, child: child!)),
        home: RepaintBoundary(key: key, child: child));
    for (final (size, scale, name) in [
      (const Size(390, 844), 1.0, 'portrait'),
      (const Size(320, 640), 2.0, 'small-large-text'),
      (const Size(844, 390), 1.0, 'landscape'),
    ]) {
      tester.view.physicalSize = size;
      var now = Duration.zero;
      final c = BetweenExerciseRestController(
          duration: const Duration(seconds: 30),
          monotonicNow: () => now,
          canAdvance: () => true,
          onReady: () async {});
      await tester.pumpWidget(app(
          BetweenExerciseRestScreen(
              controller: c,
              previousExercise: 'Burpee',
              upcomingExercise: nextExercise,
              organizationId: 'gainpath',
              onViewRoutine: () {}),
          scale));
      await tester.pumpAndSettle();
      now = const Duration(seconds: 7);
      await c.tick();
      await tester.pumpAndSettle();
      await capture('rest-$name');
      if (scale == 2) {
        await tester.drag(
            find.byType(SingleChildScrollView).first, const Offset(0, -460));
        await tester.pumpAndSettle();
        await capture('rest-$name-scrolled');
      }
      if (name == 'portrait') {
        now = const Duration(seconds: 28);
        await c.tick();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 325));
        await capture('rest-final-pulse');
      }
      await tester.pumpWidget(const SizedBox());
      c.dispose();

      final session = VisualFeedbackSession();
      await session.start(consented: true, setupConfirmed: true);
      await tester.pumpWidget(app(
          RealWorkoutView(
              session: session,
              viewport: const DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [Color(0xFF342449), Color(0xFF151220)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight))),
              exerciseName: 'Bodyweight squat',
              targetRepetitions: 8),
          scale));
      session.update();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));
      await capture('tracking-ready-$name');
      await tester.pumpAndSettle();
      session.update(reps: 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));
      await capture('tracking-rep-$name');
      await tester.pumpAndSettle();
      await capture('tracking-clear-$name');
      await tester.pumpWidget(const SizedBox());
      await session.close();
      session.dispose();
    }
  }, skip: !const bool.fromEnvironment('GAINPATH_RENDER_FLOW'));
}

/// Offline font interception bypasses the usual test asset handler. Read the
/// real bundled images/manifest locally so visual QA also verifies decoding.
class _LocalRenderAssets extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(await File(
          key.startsWith('assets/') ? key : 'build/unit_test_assets/$key')
      .readAsBytes());
}
