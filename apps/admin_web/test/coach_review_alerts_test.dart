import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_admin_web/features/identity/presentation/admin/admin_notification_button.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_admin_web/features/identity/application/coach_review_alerts_cubit.dart';
import 'coach_directory_publication_flow_test.dart' show AdminFake;
import 'package:gainpath_domain/gainpath_domain.dart';

class Pages extends AdminFake {
  Pages() : super(SessionScope(userId: 'admin', organizationId: 'org')) {
    seed();
  }
  final seen = <String?>[];
  bool eligible = true;
  @override
  Future<CoachDirectoryPage<CoachProfessionalProfile>> loadDraftPage(
      {String? afterId}) async {
    seen.add(afterId);
    return afterId == null
        ? CoachDirectoryPage([], nextCursor: 'page2')
        : CoachDirectoryPage([draft!]);
  }

  @override
  Future<CoachPublicationReview> loadReview(String id) async =>
      CoachPublicationReview(
          coachId: id,
          draft: draft,
          publication: publication,
          branchIds: ['main'],
          targetMembershipEligible: eligible);
}

void main() {
  test(
      'finds unpublished draft beyond first page, then clears after publication',
      () async {
    final repo = Pages(), cubit = CoachReviewAlertsCubit(repo);
    await cubit.refresh();
    expect(repo.seen, [null, 'page2']);
    expect(cubit.state.items.map((a) => a.coachId), ['coach']);
    repo.publication = PublishedCoachProfile(
        id: 'coach',
        fields: repo.fields,
        revision: 1,
        sourceRevision: 1,
        status: 'published',
        branchIds: ['main'],
        createdAtMillis: 1,
        updatedAtMillis: 2,
        publishedAtMillis: 2);
    await cubit.refresh();
    expect(cubit.state.items, isEmpty);
    await cubit.close();
  });
  test('inactive fixture is excluded; revoked Admin loses all pending content',
      () async {
    final repo = Pages(), cubit = CoachReviewAlertsCubit(repo);
    repo.eligible = false;
    await cubit.refresh();
    expect(cubit.state.items, isEmpty);
    repo.eligible = true;
    await cubit.refresh();
    expect(cubit.state.items, hasLength(1));
    repo.allowed = false;
    await cubit.refresh();
    expect(cubit.state.items, isEmpty);
    expect(cubit.state.error, isNotNull);
    await cubit.close();
  });
  test('new edit of an already published profile needs review again', () async {
    final repo = Pages();
    repo.publication = PublishedCoachProfile(
        id: 'coach',
        fields: repo.fields,
        revision: 1,
        sourceRevision: 1,
        status: 'published',
        branchIds: ['main'],
        createdAtMillis: 1,
        updatedAtMillis: 2,
        publishedAtMillis: 2);
    repo.draft = CoachProfessionalProfile(
        id: 'coach',
        fields: repo.fields,
        revision: 2,
        createdAtMillis: 1,
        updatedAtMillis: 3);
    final edited = CoachReviewAlertsCubit(repo);
    await edited.refresh();
    expect(edited.state.items, hasLength(1));
    await edited.close();
  });
  testWidgets('live bell opens the pending Coach review target',
      (tester) async {
    final repo = Pages();
    String? selected;
    await tester
        .pumpWidget(RepositoryProvider<CoachProfileAdminRepository>.value(
            value: repo,
            child: MaterialApp(
                home: Scaffold(
                    appBar: AppBar(actions: [
              AdminNotificationButton(
                scope: 'coach-only',
                onOpen: (notice) async {
                  selected = notice.id;
                  return true;
                },
              )
            ])))));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Profile changes awaiting Admin publication'),
        findsOneWidget);
    await tester.tap(find.text('Fixture Coach'));
    await tester.pumpAndSettle();
    expect(selected, 'coach');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('bell keeps working sources visible and tracks read revisions',
      (tester) async {
    var failSupport = true;
    var refundTime = 3;
    AdminNotification? selected;
    await tester.pumpWidget(
      RepositoryProvider<CoachProfileAdminRepository>.value(
        value: Pages(),
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(actions: [
              AdminNotificationButton(
                scope: 'combined-feed',
                onOpen: (notice) async {
                  selected = notice;
                  return true;
                },
                loadRefunds: () async => [
                  AdminNotification(AdminNotificationKind.refund, 'payment-1',
                      'Basic renewal', 'Refund awaiting review', refundTime),
                ],
                loadSupport: () async {
                  if (failSupport) throw StateError('Unavailable');
                  return const [
                    AdminNotification(AdminNotificationKind.support, 'ticket-1',
                        'Membership issue', 'Billing', 5),
                  ];
                },
              ),
            ]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Could not refresh support requests.'), findsOneWidget);
    expect(find.text('Fixture Coach'), findsOneWidget);
    expect(find.text('Basic renewal'), findsOneWidget);
    await tester.tap(find.text('Mark all as read'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Unread'), findsNothing);

    failSupport = false;
    refundTime++;
    await tester.tap(find.byTooltip('Refresh notifications'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Unread'), findsNWidgets(2));
    expect(find.text('Could not refresh support requests.'), findsNothing);
    await tester.tap(find.text('Membership issue'));
    await tester.pumpAndSettle();
    expect(selected?.kind, AdminNotificationKind.support);
    expect(selected?.id, 'ticket-1');
    expect(find.text('1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
