import '../../../test_support/fyp_render_support.dart';
import 'support/module13_demo_render.dart';
import 'package:gainpath_mobile/app/member_typography_theme.dart';

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/browse_coaches_screen.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/widgets/coach_card.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/free_coaches_preview.dart';

PublishedCoachProfile _coach({
  String id = 'coach-1',
  String name = 'Jackson Alexander',
  String specialty = 'Strength',
  int fee = 12000,
  int experience = 5,
  double rating = 4.8,
  int reviews = 15,
}) =>
    PublishedCoachProfile(
      id: id,
      fields: CoachProfessionalFields(
        displayName: name,
        specialty: specialty,
        bio:
            'Certified strength and conditioning coach with 5 years experience.',
        specializationTags: [specialty, 'Powerlifting'],
        yearsExperience: experience,
        consultationFeeMinor: fee,
      ),
      revision: 1,
      sourceRevision: 1,
      status: 'published',
      branchIds: ['branch_1'],
      createdAtMillis: 1000,
      updatedAtMillis: 1000,
      publishedAtMillis: 1000,
      certificationVerified: true,
      approvedCertificationCount: 1,
      averageRating: rating,
      reviewCount: reviews,
    );

class _TestDirectoryRepository implements CoachDirectoryRepository {
  _TestDirectoryRepository({required this.coaches})
      : scope = SessionScope(userId: 'test-user', organizationId: 'test-org');

  @override
  final SessionScope scope;
  final List<PublishedCoachProfile> coaches;

  @override
  Future<CoachDirectoryPage<PublishedCoachProfile>> loadPage(
      {String? afterId}) async {
    return CoachDirectoryPage(coaches);
  }

  @override
  Future<PublishedCoachProfile?> loadPublished(String id) async =>
      coaches.firstWhere((c) => c.id == id, orElse: () => coaches.first);
}

void main() {
  setUpAll(loadDemoRenderFonts);
  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('coach preview renders at $width and $scale text', (t) async {
        addTearDown(await installFypOfflineFonts());
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = Size(width, 1100);
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final capture = GlobalKey();
        await t.pumpWidget(MaterialApp(
          theme: buildMemberTypographyTheme(),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: RepaintBoundary(
              key: capture,
              child: BrowseCoachesScreen(
                live: true,
                liveRepository: _TestDirectoryRepository(coaches: [_coach()]),
                isCurrent: () => true,
                enforceMembership: true,
                membershipAccessRepository: _Access('denied'),
              )),
        ));
        await t.pumpAndSettle();
        expect(find.byType(FreeCoachesPreview), findsOneWidget);
        expect(t.takeException(), isNull);
        final boundary = capture.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        await t.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/coach-preview-renders')
              .create(recursive: true);
          await File(
                  'build/coach-preview-renders/coach-${width.toInt()}-$scale.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      });
    }
  }
  for (final outcome in ['denied', 'unknown', 'allowed']) {
    testWidgets('$outcome membership keeps coach access boundary', (t) async {
      addTearDown(await installFypOfflineFonts());
      var opened = 0;
      await t.pumpWidget(MaterialApp(
          theme: buildMemberTypographyTheme(),
          home: BrowseCoachesScreen(
            live: true,
            liveRepository: _TestDirectoryRepository(coaches: [_coach()]),
            isCurrent: () => true,
            enforceMembership: true,
            membershipAccessRepository: _Access(outcome),
            onOpenPublished: (_) {
              opened++;
            },
            bookingsBuilder: (_) => const Text('Existing bookings'),
          )));
      await t.pumpAndSettle();
      expect(find.byType(FreeCoachesPreview),
          outcome == 'denied' ? findsOneWidget : findsNothing);
      expect(find.byType(CoachCard),
          outcome == 'unknown' ? findsNothing : findsOneWidget);
      if (outcome != 'unknown') {
        await t.tap(find.text('Jackson Alexander'), warnIfMissed: false);
        expect(opened, outcome == 'allowed' ? 1 : 0);
      }
      await t.tap(find.text('My Bookings'));
      await t.pumpAndSettle();
      expect(find.text('Existing bookings'), findsOneWidget);
    });
  }
  testWidgets('empty published directory has an honest locked preview',
      (t) async {
    addTearDown(await installFypOfflineFonts());
    var plans = 0;
    await t.pumpWidget(MaterialApp(
        theme: buildMemberTypographyTheme(),
        home: Scaffold(
            body: SingleChildScrollView(
          child: FreeCoachesPreview(
              coaches: const [],
              onViewPlans: () async {
                plans++;
              }),
        ))));
    await t.pumpAndSettle();
    expect(find.text('No published coaches available yet.'), findsOneWidget);
    await t.ensureVisible(find.text('View membership plans'));
    await t.tap(find.text('View membership plans'));
    expect(plans, 1);
  });
}

class _Access implements MembershipAccessRepository {
  _Access(this.outcome);
  final String outcome;
  @override
  bool current = true;
  @override
  Future<MembershipAccessDecision> check(
          MembershipAccessFeature feature, String resourceId) async =>
      MembershipAccessDecision.fromJson({
        'schemaVersion': 1,
        'policyVersion': 'gainpath-membership-access-v1',
        'organizationId': 'o',
        'memberId': 'm',
        'resolvedAtMillis': 1800000000000,
        'feature': feature.name,
        'resourceId': resourceId,
        'effectiveTier': outcome == 'unknown'
            ? null
            : outcome == 'allowed'
                ? 'basic'
                : 'free',
        'requiredTier': 'basic',
        'decision': outcome,
        'reason': 'paid_tier_required',
      },
          organizationId: 'o',
          memberId: 'm',
          feature: feature,
          resourceId: resourceId);
}
