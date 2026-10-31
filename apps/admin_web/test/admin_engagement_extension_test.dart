import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/analytics/application/admin_engagement_extension.dart';
import 'package:gainpath_admin_web/features/analytics/presentation/admin/admin_engagement_widgets.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_admin_check_in_report.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_admin_reporting_gateway.dart';
import 'admin_check_in_reporting_test.dart' as fixture;
import 'firebase_admin_reporting_test.dart' as support;

Map<String, Object?> extensionFixture() => {
      'schemaVersion': 1,
      'sourceCounts': {'redemptions': 2, 'rounds': 1, 'awards': 1},
      'redemptions': {
        'issued': 1,
        'collected': 1,
        'expired': 0,
        'pointsSpent': 100,
        'issuedStatus': {
          'outstanding': 0,
          'collected': 1,
          'expired': 0,
          'expiryUnknown': 0
        },
        'daily': [
          {
            'date': '2026-10-25',
            'issued': 1,
            'collected': 1,
            'expired': 0,
            'pointsSpent': 100
          }
        ],
        'rewards': [
          {
            'itemId': 'shirt',
            'title': 'Gym shirt',
            'issued': 1,
            'collected': 1,
            'pointsSpent': 100
          }
        ]
      },
      'games': [
        for (final id in ['move-catch-v1', 'reach-tap-v1'])
          {
            'gameId': id,
            'started': id == 'move-catch-v1' ? 1 : 0,
            'completed': id == 'move-catch-v1' ? 1 : 0,
            'abandoned': 0,
            'open': 0,
            'uniqueMembers': id == 'move-catch-v1' ? 1 : 0,
            'awards': id == 'move-catch-v1' ? 1 : 0,
            'pointsAwarded': id == 'move-catch-v1' ? 20 : 0,
            'daily': id == 'move-catch-v1'
                ? [
                    {
                      'date': '2026-10-25',
                      'started': 1,
                      'completed': 1,
                      'awards': 1,
                      'pointsAwarded': 20
                    }
                  ]
                : []
          }
      ],
      'badges': [
        {'badgeId': 'first-check-in', 'unlocks': 1}
      ],
      'earningSources': [
        {'source': 'daily_check_in', 'claims': 2, 'pointsAwarded': 100},
        {'source': 'move-catch-v1', 'claims': 1, 'pointsAwarded': 20},
        {'source': 'reach-tap-v1', 'claims': 0, 'pointsAwarded': 0}
      ]
    };
AdminEngagementExtension parsed(Map<String, Object?> e) =>
    parseAdminCheckInReport({...fixture.checkInResponse(), 'extensions': e},
            support.reportingScope, support.reportingQuery)
        .extensions!;
void main() {
  test('voucher status as-of stays at scan start across Malaysia midnight', () {
    final raw = {
      ...fixture.checkInResponse(),
      'extensions': extensionFixture(),
      'sourceReadStartedAtMillis':
          DateTime.utc(2026, 10, 25, 15, 59, 59).millisecondsSinceEpoch,
      'capturedAtMillis':
          DateTime.utc(2026, 10, 25, 16, 0, 1).millisecondsSinceEpoch,
      'streaks': {
        ...(fixture.checkInResponse()['streaks'] as Map),
        'asOfDate': '2026-10-25'
      }
    };
    final e = parseAdminCheckInReport(
            raw, support.reportingScope, support.reportingQuery)
        .extensions!;
    expect(e.statusAsOf.add(const Duration(hours: 8)).day, 25);
    expect(e.capturedAt.add(const Duration(hours: 8)).day, 26);
    expect(e.redemptionCsv().expand((r) => r),
        contains(e.statusAsOf.toIso8601String()));
  });
  test('parses real source units and scoped section CSV without Game Score',
      () {
    final e = parsed(extensionFixture());
    expect(e.redemptions['pointsSpent'], 100);
    expect(e.games.first['pointsAwarded'], 20);
    final csv = e.redemptionCsv().expand((r) => r).toList();
    expect(csv, contains('Gym shirt'));
    expect(csv,
        contains(support.reportingQuery.range.start.toUtc().toIso8601String()));
    expect(csv, isNot(contains('move-catch-v1')));
    expect(e.engagementCsv().expand((r) => r), isNot(contains('score')));
  });
  test('legacy response keeps extensions unavailable rather than zero', () {
    expect(
        parseAdminCheckInReport(fixture.checkInResponse(),
                support.reportingScope, support.reportingQuery)
            .extensions,
        isNull);
  });
  test(
      'rejects inconsistent totals, foreign dates and incompatible game identity',
      () {
    var e = extensionFixture();
    (e['redemptions'] as Map)['issued'] = 2;
    expect(() => parsed(e), throwsFormatException);
    e = extensionFixture();
    (((e['games'] as List).first as Map)['daily'] as List).first['date'] =
        '2026-10-26';
    expect(() => parsed(e), throwsFormatException);
    e = extensionFixture();
    ((e['games'] as List).last as Map)['gameId'] = 'foreign';
    expect(() => parsed(e), throwsFormatException);
    e = extensionFixture();
    ((e['earningSources'] as List).first as Map)['pointsAwarded'] = 150;
    expect(() => parsed(e), throwsFormatException);
  });
  test('CSV neutralizes formula names and normalizes line breaks', () {
    final e = extensionFixture();
    ((e['redemptions'] as Map)['rewards'] as List).first['title'] =
        '=HYPERLINK("x")\nnext';
    expect(parsed(e).redemptionCsv().expand((r) => r),
        contains("'=HYPERLINK(\"x\") next"));
  });
  test('coalesces concurrent sections and refreshes after completion',
      () async {
    var calls = 0;
    final pending = Completer<Object?>();
    final g = FirebaseAdminReportingGateway(
        scope: support.reportingScope,
        isCurrent: () => true,
        currentUid: () => support.reportingScope.userId,
        checkInInvoke: (q) {
          calls++;
          expect(q['schemaVersion'], 3);
          return calls == 1
              ? pending.future
              : Future.value(fixture.checkInResponse());
        });
    final a = g.loadCheckIns(support.reportingQuery),
        b = g.loadCheckIns(support.reportingQuery);
    expect(calls, 1);
    pending.complete(
        {...fixture.checkInResponse(), 'extensions': extensionFixture()});
    expect(identical(await a, await b), true);
    await g.loadCheckIns(support.reportingQuery);
    expect(calls, 2);
  });
  test('old endpoint negotiates 3 to 2 to 1 without fabricating extended data',
      () async {
    final schemas = <Object?>[];
    final g = FirebaseAdminReportingGateway(
        scope: support.reportingScope,
        isCurrent: () => true,
        currentUid: () => support.reportingScope.userId,
        checkInInvoke: (q) async {
          schemas.add(q['schemaVersion']);
          if (q['schemaVersion'] != 1)
            throw FirebaseFunctionsException(
                code: 'invalid-argument', message: 'old contract');
          return fixture.checkInResponse();
        });
    expect((await g.loadCheckIns(support.reportingQuery)).extensions, isNull);
    expect(schemas, [3, 2, 1]);
  });
  testWidgets('empty server history is readable at enlarged text', (t) async {
    final raw = extensionFixture(),
        r = raw['redemptions'] as Map<String, Object>;
    r.addAll(<String, Object>{
      'issued': 0,
      'collected': 0,
      'expired': 0,
      'pointsSpent': 0,
      'issuedStatus': {
        'outstanding': 0,
        'collected': 0,
        'expired': 0,
        'expiryUnknown': 0
      },
      'daily': [],
      'rewards': []
    });
    t.view.physicalSize = const Size(400, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
                body: SingleChildScrollView(
                    child: AdminRedemptionData(extension: parsed(raw)))))));
    await t.pumpAndSettle();
    expect(
        find.text('No reward redemptions or collections in this date range.'),
        findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'original report panels support narrow enlarged text and useful units',
      (t) async {
    t.view.physicalSize = const Size(480, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final e = parsed(extensionFixture());
    await t.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
                body: SingleChildScrollView(
                    child: Column(children: [
              AdminRedemptionData(extension: e),
              AdminGameEngagementData(extension: e)
            ]))))));
    await t.pumpAndSettle();
    expect(find.text('Points spent'), findsNWidgets(2));
    expect(find.text('Recorded mini-game participation'), findsOneWidget);
    expect(find.text('Reach & Tap'), findsWidgets);
    expect(t.takeException(), isNull);
  });
}
