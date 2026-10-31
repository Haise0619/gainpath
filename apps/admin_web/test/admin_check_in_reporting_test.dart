import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/analytics/application/admin_check_in_reporting.dart';
import 'package:gainpath_admin_web/features/analytics/application/admin_reporting_gateway.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_admin_check_in_report.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_admin_reporting_gateway.dart';
import 'firebase_admin_reporting_test.dart' as support;

Map<String, Object?> checkInResponse() => {
      'schemaVersion': 1,
      'organizationId': 'gainpath',
      'startAtMillis':
          support.reportingQuery.range.start.millisecondsSinceEpoch,
      'endAtMillis': support.reportingQuery.range.end.millisecondsSinceEpoch,
      'sourceReadStartedAtMillis':
          DateTime.utc(2026, 10, 26, 6).millisecondsSinceEpoch,
      'capturedAtMillis':
          DateTime.utc(2026, 10, 26, 6, 0, 1).millisecondsSinceEpoch,
      'timezone': 'Asia/Kuala_Lumpur',
      'policyVersion': 'app-check-in-v1',
      'pointsPerClaim': 50,
      'coverage': {
        'membersScanned': 5,
        'activeMembers': 4,
        'profiles': 2,
        'claimsScanned': 6
      },
      'totals': {'claims': 2, 'claimingMembers': 2, 'pointsAwarded': 100},
      'daily': [
        {
          'date': '2026-10-25',
          'claims': 2,
          'claimingMembers': 2,
          'pointsAwarded': 100
        }
      ],
      'weekly': [
        {
          'date': '2026-10-19',
          'claims': 2,
          'claimingMembers': 2,
          'pointsAwarded': 100
        }
      ],
      'streaks': {
        'asOfDate': '2026-10-26',
        'current': {'zero': 2, 'oneTwo': 1, 'threeSix': 1, 'sevenPlus': 0},
        'longest': {'zero': 2, 'oneTwo': 0, 'threeSix': 1, 'sevenPlus': 1}
      },
    };

class PendingCheckIns implements AdminCheckInReportingGateway {
  final requests = <Completer<AdminCheckInReport>>[];
  @override
  Future<AdminCheckInReport> loadCheckIns(AdminReportQuery query) {
    final c = Completer<AdminCheckInReport>();
    requests.add(c);
    return c.future;
  }
}

void main() {
  test(
      'Firebase check-in gateway sends scoped query and rejects auth-session drift after await',
      () async {
    var current = true;
    Map<String, Object?>? sent;
    final g = FirebaseAdminReportingGateway(
        scope: support.reportingScope,
        isCurrent: () => current,
        currentUid: () => support.reportingScope.userId,
        checkInInvoke: (input) async {
          sent = input;
          return checkInResponse();
        });
    expect((await g.loadCheckIns(support.reportingQuery)).pointsAwarded, 100);
    expect(sent!.length, 4);
    expect(sent!['organizationId'], 'gainpath');
    final drift = FirebaseAdminReportingGateway(
        scope: support.reportingScope,
        isCurrent: () => current,
        currentUid: () => support.reportingScope.userId,
        checkInInvoke: (_) async {
          current = false;
          return checkInResponse();
        });
    await expectLater(
        drift.loadCheckIns(support.reportingQuery), throwsStateError);
  });
  test(
      'parses scoped claims/points and distinct weekly claimants, CSV labels current streaks separately',
      () {
    final r = parseAdminCheckInReport(
        checkInResponse(), support.reportingScope, support.reportingQuery);
    expect(r.claims, 2);
    expect(r.pointsAwarded, 100);
    expect(r.claimingMembers, 2);
    expect(r.weekly.single.claimingMembers, 2);
    expect(r.toCsv().toString(), contains('Current as of'));
    expect(r.toCsv().toString(), contains('app-check-in-v1'));
    expect(r.toCsv().toString(), isNot(contains('memberId')));
  });
  test(
      'rejects wrong scope/policy, inconsistent points, cohort or day/week aggregates',
      () {
    final changes = <void Function(Map<String, Object?>)>[
      (m) => m['organizationId'] = 'other',
      (m) => m['pointsPerClaim'] = 500,
      (m) => (m['totals'] as Map)['pointsAwarded'] = 101,
      (m) => (m['coverage'] as Map)['activeMembers'] = 1,
      (m) => ((m['weekly'] as List).first as Map)['claimingMembers'] = 3,
      (m) => ((m['daily'] as List).first as Map)['date'] = '2027-01-01',
    ];
    for (final change in changes) {
      final m = checkInResponse();
      change(m);
      expect(
          () => parseAdminCheckInReport(
              m, support.reportingScope, support.reportingQuery),
          throwsFormatException);
    }
  });
  test('date changes and refresh discard old or delayed check-in data',
      () async {
    final g = PendingCheckIns(),
        c = AdminCheckInReportingCubit(
            gateway: g, query: support.reportingQuery);
    final first = c.load(),
        q = AdminReportQuery(
            range: DateTimeRange(
                start: support.reportingQuery.range.start
                    .subtract(const Duration(days: 1)),
                end: support.reportingQuery.range.end));
    final second = c.load(q);
    g.requests[1].complete(parseAdminCheckInReport({
      ...checkInResponse(),
      'startAtMillis': q.range.start.millisecondsSinceEpoch
    }, support.reportingScope, q));
    await second;
    g.requests[0].complete(parseAdminCheckInReport(
        checkInResponse(), support.reportingScope, support.reportingQuery));
    await first;
    expect(c.state.report!.query, q);
    final retry = c.load();
    expect(c.state.report!.query, q);
    expect(c.state.loading, isTrue);
    g.requests.last.completeError(StateError('offline'));
    await retry;
    expect(c.state.error, isNotNull);
    await c.close();
  });
}
