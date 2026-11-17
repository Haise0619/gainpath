import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/app/member_typography_theme.dart';
import 'package:gainpath_mobile/features/recommendation/application/member_recommendation_repository.dart';
import 'package:gainpath_mobile/features/recommendation/application/published_recommendation_suggestion.dart';
import 'package:gainpath_mobile/features/recommendation/presentation/member/member_recommendations_view.dart';
import 'package:gainpath_mobile/features/recommendation/presentation/member/member_recommendation_sheet.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/routine_screen.dart';
import '../../../test_support/fyp_render_support.dart';
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;
import 'member_recommendation_navigation_test.dart'
    show contentDetail, RecommendationCatalog;
import 'member_recommendation_repository_test.dart' show memberDetail;
import 'module13_member_routine_test.dart' show routineDetail;

/// Synthetic transport fixtures rendered with the actual production widgets.
/// Loaded media uses existing project artwork through a test-only HTTP client.
/// The coach photo is project artwork used as a synthetic fixture.
void main() {
  testWidgets('Module 13 Member actual Flutter renders', (t) async {
    await t.runAsync(loadDemoRenderFonts);
    addTearDown(await installFypOfflineFonts());
    final artwork = await t.runAsync(() async => {
          'routine.png':
              await File('assets/images/workout_hero_gym.png').readAsBytes(),
          'tutorial.png': await File('assets/images/workout_hub_fallback.png')
              .readAsBytes(),
        });
    debugNetworkImageHttpClientProvider = () => _RenderImageClient(artwork!);
    addTearDown(() => debugNetworkImageHttpClientProvider = null);
    final dir = Directory('../../build/module13-ai/evidence')
      ..createSync(recursive: true);
    final scope = SessionScope(userId: 'm1', organizationId: 'gym1');
    final measurements = <Map<String, Object>>[];
    final rows = [
      {
        ...routineDetail(),
        'imageUrl': 'https://render.gainpath.invalid/routine.png',
        'targetLabel': 'Full Body Foundations',
        'summary':
            'A 20-minute beginner routine fits your strength goal and builds on your recent Squat practice.',
        'explanations': [
          'Keep a steady training rhythm with four focused exercises.'
        ],
        'aiMethod': 'gemini'
      },
      {
        ...contentDetail(),
        'imageUrl': 'https://render.gainpath.invalid/tutorial.png',
        'recommendationId': 'r2',
        'targetLabel': 'Squat technique essentials',
        'difficulty': 'Beginner',
        'summary':
            'Build confidence with your recent Squat sessions by reviewing controlled depth and balance.',
        'explanations': [
          'Practice the published setup cues before your next session.'
        ],
        'aiMethod': 'gemini'
      },
      {
        ...memberDetail(),
        'recommendationId': 'r3',
        'targetLabel': 'Coach Alex',
        'photoPath':
            'orgs/gym1/coachProfilePhotos/c1/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        'specialization': 'Strength & beginner technique',
        'branchLabel': 'Main Branch',
        'priceMinor': 8000,
        'currency': 'MYR',
        'summary':
            'Get practical strength guidance that supports your beginner goal and recent training rhythm.',
        'explanations': [
          'A verified coach can help you review your next training step.'
        ],
        'aiMethod': 'rule_fallback'
      },
    ];
    final details = rows
        .map((raw) => MemberRecommendationDetail.parse(
            raw, 'gym1', raw['recommendationId'] as String))
        .toList();
    final repository = RpcMemberRecommendationRepository(
        scope: scope,
        isCurrent: () => true,
        invoke: (q) async => rows
            .firstWhere((r) => r['recommendationId'] == q['recommendationId']));
    for (final width in [320.0, 390.0]) {
      for (final scale in [1.0, 2.0]) {
        for (final stage in [
          'routines',
          'tutorials',
          'coaches',
          'details',
          'general',
          'fallback',
          'loading',
          'error',
          'preview'
        ]) {
          t.view.physicalSize = Size(width, 844);
          t.view.devicePixelRatio = 1;
          final key = GlobalKey();
          Widget body;
          if (stage == 'details') {
            body = MemberRecommendationSheet(
                recommendationId: 'r1',
                repository: repository,
                isCurrent: () => true,
                onOpenTarget: (_, __) async {});
          } else if (stage == 'preview') {
            body = RoutineScreen(
                organizationId: 'gym1',
                publishedRoutine: RecommendationCatalog(scope).routine,
                onStartWorkout: () {});
          } else {
            body = SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: MemberRecommendationsView(
                    repository: repository,
                    isCurrent: () => true,
                    onSettings: () {},
                    onOpenTarget: (_, __) async {},
                    photoBuilder: (_, __) => Image.asset(
                        'assets/images/workout_hub_fallback.png',
                        fit: BoxFit.cover,
                        alignment: Alignment.centerRight),
                    loadDiscovery: stage == 'general'
                        ? () async => [
                              const PublishedRecommendationSuggestion(
                                  kind: RecommendationKind.routine,
                                  target: RoutineRecommendationTarget(
                                      'gym1', 'routine1'),
                                  title: 'Full Body Foundations',
                                  difficulty: 'Beginner',
                                  durationMinutes: 20,
                                  exerciseCount: 4)
                            ]
                        : null,
                    onOpenDiscovery: (_, __) async {},
                    loadPage: ({required bool history, String? afterId}) async {
                      if (stage == 'loading') {
                        return Completer<MemberRecommendationPage>().future;
                      }
                      if (stage == 'error') {
                        throw StateError('Synthetic connection failure');
                      }
                      return MemberRecommendationPage(
                          records: stage == 'general'
                              ? []
                              : stage == 'fallback'
                                  ? [
                                      MemberRecommendationDetail.parse(
                                          {...rows.first, 'imageUrl': null},
                                          'gym1',
                                          'r1')
                                    ]
                                  : details);
                    }));
          }
          final loadWatch = Stopwatch()..start();
          await t.pumpWidget(RepaintBoundary(
              key: key,
              child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: buildMemberTypographyTheme(),
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                          textScaler: TextScaler.linear(scale),
                          disableAnimations: true),
                      child: child!),
                  home: stage == 'preview'
                      ? body
                      : Scaffold(
                          appBar:
                              AppBar(title: const Text('Recommended for You')),
                          body: SafeArea(child: body)))));
          if (stage == 'loading') {
            await t.pump(const Duration(milliseconds: 200));
          } else {
            await t.runAsync(() async {
              for (final name in ['routine.png', 'tutorial.png']) {
                await precacheImage(
                    NetworkImage('https://render.gainpath.invalid/$name'),
                    key.currentContext!);
              }
              await precacheImage(
                  const AssetImage('assets/images/workout_hub_fallback.png'),
                  key.currentContext!);
            });
            await t.pumpAndSettle();
          }
          loadWatch.stop();
          measurements.add({
            'stage': stage,
            'width': width,
            'textScale': scale,
            'firstSettledFrameMilliseconds': loadWatch.elapsedMilliseconds
          });
          final filter = switch (stage) {
            'routines' => 'Routines',
            'tutorials' => 'Tutorials',
            'coaches' => 'Coaches',
            _ => null
          };
          if (filter != null) {
            await t.tap(find.text(filter));
            await t.pumpAndSettle();
          }
          final scroll =
              t.state<ScrollableState>(find.byType(Scrollable).first);
          var part = 0;
          while (true) {
            expect(t.takeException(), isNull,
                reason: '$stage $width text $scale');
            await t.runAsync(() async {
              final rendered = await (key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
              final bytes =
                  await rendered.toByteData(format: ui.ImageByteFormat.png);
              await File(
                      '${dir.path}/member-$stage-${width.toInt()}-${(scale * 100).round()}-$part.png')
                  .writeAsBytes(bytes!.buffer.asUint8List());
              rendered.dispose();
            });
            if (stage == 'loading' ||
                scroll.position.pixels >= scroll.position.maxScrollExtent) {
              break;
            }
            scroll.position.jumpTo((scroll.position.pixels + 500)
                .clamp(0, scroll.position.maxScrollExtent));
            await t.pumpAndSettle();
            part++;
          }
          await t.pumpWidget(const SizedBox());
        }
      }
    }
    await t.runAsync(() => File('${dir.path}/member-render-performance.json')
            .writeAsString(const JsonEncoder.withIndent('  ').convert({
          'method':
              'Actual Flutter widget first settled frame with in-memory recommendation transport and offline project artwork. Loading uses its first 200ms simulated frame.',
          'scope':
              'Synthetic desktop widget timing. Firebase/network latency and physical Android performance require live acceptance.',
          'measurements': measurements,
        })));
    debugNetworkImageHttpClientProvider = null;
    t.view.reset();
  }, skip: !const bool.fromEnvironment('GAINPATH_RENDER_MODULE13_AI'));
}

class _RenderImageClient implements HttpClient {
  _RenderImageClient(this.artwork);
  final Map<String, Uint8List> artwork;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _RenderImageRequest(artwork[url.pathSegments.last]!);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RenderImageRequest implements HttpClientRequest {
  _RenderImageRequest(this.bytes);
  final Uint8List bytes;
  @override
  Future<HttpClientResponse> close() async => _RenderImageResponse(bytes);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RenderImageResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _RenderImageResponse(this.bytes);
  final Uint8List bytes;
  @override
  int get statusCode => HttpStatus.ok;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.value(bytes).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
