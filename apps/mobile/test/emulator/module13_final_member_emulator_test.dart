import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show AuthSession, AppRole, SessionScope;
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_mobile/app/notifications/member_notifications_screen.dart';
import 'package:gainpath_mobile/app/notifications/member_recommendation_navigator.dart';
import 'package:gainpath_mobile/app/routing/exercise_tutorial_route.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/live_coach_directory_views.dart';
import 'package:gainpath_mobile/features/recommendation/application/member_recommendation_repository.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_catalog_repository.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/published_exercise_tutorial_screen.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_module9_repository.dart'
    show parseMemberNotice;
import 'package:google_fonts/google_fonts.dart';
import '../member_recommendation_navigation_test.dart'
    show RecommendationTestAuth;

typedef Rpc = Future<Map<String, Object?>> Function(
    String method, Map<String, Object?> data);

class GatewayInbox implements Module9Repository {
  GatewayInbox(this.rpc);
  final Rpc rpc;
  @override
  Stream<void> watchInbox() => const Stream.empty();
  @override
  Future<NoticePage> loadInbox({String? afterId}) async {
    final raw = await rpc('inbox', {
      'schemaVersion': 1,
      'organizationId': 'gainpath',
      'action': 'inbox',
      if (afterId != null) 'afterId': afterId
    });
    return NoticePage(
        (raw['records'] as List)
            .map((r) => parseMemberNotice(r, 'gainpath'))
            .toList(),
        raw['nextAfterId'] as String?);
  }

  @override
  Future<void> markRead(String id) => throw StateError(
      'Recommendations use the separate durable Member command');
  @override
  Future<CoachSharing> loadSharing() => throw UnimplementedError();
  @override
  Future<CoachSharing> saveSharing(bool enabled, int expectedRevision) =>
      throw UnimplementedError();
  @override
  Future<CoachReport> loadPerformance() => throw UnimplementedError();
}

class GatewayDirectory implements CoachDirectoryRepository {
  GatewayDirectory(this.scope, this.rpc);
  @override
  final SessionScope scope;
  final Rpc rpc;
  @override
  Future<PublishedCoachProfile?> loadPublished(String id) async =>
      PublishedCoachProfile.fromDocument(
          id, Map<String, dynamic>.from(await rpc('coach', {'coachId': id})));
  @override
  Future<CoachDirectoryPage<PublishedCoachProfile>> loadPage(
          {String? afterId}) async =>
      CoachDirectoryPage([]);
}

class GatewayCatalog implements PublishedRoutineCatalogRepository {
  GatewayCatalog(this.scope, this.rpc);
  @override
  final SessionScope scope;
  final Rpc rpc;
  @override
  Future<PublishedRoutine?> loadById(String id) async =>
      PublishedRoutine.fromDocument(id,
          Map<String, dynamic>.from(await rpc('routine', {'routineId': id})));
  @override
  Future<PublishedRoutinePage> loadPage({String? afterId}) async =>
      PublishedRoutinePage([]);
}

/// Explicit opt-in only; no configured Firebase project or production callable.
void main() {
  final enabled =
      Platform.environment['MODULE13_FINAL_GATEWAY'] == '127.0.0.1:18118';
  testWidgets(
      'Member receives actual Admin-approved final records and opens current Coach and tutorial',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final previousHitTestWarning = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() =>
        WidgetController.hitTestWarningShouldBeFatal = previousHitTestWarning);
    final previous = HttpOverrides.current;
    HttpOverrides.global = null;
    final client = HttpClient()
      ..idleTimeout = Duration.zero
      ..connectionTimeout = const Duration(seconds: 5);
    addTearDown(() {
      client.close(force: true);
      HttpOverrides.global = previous;
    });
    Future<Map<String, Object?>> call(
        String role, String method, Map<String, Object?> data) async {
      final request =
          await client.postUrl(Uri.parse('http://127.0.0.1:18118/rpc'));
      request.persistentConnection = false;
      request.headers.contentType = ContentType.json;
      request.headers.set('x-gainpath-fixture-session', 'module13-final-local');
      request.headers.set('x-gainpath-fixture-role', role);
      request.write(jsonEncode({'method': method, 'data': data}));
      final response = await request.close();
      final raw = jsonDecode(await response.transform(utf8.decoder).join());
      if (response.statusCode != 200 || raw is! Map || raw['result'] is! Map) {
        throw StateError('Local synthetic request was not confirmed.');
      }
      return Map<String, Object?>.from(raw['result'] as Map);
    }

    Future<Map<String, Object?>> admin(
            String method, Map<String, Object?> data) async =>
        (await tester.runAsync(() => call('admin', method, data)))!;
    Future<Map<String, Object?>> member(
            String method, Map<String, Object?> data) =>
        call('member', method, data);
    final health = await tester.runAsync(() async {
      final response = await (await client
              .getUrl(Uri.parse('http://127.0.0.1:18118/health')))
          .close();
      return jsonDecode(await response.transform(utf8.decoder).join()) as Map;
    });
    expect(health!['fixtureOnly'], true);
    final notices = Map<String, String>.from(health['notices'] as Map);
    expect(notices.keys.toSet(), {'trainer', 'content'});
    Future<void> settle() async {
      for (var i = 0; i < 400; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)));
        await tester.pump(const Duration(milliseconds: 100));
        final exception = tester.takeException();
        if (exception != null) throw exception;
        if (find.byType(LinearProgressIndicator).evaluate().isEmpty &&
            find.byType(CircularProgressIndicator).evaluate().isEmpty &&
            !tester.binding.hasScheduledFrame) {
          return;
        }
      }
      fail('Local Member operation did not settle');
    }

    Future<void> tap(String text) async {
      final target = find.text(text).first;
      await tester.ensureVisible(target);
      await tester.tap(target);
      await settle();
    }

    const session = AuthSession(
        userId: 'fictional-member',
        organizationId: 'gainpath',
        email: 'fictional-member@example.invalid',
        role: AppRole.member,
        branchIds: ['fictional-branch']);
    final source = RecommendationTestAuth(session);
    final auth = AuthBloc(repository: source);
    await tester.pump();
    addTearDown(auth.close);
    addTearDown(source.dispose);
    bool current() => identical(auth.state.session, session);
    final repository = RpcMemberRecommendationRepository(
        scope: session.scope,
        isCurrent: current,
        invoke: (request) => member('member', request));
    final navigator = MemberRecommendationNavigator(
        session: session,
        repository: repository,
        isCurrent: current,
        coachDirectory: GatewayDirectory(session.scope, member),
        catalog: GatewayCatalog(session.scope, member),
        bookingFactory: (_, __) => throw StateError(
            'Opening a recommendation must not initiate booking'));
    tester.view.physicalSize = const Size(393, 851);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
            home: MemberNotificationsScreen(
                session: session,
                isCurrent: current,
                module9Repository: GatewayInbox(member),
                recommendationRepository: repository,
                onOpenRecommendationTarget: navigator.open))));
    await settle();
    expect(find.text('Synthetic local preview'), findsOneWidget);
    for (final kind in ['trainer', 'content']) {
      final page =
          (await tester.runAsync(() => member('inbox', {'action': 'inbox'})))!;
      final notice = (page['records'] as List)
          .cast<Map>()
          .singleWhere((n) => n['id'] == notices[kind]);
      await tap(notice['title'] as String);
      expect(find.text('View ${kind == 'trainer' ? 'Coach' : 'Tutorial'}'),
          findsOneWidget);
      await tap(kind == 'trainer' ? 'View Coach' : 'View Tutorial');
      if (kind == 'trainer') {
        expect(find.byType(LiveCoachDetailView), findsOneWidget);
        expect(find.text('Fictional Coach Amira'), findsWidgets);
      } else {
        expect(find.byType(ExerciseTutorialRoute), findsOneWidget);
        expect(find.byType(PublishedExerciseTutorialScreen), findsOneWidget);
        expect(
            tester
                .widget<ExerciseTutorialRoute>(
                    find.byType(ExerciseTutorialRoute))
                .exercise
                .tutorial
                .steps,
            isNotEmpty);
      }
      await tester.pageBack();
      await settle();
      await tap(kind == 'trainer' ? 'Acknowledge' : 'Dismiss recommendation');
      expect(
          find.text(
              kind == 'trainer' ? 'Acknowledged' : 'Recommendation dismissed.'),
          findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Close recommendation'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close recommendation'));
      await settle();
    }
    // Current withdrawal prevents a stale Coach destination and clears sensitive detail.
    await admin('withdraw', {'kind': 'trainer'});
    final currentPage =
        (await tester.runAsync(() => member('inbox', {'action': 'inbox'})))!;
    final trainerNotice = (currentPage['records'] as List)
        .cast<Map>()
        .singleWhere((n) => n['id'] == notices['trainer']);
    // Refresh the actual inbox so its redacted current projection is used.
    await tester.tap(find.byTooltip('Refresh'));
    await settle();
    await tap(trainerNotice['title'] as String);
    expect(find.text('View Coach'), findsNothing);
    expect(find.text('This recommendation is currently unavailable.'),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  }, skip: !enabled, timeout: const Timeout(Duration(minutes: 3)));
}
