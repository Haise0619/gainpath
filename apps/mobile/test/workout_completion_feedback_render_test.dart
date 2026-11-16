import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_mobile/app/member_typography_theme.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/widgets/workout_completion_feedback.dart';
import '../../../test_support/fyp_render_support.dart'
    show installFypOfflineFonts;

void main() {
  testWidgets(
      'render completion motion, long names, landscape and reduced motion',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final restore = await tester.runAsync(installFypOfflineFonts);
    addTearDown(restore!);
    await tester.runAsync(() async {
      for (final entry in {
        'MaterialIcons':
            'C:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        'Barlow': 'assets/fonts/Barlow-Regular.ttf',
        'Ahem': 'assets/fonts/Barlow-Regular.ttf',
        'BarlowCondensed': 'assets/fonts/BarlowCondensed-Regular.ttf',
      }.entries) {
        await (FontLoader(entry.key)
              ..addFont(
                  File(entry.value).readAsBytes().then(ByteData.sublistView)))
            .load();
      }
    });
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    final directory = Directory('build/workout-completion-feedback')
      ..createSync(recursive: true);
    for (final spec in [
      (360.0, 800.0, 1.0, false),
      (320.0, 568.0, 2.0, false),
      (800.0, 400.0, 1.0, false),
      (390.0, 844.0, 1.0, true)
    ]) {
      tester.view.physicalSize = Size(spec.$1, spec.$2);
      await tester.pumpWidget(MaterialApp(
          theme: buildMemberTypographyTheme(),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(spec.$3),
                  disableAnimations: spec.$4),
              child: child!),
          home: RepaintBoundary(
              key: key,
              child: Scaffold(
                  body: WorkoutCompletionFeedback(
                      exerciseName: spec.$3 == 2
                          ? 'Standing Single Arm Dumbbell Curl — controlled movement and full range'
                          : 'Dumbbell Shoulder Press',
                      workoutComplete: true)))));
      for (final phase in ['enter', 'complete']) {
        await tester
            .pump(Duration(milliseconds: phase == 'enter' ? 160 : 1100));
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
                  '${directory.path}/${spec.$1.toInt()}-${spec.$3}-${spec.$4}-$phase.png')
              .writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
    await tester.pumpWidget(const SizedBox());
  });
}
