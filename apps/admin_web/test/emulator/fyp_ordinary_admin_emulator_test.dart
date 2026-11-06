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
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:http/io_client.dart';
import 'package:gainpath_admin_web/app/admin_app.dart';
import 'package:gainpath_admin_web/app/shells/admin_shell.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_admin_reporting_gateway.dart';
import '../../../../test_support/fyp_emulator_gateway.dart';
import '../../../../test_support/fyp_render_support.dart';
import '../../../../test_support/fyp_widget_waits.dart';
import '../../../mobile/test/support/signed_out_firebase.dart';
import '../support/module13_demo_render.dart' show loadDemoRenderFonts;

class _Members implements AdminMemberDirectoryRepository {
  _Members(this.scope, this.gateway);
  final SessionScope scope;
  final FypEmulatorGateway gateway;
  AdminMemberRecord parse(String id, Map<String, Object?> row) =>
      AdminMemberRecord(
          id: id,
          name: row['displayName'] as String,
          email: row['email'] as String,
          status: row['status'] as String);
  @override
  Future<AdminMemberPage> loadPage(
          {String query = '', String status = 'All', String? afterId}) async =>
      AdminMemberPage((await gateway.query(scope.dataRootPath, 'members',
              where: {'role': 'member'}, limit: 100))
          .map((e) => parse(e.key, e.value))
          .toList());
  @override
  Future<AdminMemberDetails> loadDetails(String memberId) async {
    final row =
        await gateway.document('${scope.dataRootPath}/members/$memberId');
    return AdminMemberDetails(
        member: parse(memberId, row),
        organizationId: scope.organizationId,
        branchIds: List<String>.from(row['branchIds'] as List));
  }
}

class _Coaches implements CoachProfileAdminRepository {
  _Coaches(this.scope, this.gateway);
  @override
  final SessionScope scope;
  final FypEmulatorGateway gateway;
  @override
  Future<bool> canManageDirectory() async {
    final membership =
        await gateway.document('${scope.dataRootPath}/members/${scope.userId}');
    return membership['role'] == 'admin' && membership['status'] == 'active';
  }

  @override
  Future<CoachDirectoryPage<CoachProfessionalProfile>> loadDraftPage(
          {String? afterId}) async =>
      CoachDirectoryPage(
          (await gateway.query(scope.dataRootPath, 'coachProfiles'))
              .map((e) => CoachProfessionalProfile.fromDocument(
                  e.key, Map<String, dynamic>.from(e.value)))
              .toList());
  @override
  Future<CoachDirectoryPage<PublishedCoachProfile>> loadPublicPage(
          {String? afterId}) async =>
      CoachDirectoryPage((await gateway.query(scope.dataRootPath, 'coaches'))
          .map((e) => PublishedCoachProfile.fromDocument(
              e.key, Map<String, dynamic>.from(e.value)))
          .toList());
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('No mutation in ordinary read acceptance');
}

void main() {
  setUpAll(setUpSignedOutFirebase);
  setUpAll(loadDemoRenderFonts);
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'ordinary Admin login uses only authorized dataset dashboard management and recommendation UI',
      (tester) async {
    final disposeFonts = await installFypOfflineFonts();
    addTearDown(disposeFonts);
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
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const key = ValueKey('ordinary-fyp-admin');
    // Paint only after observing the supported result. Unrelated loaders
    // and chart animation are not readiness conditions.
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
        child: fypOfflineChartFonts(GainPathAdminWebApp.injected(
          authRepository: auth,
          datasetTransportFactory: gateway.transport,
          memberDirectoryFactory: (scope, current) => _Members(scope, gateway),
          coachRepositoryFactory: (scope, current) => _Coaches(scope, gateway),
          reportingGatewayFactory: (scope, current) {
            final transport = gateway.transport(scope, current);
            return FirebaseAdminReportingGateway(
                scope: scope,
                isCurrent: current,
                currentUid: () => gateway.current?.userId,
                invoke: (data) =>
                    transport.call('module/adminReportingCommand', data),
                workoutInvoke: (data) =>
                    transport.call('module/adminWorkoutReportingCommand', data),
                checkInInvoke: (data) => transport.call(
                    'module/adminCheckInReportingCommand', data));
          },
        ))));
    await settle();
    final fields = find.byType(TextField);
    await tester.enterText(
        fields.at(0), 'demo-m13-admin@gainpath-demo.invalid');
    await tester.enterText(
        fields.at(1), Platform.environment['FYP_EMULATOR_PASSWORD']!);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await waitForFypWidget(tester, find.byType(AdminShell),
        description: 'Ordinary authenticated Admin shell',
        diagnostics: () =>
            'actual Auth HTTP=${gateway.authSignInRequests}, protected dataset session HTTP=${gateway.protectedSessionRequests}');
    await settle();
    expect(find.byType(AdminShell), findsOneWidget);
    expect(gateway.authSignInRequests, 1);
    expect(gateway.protectedSessionRequests, 1);
    debugPrint(
        '[fyp-admin-ui] actual Auth password requests=1 protected dataset session requests=1');
    expect(gateway.current?.datasetScope?.rootPath,
        'orgs/gainpath/cohorts/fyp-v1');
    final scope = authSession(gateway);
    final activeMembers = await tester.runAsync(() => gateway.query(
        scope.dataRootPath, 'members',
        where: {'role': 'member', 'status': 'active'}, limit: 100));
    final memberKpi = find.byWidgetPredicate((widget) =>
        widget.runtimeType.toString() == '_KpiCard' &&
        (widget as dynamic).label == 'Current active Members' &&
        (widget as dynamic).value == '${activeMembers!.length}');
    await waitForFypWidget(tester, memberKpi,
        description: 'Actual scoped active-Member report KPI');
    await settle();
    await capture('ordinary-admin-dashboard');
    await tester.tap(find.text('Members').first);
    await waitForFypWidget(tester, find.text('Demo Learner 01'),
        description: 'Actual scoped Member management row');
    await settle();
    expect(
        (await tester.runAsync(
                () => _Members((authSession(gateway)), gateway).loadPage()))!
            .items,
        hasLength(18));
    await capture('ordinary-admin-members');
    await tester.tap(find.text('Coaches').first);
    await settle();
    expect(
        (await tester.runAsync(() =>
                _Coaches(authSession(gateway), gateway).loadPublicPage()))!
            .items,
        hasLength(8));
    final coaches =
        await tester.runAsync(() => _Coaches(scope, gateway).loadPublicPage());
    await waitForFypWidget(
        tester, find.text(coaches!.items.first.fields.displayName),
        description: 'Actual scoped Coach management row');
    await settle();
    await capture('ordinary-admin-coaches');
    await tester.tap(find.text('Recommendations').first);
    await settle();
    await capture('ordinary-admin-recommendations');
    for (final tab in ['Trainer Matching', 'Content Recommendations']) {
      await tester.tap(find.text(tab).first);
      await waitForFypWidget(tester, find.text('Demo Learner 02'),
          description: 'Actual scoped pending $tab lead');
      await settle();
      final learner = find.text('Demo Learner 02');
      expect(learner, findsOneWidget);
      final card =
          find.ancestor(of: learner, matching: find.byType(Panel)).first;
      final details =
          find.descendant(of: card, matching: find.text('View details'));
      await tester.ensureVisible(details);
      await tester.tap(details);
      await waitForFypWidget(tester, find.byType(AdminDialog),
          description: 'Current Admin review dialog');
      await settle();
      expect(find.byType(AdminDialog), findsOneWidget);
      await capture(tab == 'Trainer Matching'
          ? 'ordinary-admin-trainer-review'
          : 'ordinary-admin-tutorial-review');
      await tester.tap(find.text('Close').last);
      await settle();
      final send = find.descendant(of: card, matching: find.text('Send'));
      await tester.ensureVisible(send);
      await tester.tap(send);
      await waitForFypWidget(tester, find.text('Confirm Send'),
          description: 'Explicit Admin Send confirmation');
      await settle();
      await tester.tap(find.text('Confirm Send').last);
      await waitForFypWidget(
          tester, find.text('Sent to the fictional Member inbox.'),
          description: 'Confirmed fictional inbox delivery');
      await settle();
      expect(find.text('Sent to the fictional Member inbox.'), findsOneWidget);
      // Delivery completes before the ordinary panel reloads its queue. Wait
      // for that real response too, rather than disposing an in-flight HTTP
      // request (and its timeout timer) when the success notice appears.
      await waitForFypWidget(tester, find.text('Demo Learner 03'),
          description: 'Refreshed queue after confirmed delivery');
    }
  }, skip: Platform.environment['FYP_EMULATOR_PASSWORD'] == null);
}

SessionScope authSession(FypEmulatorGateway gateway) => SessionScope(
    userId: gateway.current!.userId,
    organizationId: 'gainpath',
    datasetScope: gateway.current!.datasetScope);
