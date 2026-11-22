import 'package:gainpath_mobile/features/recommendation/presentation/member/member_recommendation_sheet.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_mobile/features/recommendation/presentation/member/member_recommendations_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/recommendation/application/member_recommendation_repository.dart';
import 'member_recommendation_repository_test.dart' show memberDetail;

MemberRecommendationDetail record(String id,
        {int created = 1000,
        int revision = 1,
        String branch = 'main',
        String state = 'available'}) =>
    MemberRecommendationDetail.parse({
      ...memberDetail(state: state),
      'recommendationId': id,
      'createdAtMillis': created,
      'revision': revision,
      if (state == 'available')
        'target': {...memberDetail()['target'] as Map, 'branchId': branch}
    }, 'gym1', id);
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  test(
      'tutorial grouping uses exercise ID across placements; kinds stay separate',
      () {
    MemberRecommendationDetail target(
            String id, String kind, Map<String, Object?> target) =>
        MemberRecommendationDetail.parse({
          ...memberDetail(),
          'recommendationId': id,
          'kind': kind,
          'target': target
        }, 'gym1', id);
    Map<String, Object?> tutorial(String routine) => {
          'kind': 'content',
          'destination': {
            'kind': 'published_routine_exercise_tutorial',
            'organizationId': 'gym1',
            'routineId': routine,
            'exerciseIndex': 0,
            'exerciseId': 'squat',
            'dayNumber': 1
          }
        };
    final groups = mergeAvailableMemberRecommendations([
      target('t1', 'content', tutorial('one')),
      target('t2', 'content', tutorial('two')),
      target('r1', 'routine',
          {'kind': 'routine', 'organizationId': 'gym1', 'routineId': 'squat'}),
      target('r2', 'routine',
          {'kind': 'routine', 'organizationId': 'gym1', 'routineId': 'squat'}),
      target('r3', 'routine', {
        'kind': 'routine',
        'organizationId': 'gym1',
        'routineId': 'different'
      }),
    ], DateTime.now());
    expect(groups.map((g) => g.length).toList()..sort(), [1, 2, 2]);
  });
  testWidgets('current pages merge and dismiss every duplicate', (t) async {
    final state = <String, String>{'old': 'available', 'new': 'available'};
    final actions = <String>[];
    final pages = <String?>[];
    final repo = RpcMemberRecommendationRepository(
        scope: SessionScope(userId: 'm1', organizationId: 'gym1'),
        isCurrent: () => true,
        invoke: (request) async {
          final id = request['recommendationId'] as String;
          if (request['action'] == 'dismiss') {
            actions.add(id);
            state[id] = 'dismissed';
          }
          return {
            ...memberDetail(state: state[id]!),
            'recommendationId': id,
            'revision': 4
          };
        });
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: MemberRecommendationsView(
                    repository: repo,
                    isCurrent: () => true,
                    onOpenTarget: (_, __) async {},
                    loadPage: ({required bool history, String? afterId}) async {
                      pages.add(afterId);
                      final id = afterId == null ? 'old' : 'new';
                      return MemberRecommendationPage(records: [
                        record(id,
                            state: state[id]!,
                            created: id == 'new' ? 2000 : 1000)
                      ], nextAfterId: afterId == null ? 'next' : null);
                    })))));
    await t.pumpAndSettle();
    expect(pages, [null, 'next']);
    expect(find.byType(RecommendationCard), findsOneWidget);
    expect(
        t
            .widget<RecommendationCard>(find.byType(RecommendationCard))
            .detail
            .recommendationId,
        'new');
    t.widget<RecommendationCard>(find.byType(RecommendationCard)).onDismiss!();
    await t.pumpAndSettle();
    expect(actions, ['new', 'old']);
    expect(find.byType(RecommendationCard), findsNothing);
  });
  testWidgets('merged details expose only current valid additional reasons',
      (t) async {
    final repo = RpcMemberRecommendationRepository(
        scope: SessionScope(userId: 'm1', organizationId: 'gym1'),
        isCurrent: () => true,
        invoke: (request) async {
          final id = request['recommendationId'] as String;
          return {
            ...memberDetail(
                state: id == 'withdrawn' ? 'withdrawn' : 'available'),
            'recommendationId': id,
            'readAtMillis': 1200,
            'summary': id == 'old'
                ? 'Additional balance guidance.'
                : 'Latest strength guidance.'
          };
        });
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MemberRecommendationSheet(
                recommendationId: 'new',
                repository: repo,
                isCurrent: () => true,
                relatedRecommendations: [
          record('new'),
          record('old'),
          record('withdrawn')
        ]))));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Other recommendation reasons'));
    await t.tap(find.text('Other recommendation reasons'));
    await t.pumpAndSettle();
    expect(find.textContaining('Additional balance guidance.'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(2));
  });
  test('groups coaches across branches and selects newest valid delivery', () {
    final old = record('old');
    final newest = record('new', created: 2000, branch: 'other');
    final groups = mergeAvailableMemberRecommendations(
        [old, newest, record('dismissed', state: 'dismissed')], DateTime.now());
    expect(groups, hasLength(1));
    expect(groups.single.map((r) => r.recommendationId), ['new', 'old']);
  });
  test('dismiss checks current revisions for every original identity',
      () async {
    final actions = <Map<String, Object?>>[];
    final repo = RpcMemberRecommendationRepository(
        scope: SessionScope(userId: 'm1', organizationId: 'gym1'),
        isCurrent: () => true,
        invoke: (request) async {
          if (request['action'] == 'dismiss') actions.add(request);
          return {
            ...memberDetail(),
            'recommendationId': request['recommendationId'],
            'revision': 3
          };
        });
    await dismissMemberRecommendationGroup(
        repo, [record('a'), record('b')], () => true);
    expect(actions.map((r) => r['recommendationId']), ['a', 'b']);
    expect(actions.every((r) => r['expectedRevision'] == 3), isTrue);
  });
  test('session drift stops group dismissal before next recipient command',
      () async {
    var current = true;
    final actions = <String>[];
    final repo = RpcMemberRecommendationRepository(
        scope: SessionScope(userId: 'm1', organizationId: 'gym1'),
        isCurrent: () => current,
        invoke: (request) async {
          if (request['action'] == 'dismiss') {
            actions.add(request['recommendationId'] as String);
            current = false;
          }
          return {
            ...memberDetail(),
            'recommendationId': request['recommendationId']
          };
        });
    await expectLater(
        dismissMemberRecommendationGroup(
            repo, [record('a'), record('b')], () => current),
        throwsA(isA<MemberRecommendationUnavailable>()));
    expect(actions, ['a']);
  });
}
