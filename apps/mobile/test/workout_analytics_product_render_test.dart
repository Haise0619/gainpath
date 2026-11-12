import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_mobile/features/analytics/presentation/shared/progress_dashboard_screen.dart';
import 'package:gainpath_mobile/features/analytics/presentation/member/workout_report_screen.dart';
import 'package:gainpath_mobile/features/analytics/domain/local_member_progress_repository.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_attempt.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_backup.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/widgets/workout_save_indicator.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/routine_history_screen.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_backup_screen.dart';
import 'member_workout_report_test.dart' as reports;
import 'routine_history_ui_test.dart' as fixture;
import 'workout_report_ui_test.dart' show ReportExporterFake;

void main() {
  testWidgets('render analytics product screens', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.runAsync(() async {
      for (final font in ['Barlow', 'MaterialIcons']) {
        final loader = FontLoader(font);
        loader.addFont(File(font == 'Barlow'
                ? 'assets/fonts/Barlow-Regular.ttf'
                : 'C:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
            .readAsBytes()
            .then(ByteData.sublistView));
        await loader.load();
      }
    });
    final attempt = fixture.attempt();
    final record = reports.reportRecord('camera', reports.reportNow,
        exercise: attempt.routine.exercises.first.exerciseId);
    final progress = calculateLocalMemberProgress(
        scope: reports.reportScope, records: [record], asOf: reports.reportNow);
    final routines = RoutineProgress(
        scope: reports.reportScope,
        attempts: [attempt],
        asOf: reports.reportNow);
    final screens = <String, Widget>{
      'history':
          RoutineHistoryScreen(attempts: [attempt], onOpenAttempt: (_) {}),
      'summary': RoutineAttemptDetailScreen(attempt: attempt),
      'progress': ProgressDashboardScreen(
          localProgress: progress,
          routineProgress: routines,
          onOpenPerformance: () {},
          onOpenHistory: () {}),
      'report': WorkoutReportScreen(
          scope: reports.reportScope,
          source: LocalMemberProgressSnapshot(
              records: [record],
              attempts: [attempt],
              routineHistoryAvailable: true),
          asOf: reports.reportNow,
          exporter: ReportExporterFake(),
          isCurrent: () => true,
          onRefresh: () async {}),
      'sync': const String.fromEnvironment('ANALYTICS_STAGE', defaultValue: 'before') == 'before'
          ? const WorkoutBackupScreen()
          : const Scaffold(body: SafeArea(child: Padding(padding: EdgeInsets.all(24),
              child: WorkoutSaveIndicator(status: BackupRecordStatus.backedUp)))),
    };
    final directory = Directory('build/workout-analytics-product');
    directory.createSync(recursive: true);
    for (final entry in screens.entries) {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
          theme: ThemeData(
              useMaterial3: true,
              fontFamily: 'Barlow',
              scaffoldBackgroundColor: const Color(0xfffaf8ff),
              colorScheme:
                  ColorScheme.fromSeed(seedColor: const Color(0xff6d28d9))),
          home: RepaintBoundary(key: key, child: entry.value)));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final stage = const String.fromEnvironment('ANALYTICS_STAGE',
            defaultValue: 'before');
        await File('${directory.path}/$stage-${entry.key}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    tester.view.reset();
  }, skip: !const bool.fromEnvironment('GAINPATH_RENDER_ANALYTICS'));
}
