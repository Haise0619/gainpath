import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_mobile/features/recommendation/application/member_recommendation_repository.dart';
import 'member_recommendation_repository_test.dart' show memberDetail;
import 'package:gainpath_mobile/app/notifications/member_recommendation_navigator.dart';
import 'member_recommendation_navigation_test.dart'
    show routeMember, RecommendationCatalog, RecommendationDirectory;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/routine_screen.dart';
import 'package:gainpath_mobile/app/routing/routine_journey_route.dart';
import 'package:google_fonts/google_fonts.dart';
import 'member_recommendation_navigation_test.dart' show RecommendationTestAuth;

Map<String, Object?> routineDetail() => {
      ...memberDetail(),
      'kind': 'routine',
      'target': {
        'kind': 'routine',
        'organizationId': 'gym1',
        'routineId': 'routine1'
      },
      'targetLabel': 'Build your strength',
      'difficulty': 'Beginner',
      'durationMinutes': 20,
      'exerciseCount': 4,
      'priceMinor': null,
      'currency': null,
      'branchLabel': null,
    };

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'delivered routine opens published preview and existing workout entry with back navigation',
      (t) async {
    final source = RecommendationTestAuth(routeMember);
    final auth = AuthBloc(repository: source);
    await t.pump();
    addTearDown(auth.close);
    addTearDown(source.dispose);
    final catalog = RecommendationCatalog(routeMember.scope);
    var resolves = 0;
    final repository = RpcMemberRecommendationRepository(
        scope: routeMember.scope,
        isCurrent: () => true,
        invoke: (request) async {
          resolves++;
          return routineDetail();
        });
    final navigator = MemberRecommendationNavigator(
        session: routeMember,
        repository: repository,
        isCurrent: () => true,
        coachDirectory: RecommendationDirectory(routeMember.scope),
        catalog: catalog);
    await t.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
            home: Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () => navigator.open(
                            context,
                            MemberRecommendationDetail.parse(
                                routineDetail(), 'gym1', 'r1')),
                        child: const Text('Open routine')))))));
    await t.tap(find.text('Open routine'));
    await t.pumpAndSettle();
    expect(resolves, 1);
    expect(find.byType(RoutineScreen), findsOneWidget);
    expect(find.text('Current Squat Tutorial'), findsOneWidget);
    await t.tap(find.text('Start Workout'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byType(RoutineJourneyRoute), findsOneWidget);
    final journey =
        t.widget<RoutineJourneyRoute>(find.byType(RoutineJourneyRoute));
    expect(journey.routine.id, 'routine1');
    expect(journey.programStoreFactory, isNotNull);
    expect(catalog.loads, 2);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byType(RoutineScreen), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.text('Open routine'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
  test(
      'general discovery is loaded from real scoped publications and rechecked',
      () async {
    final catalog = RecommendationCatalog(routeMember.scope);
    final navigator = MemberRecommendationNavigator(
        session: routeMember,
        repository:
            UnavailableMemberRecommendationRepository(routeMember.scope),
        isCurrent: () => true,
        coachDirectory: RecommendationDirectory(routeMember.scope),
        catalog: catalog);
    final items = await navigator.loadDiscovery();
    expect(items.map((r) => r.kind.name), containsAll(['routine', 'content']));
    expect(items.first.title, 'Current authored Routine');
    final routine = await navigator
        .resolveRoutine(const RoutineRecommendationTarget('gym1', 'routine1'));
    expect(identical(routine, catalog.routine), true);
    catalog.routine = null;
    await expectLater(
        navigator.resolveRoutine(
            const RoutineRecommendationTarget('gym1', 'routine1')),
        throwsA(isA<MemberRecommendationUnavailable>()));
    await expectLater(
        navigator.resolveRoutine(
            const RoutineRecommendationTarget('other', 'routine1')),
        throwsA(isA<MemberRecommendationUnavailable>()));
  });
  test(
      'published routine target and optional card metadata parse with legacy records',
      () {
    final detail =
        MemberRecommendationDetail.parse(routineDetail(), 'gym1', 'r1');
    expect(detail.kind.name, 'routine');
    expect(detail.target.runtimeType.toString(), 'RoutineRecommendationTarget');
    expect(detail.available, true);
    expect(
        MemberRecommendationDetail.parse(memberDetail(), 'gym1', 'r1')
            .available,
        true);
  });
  test('routine notice rejects foreign scope and mismatched target kinds', () {
    final notice = {
      'schemaVersion': 1,
      'recommendationId': 'r1',
      'kind': 'routine',
      'state': 'available',
      'expiresAtMillis': 4102444800000,
      'target': routineDetail()['target'],
    };
    expect(RecommendationNotice.parse(notice, 'gym1').kind.name, 'routine');
    expect(() => RecommendationNotice.parse(notice, 'other'),
        throwsFormatException);
    expect(
        () =>
            RecommendationNotice.parse({...notice, 'kind': 'content'}, 'gym1'),
        throwsFormatException);
  });
}
