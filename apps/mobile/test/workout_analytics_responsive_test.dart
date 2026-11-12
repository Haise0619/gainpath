import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_mobile/features/analytics/presentation/shared/progress_dashboard_screen.dart';
import 'package:gainpath_mobile/features/analytics/presentation/member/workout_report_screen.dart';
import 'package:gainpath_mobile/features/analytics/presentation/member/workout_performance_screen.dart';
import 'package:gainpath_mobile/features/analytics/presentation/member/posture_accuracy_screen.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_attempt.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/routine_history_screen.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_result_screen.dart';
import 'support/workout_analytics_fixture.dart';
import 'workout_report_ui_test.dart' show ReportExporterFake;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      for (final landscape in [false, true]) {
        testWidgets('analytics ${width}dp scale $scale landscape $landscape',
            (tester) async {
          tester.view.physicalSize =
              landscape ? Size(844, width) : Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final f = WorkoutAnalyticsFixture();
          final progress = calculateLocalMemberProgress(
              scope: f.scope, records: f.snapshot.records, asOf: f.now);
          final routines = RoutineProgress(
              scope: f.scope, attempts: [f.attempt], asOf: f.now);
          final screens = <String, Widget>{
            'summary': RoutineAttemptDetailScreen(
                attempt: f.attempt, summaries: f.summaries, onRepeat: () {}),
            'exercise':
                WorkoutResultScreen.measured(summary: f.summaries.first),
            'history': RoutineHistoryScreen(
                attempts: [f.attempt], asOf: f.now, onOpenAttempt: (_) {}),
            'progress': ProgressDashboardScreen(
                localProgress: progress,
                routineProgress: routines,
                onStartWorkout: () {},
                onOpenPerformance: () {}),
            'report': WorkoutReportScreen(
                scope: f.scope,
                source: f.snapshot,
                asOf: f.now,
                exporter: ReportExporterFake(),
                isCurrent: () => true,
                onRefresh: () async {}),
            'trends': WorkoutPerformanceScreen(
                localProgress: progress, routineProgress: routines),
            'form': PostureAccuracyScreen(
                localProgress: progress, routineProgress: routines),
          };
          for (final screen in screens.entries) {
            await tester.pumpWidget(MaterialApp(
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(scale),
                        disableAnimations: true),
                    child: child!),
                home: screen.value));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull,
                reason: '${screen.key} initial');
            await tester.drag(
                find.byType(Scrollable).first, const Offset(0, -1600));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull,
                reason: '${screen.key} scrolled');
          }
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
}
