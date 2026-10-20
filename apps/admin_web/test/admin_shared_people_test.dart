import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/app/di/admin_presentation_dependencies.dart';
import 'package:gainpath_admin_web/features/identity/presentation/admin/coach_review_discard_guard.dart';
import 'package:gainpath_admin_web/features/identity/presentation/admin/coaches_screen.dart';
import 'package:gainpath_admin_web/features/identity/presentation/admin/members_screen.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_data/identity.dart';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';

const _testSession = AuthSession(
  userId: 'people-admin',
  organizationId: 'people-org',
  branchIds: ['b1'],
  displayName: 'People Admin',
  email: 'admin@people.org',
  role: AppRole.admin,
);

class _TestMembers implements AdminMemberDirectoryRepository {
  @override
  Future<AdminMemberDetails> loadDetails(String memberId) async =>
      throw UnimplementedError();

  @override
  Future<AdminMemberPage> loadPage({
    String query = '',
    String status = 'All',
    String? afterId,
  }) async {
    return AdminMemberPage(const [
      AdminMemberRecord(
        id: 'm1',
        name: 'Jane Doe',
        email: 'jane@example.test',
        status: 'active',
      ),
      AdminMemberRecord(
        id: 'm2',
        name: 'John Smith',
        email: 'john@example.test',
        status: 'pending',
      ),
    ]);
  }
}

class _TestCoachAdminRepo implements CoachProfileAdminRepository {
  _TestCoachAdminRepo(
      {this.allowed = true,
      this.includePublic = false,
      this.reviewPublication = false});
  final bool allowed, includePublic, reviewPublication;
  int draftReads = 0;
  final reviewedIds = <String>[];
  final mutations = <CoachDirectoryAction>[];
  PublishedCoachProfile publication(String id) => PublishedCoachProfile(
        id: id,
        fields: fields,
        revision: 1,
        sourceRevision: 1,
        status: 'published',
        branchIds: const ['b2'],
        createdAtMillis: 1000,
        updatedAtMillis: 2000,
        publishedAtMillis: 2000,
      );
  @override
  SessionScope get scope => _testSession.scope;

  final fields = CoachProfessionalFields(
    displayName: 'Fixture Coach',
    specialty: 'Strength & Conditioning',
    bio: 'Reviewable coach biography',
    specializationTags: ['Strength'],
    yearsExperience: 5,
  );

  @override
  Future<bool> canManageDirectory() async => allowed;

  @override
  Future<CoachDirectoryPage<CoachProfessionalProfile>> loadDraftPage(
      {String? afterId}) async {
    draftReads++;
    return CoachDirectoryPage([
      CoachProfessionalProfile(
        id: 'coach-1',
        fields: fields,
        revision: 1,
        createdAtMillis: 1000,
        updatedAtMillis: 2000,
      ),
    ]);
  }

  @override
  Future<CoachDirectoryPage<PublishedCoachProfile>> loadPublicPage(
      {String? afterId}) async {
    return CoachDirectoryPage(includePublic ? [publication('coach-2')] : []);
  }

  @override
  Future<CoachPublicationReview> loadReview(String coachId) async {
    reviewedIds.add(coachId);
    return CoachPublicationReview(
      coachId: coachId,
      draft: CoachProfessionalProfile(
        id: coachId,
        fields: fields,
        revision: 1,
        createdAtMillis: 1000,
        updatedAtMillis: 2000,
      ),
      publication: reviewPublication ? publication(coachId) : null,
      branchIds: const ['b1'],
      targetMembershipEligible: true,
      certificationVerified: true,
      approvedCertificationCount: 1,
    );
  }

  @override
  Future<CoachCommandResult> setStatus({
    required CoachPublicationReview baseline,
    required CoachDirectoryAction action,
    required String requestId,
  }) async {
    mutations.add(action);
    return CoachCommandResult(
      requestId: requestId,
      coachId: baseline.coachId,
      revision: 2,
      outcome: 'published',
    );
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('People - MembersScreen', () {
    testWidgets(
        'renders loaded members and enforces read-only constraints in live mode',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final members = _TestMembers();

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<AdminMemberDirectoryRepository>.value(
              value: members,
            ),
            RepositoryProvider<UserAccountRepository>.value(
              value: NeutralUserAccountRepository(session: _testSession),
            ),
          ],
          child: const MaterialApp(
            home: MembersScreen(live: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Members on page'), findsOneWidget);
      expect(
        find.text('Organization membership records · Read-only directory'),
        findsOneWidget,
      );
      expect(find.text('Jane Doe'), findsOneWidget);
      expect(find.text('John Smith'), findsOneWidget);
      expect(find.text('jane@example.test'), findsOneWidget);

      // Verify destructive / provisioning action buttons are NOT present in live mode
      expect(find.text('Suspend account'), findsNothing);
      expect(find.text('Provision member'), findsNothing);
    });
  });

  group('People - CoachesScreen', () {
    Future<void> pumpCoaches(WidgetTester tester,
        {required bool live,
        _TestCoachAdminRepo? repository,
        CoachReviewDiscardGuard? guard,
        void Function(String)? onOpenBookings,
        void Function(String)? onOpenSchedule}) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MultiRepositoryProvider(
          providers: [
            RepositoryProvider<CoachProfileAdminRepository>.value(
                value: repository ?? _TestCoachAdminRepo()),
            RepositoryProvider<UserAccountRepository>.value(
                value: InMemoryUserAccountRepository()),
            RepositoryProvider<CoachRepository>.value(
                value: InMemoryCoachRepository()),
          ],
          child: MaterialApp(
              home: CoachesScreen(
                  live: live,
                  discardGuard: guard,
                  onOpenBookings: onOpenBookings,
                  onOpenSchedule: onOpenSchedule))));
      await tester.pumpAndSettle();
    }

    test('coach source contains one canonical page body', () {
      final source =
          File('lib/features/identity/presentation/admin/coaches_screen.dart')
              .readAsStringSync();
      expect(RegExp(r'\bScaffold\s*\(').allMatches(source), hasLength(1));
      expect(RegExp(r'\bbody\s*:').allMatches(source), hasLength(1));
      expect(RegExp(r'\bSingleChildScrollView\s*\(').allMatches(source),
          hasLength(1));
    });

    for (final live in [false, true]) {
      testWidgets(
          'same canonical stat chips and branch-card layout for ${live ? 'loaded' : 'sample'} coaches',
          (tester) async {
        await pumpCoaches(tester, live: live);
        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.byKey(const ValueKey('coaches-page')), findsOneWidget);
        expect(
            find.byWidgetPredicate(
                (widget) => widget.runtimeType.toString() == '_StatChip'),
            findsNWidgets(2));
        expect(find.textContaining('Total coaches'), findsOneWidget);
        expect(find.textContaining('Pending review'), findsOneWidget);
        expect(
            find.byWidgetPredicate(
                (widget) => widget.runtimeType.toString() == '_CoachCard'),
            findsWidgets);
        final add = tester
            .widget<FilledButton>(find.byKey(const ValueKey('add-coach')));
        expect(add.onPressed == null, live);
        if (live) {
          expect(find.byKey(const ValueKey('coach-branch-Unassigned')),
              findsOneWidget);
          expect(find.text('- sessions'), findsOneWidget);
          expect(find.text('0 sessions'), findsNothing);
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
        'public branch groups and review actions use stable IDs when display names match',
        (tester) async {
      final repository = _TestCoachAdminRepo(includePublic: true);
      await pumpCoaches(tester, live: true, repository: repository);
      expect(find.text('Fixture Coach'), findsNWidgets(2));
      expect(find.byKey(const ValueKey('coach-card-Unassigned-coach-1')),
          findsOneWidget);
      expect(
          find.byKey(const ValueKey('coach-card-b2-coach-2')), findsOneWidget);
      final publicCard = find.byKey(const ValueKey('coach-card-b2-coach-2'));
      await tester
          .tap(find.descendant(of: publicCard, matching: find.text('Review')));
      await tester.pumpAndSettle();
      expect(repository.reviewedIds, ['coach-2']);
      expect(find.text('Review coach-2'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('coach-card-b1-coach-2')), findsOneWidget);
    });

    testWidgets(
        'review details preserve read controls and guard refresh and publication mutations',
        (tester) async {
      final repository = _TestCoachAdminRepo(reviewPublication: true);
      final guard = CoachReviewDiscardGuard();
      final bookings = <String>[], schedules = <String>[];
      await pumpCoaches(tester,
          live: true,
          repository: repository,
          guard: guard,
          onOpenBookings: bookings.add,
          onOpenSchedule: schedules.add);
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      expect(find.text('Publish profile'), findsOneWidget);
      expect(find.text('Deactivate directory profile'), findsOneWidget);
      var guardChecks = 0;
      guard.confirm = () async {
        guardChecks++;
        return false;
      };
      final reads = repository.draftReads;
      for (final label in [
        'Publish profile',
        'Deactivate directory profile',
        'Discard and reload review',
        'View bookings',
        'View schedule'
      ]) {
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.byTooltip('Refresh Coaches'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Refresh Coaches'));
      await tester.pumpAndSettle();
      expect(guardChecks, 6);
      expect(repository.draftReads, reads);
      expect(repository.reviewedIds, ['coach-1']);
      expect(repository.mutations, isEmpty);
      expect(bookings, isEmpty);
      expect(schedules, isEmpty);
      guard.confirm = () async => true;
      for (final label in ['View bookings', 'View schedule']) {
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      expect(bookings, ['coach-1']);
      expect(schedules, ['coach-1']);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'denied directory remains canonical without reading drafts or falling back to sample coaches',
        (tester) async {
      final repository = _TestCoachAdminRepo(allowed: false);
      await pumpCoaches(tester, live: true, repository: repository);
      expect(repository.draftReads, 0);
      expect(find.text('Canonical organization Admin access is required.'),
          findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(
          find.byWidgetPredicate(
              (widget) => widget.runtimeType.toString() == '_CoachCard'),
          findsNothing);
      expect(
          tester
              .widget<FilledButton>(find.byKey(const ValueKey('add-coach')))
              .onPressed,
          isNull);
      expect(find.text('Fixture Coach'), findsNothing);
    });
  });
}
