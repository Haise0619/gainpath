import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/workout/application/between_exercise_rest_controller.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/between_exercise_rest_screen.dart';
import 'hybrid_routine_journey_test.dart' show hybridFixture;

void main() {
  testWidgets('render between exercise rest at normal and large text',
      (tester) async {
    Future<void> loadFont(String family, String path) async {
      final loader = FontLoader(family)
        ..addFont(File(path)
            .readAsBytes()
            .then((bytes) => ByteData.sublistView(bytes)));
      await loader.load();
    }

    await tester.runAsync(() async {
      await loadFont('MaterialIcons',
          'C:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
      await loadFont('Barlow', 'assets/fonts/Barlow-Regular.ttf');
    });
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = BetweenExerciseRestController(
        duration: const Duration(seconds: 30),
        monotonicNow: () => Duration.zero,
        canAdvance: () => true,
        onReady: () async {});
    for (final scale in [1.0, 2.0]) {
      tester.view.physicalSize =
          scale == 1 ? const Size(390, 844) : const Size(360, 640);
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
          theme: ThemeData(
              useMaterial3: true,
              fontFamily: 'Barlow',
              colorScheme:
                  ColorScheme.fromSeed(seedColor: const Color(0xff5c19d9))),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  padding: const EdgeInsets.only(bottom: 24)),
              child: child!),
          home: RepaintBoundary(
              key: key,
              child: BetweenExerciseRestScreen(
                  controller: c,
                  previousExercise: 'Squat',
                  upcomingExercise: hybridFixture().exercises[1],
                  organizationId: 'gainpath',
                  onViewRoutine: () {}))));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final directory = Directory('build/between-exercise-rest-preview')
          ..createSync(recursive: true);
        await File('${directory.path}/rest-${scale.toInt()}x.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  }, skip: !const bool.fromEnvironment('GAINPATH_RENDER_REST'));
}
