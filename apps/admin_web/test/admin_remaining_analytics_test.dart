import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:gainpath_admin_web/features/analytics/application/admin_observed_activity.dart';
import 'package:gainpath_admin_web/features/analytics/application/admin_check_in_reporting.dart';
import 'package:gainpath_admin_web/features/analytics/application/admin_workout_reporting.dart';
import 'package:gainpath_admin_web/features/analytics/presentation/admin/admin_remaining_analytics.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_admin_check_in_report.dart';
import 'admin_original_reporting_layout_test.dart' as original;
import 'admin_workout_reporting_ui_test.dart' as workouts;
import 'admin_check_in_reporting_test.dart' as fixture;
import 'firebase_admin_reporting_test.dart' as support;

Map<String, Object?> observations() => {
      'schemaVersion': 1,
      'asOfMillis': support.reportingQuery.range.end.millisecondsSinceEpoch - 1,
      'cohortMembers': 4,
      'sourceCounts': {
        'checkIns': 2,
        'bookings': 1,
        'games': 0,
        'workoutBackups': 1
      },
      'daily': [
        {
          'date': '2026-10-25',
          'checkIns': 2,
          'bookings': 1,
          'games': 0,
          'workoutBackups': 1,
          'uniqueMembers': 2
        }
      ],
      'weekly': [
        {
          'date': '2026-10-20',
          'checkIns': 2,
          'bookings': 1,
          'games': 0,
          'workoutBackups': 1,
          'uniqueMembers': 2
        }
      ],
      'recency': {
        'within7Days': 2,
        'days8To30': 0,
        'over30Days': 0,
        'noObservedActivity': 2
      },
      'returning': {
        'available': true,
        'previousMembers': 2,
        'currentMembers': 2,
        'returningMembers': 1,
        'ratePercent': 50.0
      }
    };
Map<String, Object?> valid() {
  final o = observations();
  (o['weekly'] as List).first['date'] = '2026-10-19';
  return o;
}

class Gateway extends workouts.WorkoutUiGateway
    implements AdminCheckInReportingGateway {
  @override
  Future<AdminCheckInReport> loadCheckIns(q) async {
    final raw = fixture.checkInResponse();
    raw['observations'] = valid();
    return parseAdminCheckInReport(raw, support.reportingScope, q);
  }

  @override
  Future<AdminWorkoutReport> loadWorkouts(q) async {
    final r = await super.loadWorkouts(q);
    final f = r.forms.first;
    return AdminWorkoutReport(
        query: r.query,
        capturedAt: r.capturedAt,
        scanStartedAt: r.scanStartedAt,
        totals: r.totals,
        coverage: r.coverage,
        daily: r.daily,
        exercises: r.exercises,
        forms: [
          WorkoutFormGroup(
              exerciseId: f.exerciseId,
              scoringVersion: '=unsafe',
              detectorId: f.detectorId,
              detectorVersion: f.detectorVersion,
              cameraView: f.cameraView,
              armMode: f.armMode,
              scoredSessions: 2,
              scoreSum: 150,
              daily: [
                const WorkoutFormDay('2020-01-01', 1, 70),
                const WorkoutFormDay('2026-10-25', 1, 80)
              ])
        ]);
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  test(
      'observed validation and filtered CSV preserve source separation and return denominator',
      () {
    final r = AdminObservedActivity.parse(valid(), support.reportingQuery,
        DateTime.utc(2026, 10, 26, 6).millisecondsSinceEpoch);
    expect(r.cohort, 4);
    expect(r.recency['noObservedActivity'], 2);
    expect(r.returning['ratePercent'], 50);
    expect(r.csv(retention: false, weeklyView: true).expand((r) => r),
        contains('2026-10-19'));
    expect(r.csv(retention: true, weeklyView: false).expand((r) => r),
        contains('Return rate %'));
  });
  test('rejects malformed cohort, false return rate and mixed source totals',
      () {
    for (final change in [0, 1, 2]) {
      final m = valid();
      if (change == 0) (m['recency'] as Map)['within7Days'] = 9;
      if (change == 1) (m['returning'] as Map)['ratePercent'] = 99;
      if (change == 2) (m['sourceCounts'] as Map)['bookings'] = 8;
      expect(
          () => AdminObservedActivity.parse(m, support.reportingQuery,
              DateTime.utc(2026, 10, 26, 6).millisecondsSinceEpoch),
          throwsFormatException);
    }
  });
  test(
      'rejects wrong observation cutoff, period dates and comparison availability',
      () {
    for (final kind in ['cutoff', 'date', 'availability', 'unique']) {
      final m = valid();
      if (kind == 'cutoff') {
        m['asOfMillis'] = (m['asOfMillis'] as int) - 1;
      }
      if (kind == 'date') {
        ((m['daily'] as List).first as Map)['date'] = '2000-01-01';
      }
      if (kind == 'availability') {
        (m['returning'] as Map)['available'] = false;
      }
      if (kind == 'unique') {
        ((m['daily'] as List).first as Map)['uniqueMembers'] = 5;
      }
      expect(
          () => AdminObservedActivity.parse(m, support.reportingQuery,
              DateTime.utc(2026, 10, 26, 6).millisecondsSinceEpoch),
          throwsFormatException);
    }
  });
  test('no denominator yields unavailable rate rather than zero', () {
    final m = valid();
    m['returning'] = {
      'available': true,
      'previousMembers': 0,
      'currentMembers': 2,
      'returningMembers': 0,
      'ratePercent': null
    };
    final r = AdminObservedActivity.parse(m, support.reportingQuery,
        DateTime.utc(2026, 10, 26, 6).millisecondsSinceEpoch);
    expect(r.returning['ratePercent'], isNull);
  });
  testWidgets(
      'posture DateTime chart preserves long missing-score gap and safe scoped CSV',
      (t) async {
    await t.pumpWidget(original.originalLayoutApp(
        Scaffold(
            body: SingleChildScrollView(
                child: AdminPostureSection(
                    query: support.reportingQuery, anchorKey: GlobalKey()))),
        Gateway()));
    await t.pumpAndSettle();
    expect(find.text('Estimated Form Score Trend'), findsOneWidget);
    final chart = t.widget<SfCartesianChart>(find.byType(SfCartesianChart));
    expect(chart.primaryXAxis, isA<DateTimeAxis>());
    final series = chart.series.single;
    expect(series.dataSource!.length, 3);
    final section = t.widget<ReportSection>(find.byType(ReportSection));
    final rows = section.exportRows!();
    expect(
        rows
            .expand((r) => r)
            .whereType<String>()
            .any((v) => v.contains('=unsafe')),
        true);
    final data =
        rows.where((r) => r.length == 3 && r.first == '2020-01-02').single;
    expect(data[1], isNull);
    expect(data[2], 0);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'observed report supports weekly CSV and unknown recency without prediction',
      (t) async {
    await t.pumpWidget(original.originalLayoutApp(
        Scaffold(
            body: SingleChildScrollView(
                child: AdminObservedSection(
                    query: support.reportingQuery, anchorKey: GlobalKey()))),
        Gateway()));
    await t.pumpAndSettle();
    expect(find.text('Platform Usage Pattern'), findsOneWidget);
    await t.tap(find.text('Weekly'));
    await t.pumpAndSettle();
    final s = t.widget<ReportSection>(find.byType(ReportSection));
    expect(s.exportRows!().expand((r) => r), contains('2026-10-19'));
    expect(t.takeException(), isNull);
  });
  testWidgets('recency 320px large text remains readable', (t) async {
    t.view.physicalSize = const Size(320, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(original.originalLayoutApp(
        MediaQuery(
            data: const MediaQueryData(
                size: Size(320, 900), textScaler: TextScaler.linear(2)),
            child: Scaffold(
                body: SingleChildScrollView(
                    child: AdminObservedSection(
                        query: support.reportingQuery,
                        anchorKey: GlobalKey(),
                        retention: true)))),
        Gateway()));
    await t.pumpAndSettle();
    expect(find.text('No observed activity / unknown'), findsWidgets);
    expect(t.takeException(), isNull);
  });
}
