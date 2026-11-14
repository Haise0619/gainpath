import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/recommendation/application/member_recommendation_repository.dart';
import 'package:gainpath_mobile/features/recommendation/presentation/member/member_recommendations_view.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_member_recommendations.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_app_check_readiness.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'member_recommendation_repository_test.dart' show memberDetail;

final scope = SessionScope(userId: 'm1', organizationId: 'gym1');
FirebaseAppCheckReadiness readiness() => FirebaseAppCheckReadiness(
    mode: 'production',
    supported: true,
    activate: (_) async {},
    token: () async => 'synthetic-test-token');
Map<String, Object?> page(Map<String, Object?> detail) => {
      'schemaVersion': 1,
      'mode': 'accepted_workout',
      'organizationId': 'gym1',
      'enabled': true,
      'recommendations': [detail],
      'nextAfterId': null,
    };
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  test('disabled client never calls Firebase or seeds recommendations',
      () async {
    var calls = 0;
    final r = FirebaseMemberRecommendations(
        scope: scope,
        enabled: false,
        isCurrent: () => true,
        currentUid: () => 'm1',
        readiness: readiness(),
        invoke: (_) async {
          calls++;
          return {};
        });
    expect((await r.loadPage(history: false)).enabled, false);
    expect(r.recommendation.enabled, false);
    expect(calls, 0);
  });
  test('canonical page rejects prepared and fictional data and binds scope',
      () async {
    var raw = {...memberDetail(), 'mode': 'accepted_workout'};
    final requests = <Map<String, Object?>>[];
    final r = FirebaseMemberRecommendations(
        scope: scope,
        enabled: true,
        isCurrent: () => true,
        currentUid: () => 'm1',
        readiness: readiness(),
        invoke: (q) async {
          requests.add(q);
          return page(raw);
        });
    final result = await r.loadPage(history: false);
    expect(result.records.single.targetLabel, 'Coach Alex');
    expect(r.recommendation.fixtureOnly, false);
    expect(requests.single['operation'], 'member.recommendation.list');
    expect((requests.single['data'] as Map)['organizationId'], 'gym1');
    raw = {...raw, 'deliveredAtMillis': null};
    await expectLater(r.loadPage(history: false), throwsFormatException);
    raw = {...memberDetail()};
    await expectLater(r.loadPage(history: false), throwsFormatException);
  });
  test('account drift while canonical request waits rejects delayed result',
      () async {
    var current = true;
    final pending = Completer<Object?>();
    final started = Completer<void>();
    final r = FirebaseMemberRecommendations(
        scope: scope,
        enabled: true,
        isCurrent: () => current,
        currentUid: () => 'm1',
        readiness: readiness(),
        invoke: (_) {
          started.complete();
          return pending.future;
        });
    final load = r.loadPage(history: false);
    await started.future;
    current = false;
    pending.complete(page({...memberDetail(), 'mode': 'accepted_workout'}));
    await expectLater(load, throwsA(isA<MemberRecommendationUnavailable>()));
  });
  for (final width in [320.0, 360.0, 390.0]) {
    testWidgets('delivered feed and history at $width and 200 percent',
        (t) async {
      t.view.physicalSize = Size(width, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      var openings = 0;
      final actions = <String>[];
      final repo = RpcMemberRecommendationRepository(
          scope: scope,
          isCurrent: () => true,
          invoke: (q) async {
            actions.add(q['action']! as String);
            return memberDetail();
          });
      final requests = <bool>[];
      await t.pumpWidget(MaterialApp(
          theme: AppTheme.build(),
          builder: (c, child) => MediaQuery(
              data: MediaQuery.of(c)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!),
          home: Scaffold(
              body: SingleChildScrollView(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: MemberRecommendationsView(
                          repository: repo,
                          isCurrent: () => true,
                          loadPage: (
                              {required bool history, String? afterId}) async {
                            requests.add(history);
                            return MemberRecommendationPage(records: [
                              MemberRecommendationDetail.parse(
                                  memberDetail(), 'gym1', 'r1')
                            ]);
                          },
                          onOpenTarget: (_, __) async {
                            openings++;
                          }))))));
      await t.pumpAndSettle();
      expect(find.text('Coach Alex'), findsOneWidget);
      expect(actions, isEmpty);
      await t.tap(find.text('History'));
      await t.pumpAndSettle();
      expect(requests, [false, true]);
      await t.scrollUntilVisible(find.text('View Coach'), 160,
          scrollable: find.byType(Scrollable).first);
      await t.tap(find.text('View Coach'));
      await t.pumpAndSettle();
      expect(openings, 1);
      expect(actions, ['resolve', 'read']);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }
}
