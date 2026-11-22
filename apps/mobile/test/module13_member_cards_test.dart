import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/recommendation/application/member_recommendation_repository.dart';
import 'package:gainpath_mobile/features/recommendation/presentation/member/member_recommendations_view.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'module13_member_routine_test.dart' show routineDetail;
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_mobile/features/recommendation/application/published_recommendation_suggestion.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'empty personalized page displays real general discovery without member response actions',
      (t) async {
    var opens = 0;
    final scope = SessionScope(userId: 'm1', organizationId: 'gym1');
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.build(),
        home: Scaffold(
            body: SingleChildScrollView(
                child: MemberRecommendationsView(
          compact: true,
          repository: UnavailableMemberRecommendationRepository(scope),
          isCurrent: () => true,
          onOpenTarget: (_, __) async => fail('personalized navigation'),
          loadPage: ({required bool history, String? afterId}) async =>
              throw StateError('personalized disabled'),
          loadDiscovery: () async => [
            const PublishedRecommendationSuggestion(
                kind: RecommendationKind.routine,
                target: RoutineRecommendationTarget('gym1', 'published-1'),
                title: 'Real published catalog title',
                difficulty: 'Beginner',
                imageUrl: 'https://example.test/routine.png')
          ],
          onOpenDiscovery: (_, item) async {
            expect((item.target as RoutineRecommendationTarget).routineId,
                'published-1');
            opens++;
          },
        )))));
    await t.pumpAndSettle();
    expect(find.text('Explore routines'), findsOneWidget);
    final cover = find.byType(AspectRatio);
    expect(t.widget<AspectRatio>(cover).aspectRatio, closeTo(16 / 9, .001));
    expect(
        t
            .widget<Image>(
                find.descendant(of: cover, matching: find.byType(Image)))
            .fit,
        BoxFit.cover);
    expect(find.text('Real published catalog title'), findsOneWidget);
    expect(t.getTopLeft(find.text('Beginner')).dy,
        greaterThan(t.getBottomLeft(cover).dy));
    expect(find.text('Dismiss'), findsNothing);
    expect(find.text('New recommendation'), findsNothing);
    await t.ensureVisible(find.text('Preview Routine'));
    await t.tap(find.text('Preview Routine'));
    await t.pumpAndSettle();
    expect(opens, 1);
    expect(t.takeException(), isNull);
  });
  testWidgets('pull to refresh reloads an empty page and catalog', (t) async {
    var feedReads = 0;
    var catalogReads = 0;
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.build(),
      home: Scaffold(
          body: MemberRecommendationsView(
        pageScrollable: true,
        repository: RpcMemberRecommendationRepository(
            scope: SessionScope(userId: 'm1', organizationId: 'gym1'),
            isCurrent: () => true,
            invoke: (_) async => routineDetail()),
        isCurrent: () => true,
        onOpenTarget: (_, __) async {},
        loadPage: ({required bool history, String? afterId}) async {
          expect(history, isFalse);
          feedReads++;
          return MemberRecommendationPage(records: []);
        },
        loadDiscovery: () async {
          catalogReads++;
          return [];
        },
      )),
    ));
    await t.pumpAndSettle();
    expect(find.text('History'), findsNothing);
    expect(find.text('Refresh'), findsNothing);
    expect(feedReads, 1);
    expect(catalogReads, 1);
    await t.dragFrom(const Offset(180, 150), const Offset(0, 360));
    await t.pumpAndSettle();
    expect(feedReads, 2);
    expect(catalogReads, 2);
  });

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('routine card and filters wrap at $width text $scale',
          (t) async {
        t.view.physicalSize = Size(width, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final repository = RpcMemberRecommendationRepository(
            scope: SessionScope(userId: 'm1', organizationId: 'gym1'),
            isCurrent: () => true,
            invoke: (_) async => routineDetail());
        await t.pumpWidget(MaterialApp(
            theme: AppTheme.build(),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: Scaffold(
                body: SingleChildScrollView(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: MemberRecommendationsView(
                          repository: repository,
                          isCurrent: () => true,
                          onOpenTarget: (_, __) async {},
                          loadPage: (
                                  {required bool history,
                                  String? afterId}) async =>
                              MemberRecommendationPage(records: [
                            MemberRecommendationDetail.parse(
                                routineDetail(), 'gym1', 'r1')
                          ]),
                        ))))));
        await t.pumpAndSettle();
        expect(find.text('Routines'), findsOneWidget);
        expect(find.text('Tutorials'), findsOneWidget);
        expect(find.text('Coaches'), findsOneWidget);
        expect(find.textContaining('20 min'), findsOneWidget);
        expect(find.textContaining('4 exercises'), findsOneWidget);
        expect(find.text('Preview Routine'), findsOneWidget);
        await t.ensureVisible(find.text('Tutorials'));
        await t.tap(find.text('Tutorials'));
        await t.pumpAndSettle();
        expect(find.text('Build your strength'), findsNothing);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      });
    }
  }
}
