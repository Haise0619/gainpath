import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:gainpath_admin_web/features/analytics/application/admin_commerce_report.dart';
import 'package:gainpath_admin_web/features/analytics/presentation/admin/admin_commerce_section.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_admin_reporting_gateway.dart';
import 'firebase_admin_reporting_test.dart' as support;

Map<String, dynamic> metric(int n) => {
      'purchases': n,
      'renewals': 0,
      'confirmedMinor': n * 1000,
      'confirmedCount': n,
      'reviewMinor': 0,
      'refundedMinor': 0,
      'statuses': {'cleared': n},
      'refundStatuses': {'none': n},
      'daily': [
        if (n > 0)
          {
            'date': '2026-10-25',
            'confirmedMinor': n * 1000,
            'purchases': n,
            'renewals': 0
          }
      ],
      'previous': {
        'confirmedMinor': 0,
        'confirmedCount': 0,
        'purchases': 0,
        'renewals': 0
      }
    };
Map<String, dynamic> commerce() => {
      'schemaVersion': 1,
      'asOfMillis': DateTime.utc(2026, 10, 26).millisecondsSinceEpoch,
      'coaches': [
        {
          'coachId': 'coach',
          'name': 'Coach A',
          'bookings': 2,
          'confirmed': 0,
          'completed': 1,
          'cancelled': 1,
          'expired': 0,
          'pendingHold': 0,
          'refunded': 0,
          'consultations': 1,
          'missingConsultations': 0,
          'reviewCount': 1,
          'ratingSum': 4,
          'scheduledStarts': 1,
          'daily': [
            {'date': '2026-10-25', 'bookings': 2, 'consultations': 1}
          ]
        }
      ],
      'membership': {
        'current': {'free': 1, 'basic': 1, 'premium': 0, 'unknown': 1},
        'plans': [
          {'planId': 'basic', ...metric(1)},
          {'planId': 'premium', ...metric(2)}
        ],
        'coaching': metric(1),
        'previousAvailable': true
      },
      'coverage': {
        'membersConsidered': 3,
        'bookingsScanned': 2,
        'paymentsScanned': 4
      }
    };
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  test(
      'validates coach outcomes, ratings and maps unknown entitlement without guessing',
      () {
    final r = AdminCommerceReport.parse(commerce(), support.reportingQuery);
    expect(r.coaches.single['bookings'], 2);
    expect(r.current['unknown'], 1);
    expect(r.coaching.id, 'coaching');
    final bad = commerce();
    ((bad['coaches'] as List).first as Map)['completed'] = 8;
    expect(() => AdminCommerceReport.parse(bad, support.reportingQuery),
        throwsFormatException);
  });
  test(
      'selected plan CSV excludes other historical plans and retains explicitly current census',
      () {
    final r = AdminCommerceReport.parse(commerce(), support.reportingQuery);
    final csv = r.csv(coach: false, filter: 'basic');
    expect(csv.where((row) => row.firstOrNull == 'ID').map((row) => row[1]),
        ['basic']);
    expect(csv.expand((row) => row), contains('Current tier'));
    expect(csv.expand((row) => row), contains('unknown'));
  });
  test('spreadsheet labels are escaped and bad rating samples fail closed', () {
    final raw = commerce();
    ((raw['coaches'] as List).first as Map)['name'] = '=SUM(1)';
    final r = AdminCommerceReport.parse(raw, support.reportingQuery);
    expect(r.csv(coach: true).expand((row) => row), contains("'=SUM(1)"));
    ((raw['coaches'] as List).first as Map)['ratingSum'] = 6;
    expect(() => AdminCommerceReport.parse(raw, support.reportingQuery),
        throwsFormatException);
  });
  test(
      'legacy service fallback retains base reports without inventing extension',
      () async {
    final versions = <Object?>[];
    final gateway = FirebaseAdminReportingGateway(
        scope: support.reportingScope,
        isCurrent: () => true,
        currentUid: () => support.reportingScope.userId,
        invoke: (q) async {
          versions.add(q['schemaVersion']);
          if (q['schemaVersion'] == 2) {
            throw FirebaseFunctionsException(
                code: 'invalid-argument', message: 'legacy');
          }
          return support.reportingResponse();
        });
    final r = await gateway.load(support.reportingQuery);
    expect(versions, [2, 1]);
    expect(r.commerce, isNull);
    expect(r.totalRevenue!.minorUnits, 13900);
  });
  testWidgets(
      'Coach comparison shows distinct consultation metrics and sortable rates',
      (tester) async {
    tester.view.physicalSize = const Size(1300, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: AdminCommerceSection(
                    anchorKey: GlobalKey(),
                    report: AdminCommerceReport.parse(
                        commerce(), support.reportingQuery),
                    coach: true)))));
    await tester.pumpAndSettle();
    expect(find.text('Consultations'), findsOneWidget);
    expect(find.text('50.0%'), findsNWidgets(2));
    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'membership plan filter, unknown census and narrow large text remain usable',
      (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!),
        home: Scaffold(
            body: SingleChildScrollView(
                child: AdminCommerceSection(
                    anchorKey: GlobalKey(),
                    report: AdminCommerceReport.parse(
                        commerce(), support.reportingQuery),
                    coach: false)))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Current unknown Members'), findsOneWidget);
  });
}
