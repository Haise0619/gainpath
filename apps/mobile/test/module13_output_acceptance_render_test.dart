import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_identity/gainpath_identity.dart';

import 'package:gainpath_mobile/app/notifications/member_recommendation_navigator.dart';
import 'package:gainpath_mobile/app/routing/exercise_tutorial_route.dart';
import 'package:gainpath_mobile/app/routing/routine_journey_route.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/routine_screen.dart';
import 'member_recommendation_navigation_test.dart'
    show RecommendationCatalog, RecommendationDirectory, RecommendationTestAuth;
import 'package:gainpath_domain/gainpath_domain.dart'
    show SessionScope, AuthSession, AppRole;
import 'package:gainpath_mobile/app/member_typography_theme.dart';
import 'package:gainpath_mobile/features/recommendation/application/member_recommendation_repository.dart';
import 'package:gainpath_mobile/features/recommendation/presentation/member/member_recommendations_view.dart';
import 'package:gainpath_mobile/features/recommendation/presentation/member/member_recommendation_sheet.dart';
import '../../../test_support/fyp_render_support.dart';
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;

/// Exported responses from the approved production test account.
/// These are Flutter widget captures, with device acceptance reported separately.
void main() {
  testWidgets('actual saved Tutorial and Routine open existing routes',
      (t) async {
    addTearDown(await installFypOfflineFonts());
    final raw = jsonDecode(
        File('../../build/module13-output-fix/acceptance-result.private.json')
            .readAsStringSync()) as Map;
    final publications = jsonDecode(
        File('../../build/module13-output-fix/destinations.private.json')
            .readAsStringSync()) as Map;
    const session = AuthSession(
        userId: 'm13-e2e-20261117',
        organizationId: 'gainpath',
        email: 'gainpath.m13.e2e.20261117@example.test',
        role: AppRole.member,
        branchIds: ['main']);
    final source = RecommendationTestAuth(session);
    final auth = AuthBloc(repository: source);
    await t.pump();
    addTearDown(auth.close);
    addTearDown(source.dispose);
    for (final row in (raw['records'] as List).cast<Map>().where(
        (row) => row['saved']['suggestion']['target']['kind'] != 'trainer')) {
      final resolved = Map<String, Object?>.from(row['resolved'] as Map);
      final kind = row['saved']['suggestion']['target']['kind'];
      final target = row['saved']['suggestion']['target'] as Map;
      final id = (kind == 'routine'
          ? target['routineId']
          : target['destination']['routineId']) as String;
      final catalog = RecommendationCatalog(session.scope)
        ..routine = PublishedRoutine.fromDocument(
            id, Map<String, dynamic>.from(publications[id] as Map));
      final repository = RpcMemberRecommendationRepository(
          scope: session.scope,
          isCurrent: () => true,
          fixtureOnly: false,
          invoke: (_) async => resolved);
      final navigator = MemberRecommendationNavigator(
          session: session,
          repository: repository,
          isCurrent: () => true,
          catalog: catalog,
          coachDirectory: RecommendationDirectory(session.scope));
      final detail = MemberRecommendationDetail.parse(
          resolved, 'gainpath', row['id'] as String);
      await t.pumpWidget(BlocProvider.value(
          value: auth,
          child: MaterialApp(
            theme: buildMemberTypographyTheme(),
            home: Builder(
                builder: (context) => Scaffold(
                      body: TextButton(
                          onPressed: () =>
                              unawaited(navigator.open(context, detail)),
                          child: const Text('Open saved target')),
                    )),
          )));
      await t.tap(find.text('Open saved target'));
      await t.pumpAndSettle();
      if (kind == 'routine') {
        expect(find.byType(RoutineScreen), findsOneWidget);
        await t.tap(find.text('Start Workout'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
        expect(find.byType(RoutineJourneyRoute), findsOneWidget);
        expect(
            t
                .widget<RoutineJourneyRoute>(find.byType(RoutineJourneyRoute))
                .routine
                .id,
            id);
      } else {
        expect(find.byType(ExerciseTutorialRoute), findsOneWidget);
      }
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    }
  }, skip: !const bool.fromEnvironment('GAINPATH_RENDER_M13_LIVE_E2E'));
  testWidgets('saved production recommendations render in Member widgets',
      (t) async {
    addTearDown(await installFypOfflineFonts());
    await t.runAsync(loadDemoRenderFonts);
    final raw = jsonDecode(
        File('../../build/module13-output-fix/acceptance-result.private.json')
            .readAsStringSync()) as Map;
    final records = (raw['records'] as List).cast<Map>();
    final mediaFile =
        File('../../build/module13-output-fix/media.private.json');
    if (mediaFile.existsSync()) {
      final media = jsonDecode(mediaFile.readAsStringSync()) as Map;
      for (final item in (media['files'] as Map).values.cast<Map>()) {
        if (item['url'] is! String) continue;
        await t.runAsync(() async {
          final codec = await ui.instantiateImageCodec(
              File(item['file'] as String).readAsBytesSync());
          final frame = await codec.getNextFrame();
          PaintingBinding.instance.imageCache.putIfAbsent(
            NetworkImage(item['url'] as String),
            () => OneFrameImageStreamCompleter(
                Future.value(ImageInfo(image: frame.image))),
          );
          codec.dispose();
        });
      }
    }
    expect(records.length, 1);
    final scope =
        SessionScope(userId: 'm13-e2e-20261117', organizationId: 'gainpath');
    final repository = RpcMemberRecommendationRepository(
      scope: scope,
      isCurrent: () => true,
      fixtureOnly: false,
      invoke: (query) async => records.firstWhere(
          (row) => row['id'] == query['recommendationId'])['resolved'],
    );
    t.view.physicalSize = const Size(390, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final directory = Directory('../../build/module13-output-fix/screenshots')
      ..createSync(recursive: true);
    for (final row in records) {
      final detail = MemberRecommendationDetail.parse(
          Map<String, Object?>.from(row['resolved'] as Map),
          'gainpath',
          row['id'] as String);
      for (final showDetails in [false, true]) {
        final key = GlobalKey();
        await t.pumpWidget(RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildMemberTypographyTheme(),
              home: Scaffold(
                appBar: AppBar(
                    title: Text(showDetails
                        ? 'Recommendation details'
                        : 'Recommended for You')),
                body: showDetails
                    ? MemberRecommendationSheet(
                        recommendationId: detail.recommendationId,
                        repository: repository,
                        isCurrent: () => true,
                        onOpenTarget: (_, __) async {},
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Module 13 TEST'),
                            const SizedBox(height: 16),
                            RecommendationCard(
                                detail: detail,
                                onOpen: () {},
                                onDetails: () {}),
                          ],
                        )),
              ),
            )));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.runAsync(() async {
          final image = await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final name = 'member-' +
              detail.kind.name +
              '-' +
              (showDetails ? 'details' : 'card') +
              '.png';
          await File(directory.path + '/' + name)
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
  }, skip: !const bool.fromEnvironment('GAINPATH_RENDER_M13_LIVE_E2E'));
}
