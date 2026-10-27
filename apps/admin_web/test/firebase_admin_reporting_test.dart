import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_admin_reporting_gateway.dart';
import 'package:gainpath_admin_web/features/analytics/application/admin_reporting_gateway.dart';

final reportingScope =
    SessionScope(userId: 'admin', organizationId: 'gainpath');
final reportingQuery = AdminReportQuery(
    range: DateTimeRange(
        start: DateTime.utc(2026, 10, 24, 16),
        end: DateTime.utc(2026, 10, 25, 16)));
Map<String, dynamic> reportingResponse() => {
      'schemaVersion': 1,
      'organizationId': 'gainpath',
      'startAtMillis': reportingQuery.range.start.millisecondsSinceEpoch,
      'endAtMillis': reportingQuery.range.end.millisecondsSinceEpoch,
      'capturedAtMillis': DateTime.utc(2026, 10, 26).millisecondsSinceEpoch,
      'sourceReadStartedAtMillis':
          DateTime.utc(2026, 10, 26).millisecondsSinceEpoch,
      'timezone': 'Asia/Kuala_Lumpur',
      'environment': 'sandbox',
      'currentAccounts': {'members': 3, 'coaches': 1},
      'bookings': {
        'created': 2,
        'scheduledStarts': 1,
        'statuses': {
          'pending_hold': 1,
          'confirmed': 1,
          'completed': 0,
          'cancelled': 0,
          'expired': 0,
          'refunded': 0
        }
      },
      'receipts': <String, dynamic>{
        'confirmedMinor': 13900,
        'membershipMinor': 8900,
        'coachingMinor': 5000,
        'confirmedCount': 2,
        'reviewMinor': 9000,
        'reviewCount': 1,
        'refundedMinor': 0,
        'refundedCount': 0
      },
      'daily': [
        {
          'date': '2026-10-25',
          'bookingsCreated': 2,
          'scheduledStarts': 1,
          'receiptsMinor': 13900,
          'membershipMinor': 8900,
          'coachingMinor': 5000
        }
      ],
      'sourceCounts': {'members': 4, 'bookings': 3, 'transactions': 4},
      'unsupported': [
        'posture',
        'facility_occupancy',
        'retention_risk',
        'reward_redemptions',
        'coach_utilization',
        'net_revenue',
        'branch_allocation'
      ]
    };
void main() {
  test('sends only scoped dates and maps real confirmed minor-unit amounts',
      () async {
    Map<String, Object?>? sent;
    final gateway = FirebaseAdminReportingGateway(
        scope: reportingScope,
        isCurrent: () => true,
        currentUid: () => reportingScope.userId,
        invoke: (data) async {
          sent = data;
          return reportingResponse();
        });
    final r = await gateway.load(reportingQuery);
    expect(sent!.keys.toSet(),
        {'schemaVersion', 'organizationId', 'startAtMillis', 'endAtMillis'});
    expect(r.totalRevenue!.minorUnits, 13900);
    expect(r.activeMembersCount, 3);
    expect(r.operations!.reviewMinor, 9000);
    expect(r.avgPostureAccuracy, isNull);
    expect(r.operations!.toCsv(r).join('\n'), contains('Sandbox'));
  });
  test('account drift drops a delayed response', () async {
    var active = true;
    final response = Completer<Object?>();
    final gateway = FirebaseAdminReportingGateway(
        scope: reportingScope,
        isCurrent: () => active,
        currentUid: () => reportingScope.userId,
        invoke: (_) => response.future);
    final wait = gateway.load(reportingQuery);
    active = false;
    response.complete(reportingResponse());
    await expectLater(wait, throwsStateError);
  });
  test('foreign response, malformed money and incompatible query fail closed',
      () async {
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (r) => r['organizationId'] = 'other',
      (r) => r['endAtMillis'] = 1,
      (r) => (r['receipts'] as Map)['confirmedMinor'] = 1,
      (r) => (r['receipts'] as Map)['confirmedMinor'] = double.nan,
      (r) => r['daily'] = [...(r['daily'] as List), ...(r['daily'] as List)],
      (r) => r['environment'] = 'production'
    ]) {
      final gateway = FirebaseAdminReportingGateway(
          scope: reportingScope,
          isCurrent: () => true,
          currentUid: () => reportingScope.userId,
          invoke: (_) async {
            final r = reportingResponse();
            mutate(r);
            return r;
          });
      await expectLater(gateway.load(reportingQuery), throwsFormatException);
    }
  });
  test('wrong SDK account and unsupported branch never invoke service',
      () async {
    var calls = 0;
    final gateway = FirebaseAdminReportingGateway(
        scope: reportingScope,
        isCurrent: () => true,
        currentUid: () => 'other',
        invoke: (_) async {
          calls++;
          return reportingResponse();
        });
    await expectLater(gateway.load(reportingQuery), throwsStateError);
    expect(calls, 0);
    final branch = FirebaseAdminReportingGateway(
        scope: reportingScope,
        isCurrent: () => true,
        currentUid: () => reportingScope.userId,
        invoke: (_) async {
          calls++;
          return reportingResponse();
        });
    final r = await branch.load(
        AdminReportQuery(range: reportingQuery.range, branchId: 'branch'));
    expect(r.isAvailable, false);
    expect(calls, 0);
  });
}
