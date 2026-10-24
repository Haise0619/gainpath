import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_admin_web/features/identity/presentation/admin/coach_review_overview.dart';
import 'coach_directory_publication_flow_test.dart' show AdminFake;

void main() {
  testWidgets(
      'review comparison keeps profile fields and eligibility readable at narrow widths',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = AdminFake(SessionScope(userId: 'admin', organizationId: 'org'))
      ..seed();
    final review = await repo.loadReview('coach');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: CoachReviewOverview(review: review)))));
    expect(find.text('Draft profile'), findsOneWidget);
    expect(find.text('Published profile'), findsOneWidget);
    expect(find.text('Reviewable bio'), findsOneWidget);
    expect(find.text('Not published yet'), findsWidgets);
    expect(find.textContaining('Approval does not publish'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('missing draft explains why publication is blocked',
      (tester) async {
    final review = CoachPublicationReview(
        coachId: 'coach',
        draft: null,
        publication: null,
        branchIds: [],
        targetMembershipEligible: false);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: CoachReviewOverview(review: review)))));
    expect(find.textContaining('Draft missing'), findsOneWidget);
    expect(find.textContaining('Membership unavailable'), findsOneWidget);
    expect(find.textContaining('approved certification'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
