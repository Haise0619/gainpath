import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_domain/content.dart';
import 'package:http/io_client.dart';
import 'package:gainpath_mobile/app/mobile_app.dart';
import 'package:gainpath_mobile/app/home/member_home_screen.dart';
import 'package:gainpath_mobile/app/shells/member_shell.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_catalog_repository.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_fyp_progress_repository.dart';
import 'package:gainpath_mobile/app/routing/exercise_tutorial_route.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/live_coach_directory_views.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/coach_profile_screen.dart';
import '../../../../test_support/fyp_emulator_gateway.dart';
import '../../../../test_support/fyp_render_support.dart';
import '../../../../test_support/fyp_widget_waits.dart';
import '../support/signed_out_firebase.dart';
import '../support/module13_demo_render.dart' show loadDemoRenderFonts;
import '../workout_program_controller_test.dart' show MemoryProgramStore;
import '../routine_journey_controller_test.dart' show MemoryJourneyStore;

class _Profile implements FitnessProfileGateway {
  _Profile(this.gateway);
  final FypEmulatorGateway gateway;
  @override
  Future<Map<String, Object?>?> read(SessionScope scope) =>
      gateway.document('${scope.dataRootPath}/profiles/${scope.userId}');
  @override
  Future<void> write(SessionScope scope, Map<String, Object?> data,
          {required Map<String, Object?>? expectedSnapshot}) =>
      Future.error(UnsupportedError('Read only fixtures'));
}

class _Directory implements CoachDirectoryRepository {
  _Directory(this.scope, this.gateway);
  @override
  final SessionScope scope;
  final FypEmulatorGateway gateway;
  @override
  Future<CoachDirectoryPage<PublishedCoachProfile>> loadPage(
          {String? afterId}) async =>
      CoachDirectoryPage((await gateway.query(scope.dataRootPath, 'coaches',
              where: {'status': 'published'}))
          .map((e) => PublishedCoachProfile.fromDocument(
              e.key, Map<String, dynamic>.from(e.value)))
          .toList());
  @override
  Future<PublishedCoachProfile?> loadPublished(String coachId) async =>
      PublishedCoachProfile.fromDocument(
          coachId,
          Map<String, dynamic>.from(await gateway
              .document('${scope.dataRootPath}/coaches/$coachId')));
}

class _Catalog implements PublishedRoutineCatalogRepository {
  _Catalog(this.scope, this.gateway);
  @override
  final SessionScope scope;
  final FypEmulatorGateway gateway;
  @override
  Future<PublishedRoutinePage> loadPage({String? afterId}) async =>
      PublishedRoutinePage((await gateway.query(scope.dataRootPath, 'content',
              where: {'status': 'published', 'kind': 'routine'}))
          .map((e) => PublishedRoutine.fromDocument(
              e.key, Map<String, dynamic>.from(e.value)))
          .toList());
  @override
  Future<PublishedRoutine?> loadById(String id) async =>
      PublishedRoutine.fromDocument(
          id,
          Map<String, dynamic>.from(
              await gateway.document('${scope.dataRootPath}/content/$id')));
}

class _Announcements implements AnnouncementReader {
  _Announcements(this.scope, this.gateway);
  final SessionScope scope;
  final FypEmulatorGateway gateway;
  @override
  Future<AnnouncementPage> loadAnnouncements({String? afterId}) async {
    final rows = await gateway.query(scope.dataRootPath, 'announcements',
        where: {'status': 'published'});
    return AnnouncementPage(rows
        .map((e) => Announcement(
            id: e.key,
            title: e.value['title'] as String,
            body: e.value['body'] as String,
            validFrom: e.value['validFrom'] as DateTime,
            validTo: e.value['validTo'] as DateTime,
            revision: e.value['revision'] as int))
        .toList());
  }
}

void main() {
  setUpAll(setUpSignedOutFirebase);
  setUpAll(loadDemoRenderFonts);
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'ordinary Member login hydrates actual owned FYP profile progress directory and tutorials',
      (tester) async {
    final disposeFonts = await installFypOfflineFonts();
    addTearDown(disposeFonts);
    final password = Platform.environment['FYP_EMULATOR_PASSWORD'];
    expect(password, isNotEmpty,
        reason: 'Runner supplies ephemeral emulator password');
    final previous = HttpOverrides.current;
    HttpOverrides.global = null;
    final client = IOClient(HttpClient()
      ..idleTimeout = Duration.zero
      ..connectionTimeout = const Duration(seconds: 5));
    final gateway = FypEmulatorGateway(client),
        auth = FirebaseAuthRepository(gateway);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      client.close();
      unawaited(auth.dispose());
      unawaited(gateway.dispose());
      HttpOverrides.global = previous;
    });
    tester.view.physicalSize = const Size(393, 851);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const key = ValueKey('ordinary-fyp-member');
    // Paint only after an observable supported response. Ancillary native
    // SDK loaders and persistent chart animations do not block acceptance.
    Future<void> settle() async {
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)));
        await tester.pump(const Duration(milliseconds: 100));
        final error = tester.takeException();
        if (error != null) throw error;
      }
    }

    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final boundary =
            tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
        final image = await boundary.toImage(),
            bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('../../build/fyp-shared-data/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: fypOfflineChartFonts(GainPathMobileApp.injected(
          authRepository: auth,
          datasetTransportFactory: gateway.transport,
          profileRepositoryFactory: (scope) => FirebaseFitnessProfileRepository(
              scope: scope, gateway: _Profile(gateway)),
          coachDirectoryFactory: (scope, current) => _Directory(scope, gateway),
          routineCatalogFactory: (scope, active) => _Catalog(scope, gateway),
          progressRepositoryFactory: (scope, active) async =>
              FirebaseFypProgressRepository(
                  gateway.transport(scope, () => active() == scope)),
          programStoreFactory: (scope) async => MemoryProgramStore(scope),
          routineJourneyStoreFactory: (scope) async =>
              MemoryJourneyStore(scope),
          announcementReaderFactory: (scope, __) =>
              _Announcements(scope, gateway),
          memberRewardsBuilder: (_) => const SizedBox(),
        ))));
    await settle();
    final fields = find.byType(TextField);
    await tester.enterText(
        fields.at(0), 'demo-m13-member-02@gainpath-demo.invalid');
    await tester.enterText(fields.at(1), password!);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await waitForFypWidget(tester, find.byType(MemberShell),
        description: 'Ordinary authenticated Member shell',
        diagnostics: () =>
            'actual Auth HTTP=${gateway.authSignInRequests}, protected dataset session HTTP=${gateway.protectedSessionRequests}');
    await settle();
    expect(find.byType(MemberHomeScreen), findsOneWidget);
    expect(gateway.authSignInRequests, 1);
    expect(gateway.protectedSessionRequests, 1);
    expect(gateway.current!.userId, 'demo-m13-member-02');
    debugPrint(
        '[fyp-member-ui] actual Auth password requests=1 protected dataset session requests=1');
    expect(gateway.current?.datasetScope?.rootPath,
        'orgs/gainpath/cohorts/fyp-v1');
    final scope = (await auth.restoreSession())!.scope;
    final progress = await pumpFypFuture(
        tester,
        () =>
            FirebaseFypProgressRepository(gateway.transport(scope, () => true))
                .load(),
        description: 'Read owned emulator progress');
    expect(progress.records, isNotEmpty);
    expect(
        progress.summaries.values
            .every((s) => s.provenance.name == 'recordedFixture'),
        isTrue);
    final directory = await pumpFypFuture(
        tester, () => _Directory(scope, gateway).loadPage(),
        description: 'Read scoped Coach directory');
    expect(directory.items, hasLength(7));
    expect(
        (await pumpFypFuture(tester, () => _Catalog(scope, gateway).loadPage(),
                description: 'Read scoped published Tutorial catalog'))
            .items
            .length,
        greaterThanOrEqualTo(12));
    await waitForFypWidget(
        tester,
        find.byWidgetPredicate((widget) =>
            widget is MemberHomeScreen && widget.localProgress != null),
        description: 'Hydrated ordinary Member progress');
    await settle();
    await capture('ordinary-member-home');
    final recent = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_RecentActivitySection');
    final history =
        find.descendant(of: recent, matching: find.text('View all'));
    // Position the link above the existing floating button without a fling
    // whose ballistic scroll could move the target outside the viewport.
    final homeScroll = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView).first)
        .controller!;
    homeScroll.jumpTo((homeScroll.offset + tester.getCenter(history).dy - 400)
        .clamp(0, homeScroll.position.maxScrollExtent));
    await settle();
    expect(history.hitTestable(), findsOneWidget);
    await tester.tap(history);
    await waitForFypWidget(
        tester, find.text('Fictional recorded fixture · read only'),
        description: 'Actual fictional activity timeline records');
    await settle();
    expect(find.text('Activity timeline'), findsOneWidget);
    expect(find.text('Fictional recorded fixture · read only'), findsWidgets);
    await capture('ordinary-member-history');
    await tester.pageBack();
    await settle();
    await tester.tap(find.text('Coaches').last);
    await waitForFypWidget(
        tester, find.text(directory.items.first.fields.displayName),
        description: 'Actual scoped published Coach directory row');
    await settle();
    await capture('ordinary-member-directory');
    await tester.tap(find.text('Profile').last);
    await waitForFypWidget(tester, find.text(gateway.current!.displayName!),
        description: 'Actual scoped Member profile');
    await settle();
    await capture('ordinary-member-profile');
    await tester.tap(find.text('Home').last);
    await settle();
    await tester.ensureVisible(find.byTooltip('Notifications'));
    await tester.tap(find.byTooltip('Notifications'));
    await settle();
    final inbox = await pumpFypFuture(
        tester,
        () => gateway.transport(scope, () => true).map('member.inbox',
            {'schemaVersion': 1, 'organizationId': scope.organizationId}),
        description: 'Read delivered emulator inbox');
    final notices = (inbox['records'] as List).cast<Map>();
    expect(notices, hasLength(2));
    debugPrint('[fyp-member-ui] actual Admin-widget recipient '
        '${gateway.current!.userId}; delivered inbox entries=${notices.length}');
    await waitForFypWidget(tester, find.text(notices.first['title'] as String),
        description:
            'Actual delivered recommendation in ordinary Notification Center');
    await capture('ordinary-member-notifications');
    for (final notice in notices) {
      final entry = find.text(notice['title'] as String).first;
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await waitForFypWidget(
          tester,
          find.byWidgetPredicate((widget) =>
              widget is Text &&
              (widget.data == 'View Coach' || widget.data == 'View Tutorial')),
          description: 'Current recommendation target action');
      await settle();
      final coach = find.text('View Coach').evaluate().isNotEmpty;
      final open = find.text(coach ? 'View Coach' : 'View Tutorial');
      await tester.ensureVisible(open);
      await tester.tap(open);
      await waitForFypWidget(
          tester,
          coach
              ? find.byType(LiveCoachDetailView)
              : find.byType(ExerciseTutorialRoute),
          description: 'Current authorized recommendation destination');
      if (coach) {
        await waitForFypWidget(tester, find.byType(CoachProfileScreen),
            description: 'Current published Coach profile data');
        final currentProfile = tester
            .widget<CoachProfileScreen>(find.byType(CoachProfileScreen))
            .published!;
        expect(
            currentProfile.id,
            tester
                .widget<LiveCoachDetailView>(find.byType(LiveCoachDetailView))
                .coachId);
        expect(currentProfile.fields.displayName, contains('Demo'));
      }
      await settle();
      expect(
          coach
              ? find.byType(LiveCoachDetailView)
              : find.byType(ExerciseTutorialRoute),
          findsOneWidget);
      await capture(coach
          ? 'ordinary-member-current-coach'
          : 'ordinary-member-current-tutorial');
      await tester.pageBack();
      await settle();
      final action =
          find.text(coach ? 'Acknowledge' : 'Dismiss recommendation');
      await tester.ensureVisible(action);
      await tester.tap(action);
      await waitForFypWidget(tester,
          find.text(coach ? 'Acknowledged' : 'Recommendation dismissed.'),
          description: 'Persisted Member recommendation response');
      await settle();
      final close = find.byTooltip('Close recommendation');
      Scrollable.of(tester.element(close)).position.jumpTo(0);
      await settle();
      expect(close.hitTestable(), findsOneWidget);
      await tester.tap(close);
      await settle();
    }
    // Member responses refresh the underlying ordinary inbox asynchronously.
    // Finish those actual requests before disposing the HTTP client/widget.
    for (var i = 0; i < 1200 && gateway.activeCommandRequests != 0; i++) {
      await settle();
    }
    expect(gateway.activeCommandRequests, 0);
  }, skip: Platform.environment['FYP_EMULATOR_PASSWORD'] == null);
}
