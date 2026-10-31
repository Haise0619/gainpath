import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/analytics/application/admin_workout_reporting.dart';
import 'package:gainpath_admin_web/features/analytics/application/admin_reporting_gateway.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_admin_workout_report.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_admin_reporting_gateway.dart';
import 'firebase_admin_reporting_test.dart' as support;

Map<String, Object?> workoutResponse() {
  const totals = {
    'sessions': 2,
    'fullReps': 10,
    'partialReps': 1,
    'trackedMicros': 20000000,
    'routineAttempts': 2,
    'completedRoutineDays': 1,
    'partialRoutineDays': 0,
    'inProgressRoutineDays': 1,
    'unknownCompletionDays': 0,
    'manualSets': 3
  };
  return {
    'schemaVersion': 1,
    'organizationId': support.reportingScope.organizationId,
    'startAtMillis': support.reportingQuery.range.start.millisecondsSinceEpoch,
    'endAtMillis': support.reportingQuery.range.end.millisecondsSinceEpoch,
    'sourceReadStartedAtMillis': 1792980000000,
    'capturedAtMillis': 1792980001000,
    'timezone': 'Asia/Kuala_Lumpur',
    'classification': 'provisional_member_backup',
    'coverage': {
      'membersScanned': 5,
      'activeMembers': 4,
      'membersWithBackups': 2,
      'membersWithActivity': 1,
      'backupRecords': 4,
      'bytesRead': 6000
    },
    'totals': totals,
    'daily': [
      {'date': '2026-10-25', ...totals}
    ],
    'exercises': [
      {
        'exerciseId': 'squat',
        'name': 'Squat',
        'sessions': 2,
        'fullReps': 10,
        'partialReps': 1,
        'trackedMicros': 20000000,
        'manualSets': 3
      }
    ],
    'forms': [
      {
        'exerciseId': 'squat',
        'scoringVersion': 'squat-v1',
        'detectorId': 'blazepose',
        'detectorVersion': 'v1',
        'cameraView': 'side',
        'armMode': 'not_applicable',
        'scoredSessions': 2,
        'scoreSum': 170,
        'daily': [
          {'date': '2026-10-25', 'scoredSessions': 2, 'scoreSum': 170}
        ]
      }
    ]
  };
}

class PendingWorkouts implements AdminWorkoutReportingGateway {
  final requests = <Completer<AdminWorkoutReport>>[];
  @override
  Future<AdminWorkoutReport> loadWorkouts(query) {
    final c = Completer<AdminWorkoutReport>();
    requests.add(c);
    return c.future;
  }
}

void main() {
  test(
      'Firebase workout gateway sends exact scoped query and rejects session changes after the response',
      () async {
    var current = true;
    Map<String, Object?>? sent;
    final g = FirebaseAdminReportingGateway(
        scope: support.reportingScope,
        isCurrent: () => current,
        currentUid: () => support.reportingScope.userId,
        workoutInvoke: (input) async {
          sent = input;
          return workoutResponse();
        });
    final r = await g.loadWorkouts(support.reportingQuery);
    expect(r.totals.sessions, 2);
    expect(sent!['organizationId'], 'gainpath');
    expect(sent!.length, 4);
    final drift = FirebaseAdminReportingGateway(
        scope: support.reportingScope,
        isCurrent: () => current,
        currentUid: () => support.reportingScope.userId,
        workoutInvoke: (_) async {
          current = false;
          return workoutResponse();
        });
    await expectLater(
        drift.loadWorkouts(support.reportingQuery), throwsStateError);
  });
  test(
      'parses scoped provisional aggregates, exact counts and versioned sample means into current-query CSV',
      () {
    final r = parseAdminWorkoutReport(
        workoutResponse(), support.reportingScope, support.reportingQuery);
    expect(r.totals.sessions, 2);
    expect(r.forms.single.average, 85);
    expect(r.toCsv().toString(), contains('provisional_member_backup'));
    expect(r.toCsv().toString(), contains('Manual sets'));
    expect(r.toCsv().toString(), isNot(contains('userId')));
    expect(r.trend(weekly: true).single.sessions, 2);
  });
  test(
      'rejects foreign scope, wrong date totals, inconsistent coverage and unsafe scores',
      () {
    final changes = <void Function(Map<String, Object?>)>[
      (m) => m['organizationId'] = 'other',
      (m) => (m['totals'] as Map)['sessions'] = 3,
      (m) => (m['coverage'] as Map)['membersWithBackups'] = 6,
      (m) => ((m['forms'] as List).first as Map)['scoreSum'] = 999,
      (m) => ((m['daily'] as List).first as Map)['date'] = '2027-01-01',
    ];
    for (final change in changes) {
      final m = workoutResponse(); // Copy nested const maps before mutation.
      final mutable = <String, Object?>{
        ...m,
        'totals': {...m['totals'] as Map},
        'coverage': {...m['coverage'] as Map},
        'daily': [
          for (final d in m['daily'] as List) {...d as Map}
        ],
        'forms': [
          for (final d in m['forms'] as List) {...d as Map}
        ]
      };
      change(mutable);
      expect(
          () => parseAdminWorkoutReport(
              mutable, support.reportingScope, support.reportingQuery),
          throwsFormatException);
    }
  });
  test('query changes clear old results and reject delayed responses',
      () async {
    final g = PendingWorkouts(),
        c = AdminWorkoutReportingCubit(
            gateway: g, query: support.reportingQuery);
    final first = c.load(), next = support.reportingQuery;
    final q = AdminReportQuery(
        range: DateTimeRange(
            start: next.range.start.subtract(const Duration(days: 1)),
            end: next.range.end));
    final second = c.load(q);
    g.requests[1].complete(parseAdminWorkoutReport({
      ...workoutResponse(),
      'startAtMillis': q.range.start.millisecondsSinceEpoch
    }, support.reportingScope, q));
    await second;
    g.requests[0].complete(parseAdminWorkoutReport(
        workoutResponse(), support.reportingScope, next));
    await first;
    expect(c.state.query, q);
    expect(c.state.report!.query, q);
    final pending = c.load();
    expect(c.state.report!.query, q);
    expect(c.state.loading, isTrue);
    g.requests.last.completeError(StateError('unavailable'));
    await pending;
    expect(c.state.error, isNotNull);
    expect(c.state.report, isNull);
    await c.close();
  });
  test('exports untrusted snapshot names safely for spreadsheets', () {
    final m = workoutResponse();
    ((m['exercises'] as List).first as Map)['name'] =
        '=HYPERLINK("https://example.com")';
    final r = parseAdminWorkoutReport(
        m, support.reportingScope, support.reportingQuery);
    expect(
        r
            .toCsv()
            .expand((row) => row)
            .whereType<String>()
            .where((v) => v.startsWith("'=HYPERLINK"))
            .length,
        1);
  });
  test('normalizes embedded CR/LF before escaping spreadsheet formula prefixes',
      () {
    for (final name in ['Squat\r=1+1', '\r=1+1', 'Squat\n=1+1']) {
      final m = workoutResponse();
      ((m['exercises'] as List).first as Map)['name'] = name;
      final r = parseAdminWorkoutReport(
          m, support.reportingScope, support.reportingQuery);
      final cells = r.toCsv().expand((row) => row).whereType<String>();
      expect(cells.any((cell) => cell.contains('\r') || cell.contains('\n')),
          isFalse);
      if (name.startsWith('\r')) {
        expect(cells.any((cell) => cell.startsWith("' =1+1")), isTrue);
      }
    }
  });
}
