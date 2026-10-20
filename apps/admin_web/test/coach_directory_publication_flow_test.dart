import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_admin_web/app/admin_app.dart';
import 'package:gainpath_admin_web/features/identity/application/coach_directory_admin_cubit.dart';

class _EmptyPhotoAccount extends Fake implements AdminAccountContactRepository {
  @override
  Future<Uint8List?> loadCurrentPhoto() async => null;
}

class AdminFake implements CoachProfileAdminRepository {
  AdminFake(this.scope);
  @override
  final SessionScope scope;
  bool allowed = true;
  String? failure;
  CoachRepositoryException? customException;
  Object? loadFailure;
  bool certificationVerified = true;
  int approvedCertificationCount = 1;
  final requests = <String>[];
  final fields = CoachProfessionalFields(
      displayName: 'Fixture Coach',
      specialty: 'Strength',
      bio: 'Reviewable bio',
      specializationTags: ['Strength'],
      yearsExperience: null);
  CoachProfessionalProfile? draft;
  PublishedCoachProfile? publication;
  void seed() {
    draft = CoachProfessionalProfile(
        id: 'coach',
        fields: fields,
        revision: 1,
        createdAtMillis: 1,
        updatedAtMillis: 2);
  }

  @override
  Future<bool> canManageDirectory() async => allowed;
  @override
  Future<CoachDirectoryPage<CoachProfessionalProfile>> loadDraftPage(
          {String? afterId}) async {
    if (loadFailure != null) throw loadFailure!;
    return CoachDirectoryPage(draft == null ? [] : [draft!]);
  }
  @override
  Future<CoachDirectoryPage<PublishedCoachProfile>> loadPublicPage(
          {String? afterId}) async =>
      CoachDirectoryPage(publication == null ? [] : [publication!]);
  @override
  Future<CoachPublicationReview> loadReview(String coachId) async =>
      CoachPublicationReview(
          coachId: coachId,
          draft: draft,
          publication: publication,
          branchIds: ['main'],
          targetMembershipEligible: true,
          certificationVerified: certificationVerified,
          approvedCertificationCount: approvedCertificationCount);
  @override
  Future<CoachCommandResult> setStatus(
      {required CoachPublicationReview baseline,
      required CoachDirectoryAction action,
      required String requestId}) async {
    requests.add(requestId);
    if (customException != null) throw customException!;
    if (failure != null) throw CoachRepositoryException(failure!);
    publication = PublishedCoachProfile(
        id: baseline.coachId,
        fields: draft?.fields ?? publication!.fields,
        revision: baseline.publicRevision + 1,
        sourceRevision: draft?.revision ?? publication!.sourceRevision,
        status:
            action == CoachDirectoryAction.publish ? 'published' : 'inactive',
        branchIds: ['main'],
        createdAtMillis: 1,
        updatedAtMillis: 3,
        publishedAtMillis: 3);
    return CoachCommandResult(
        requestId: requestId,
        coachId: baseline.coachId,
        revision: publication!.revision,
        outcome: publication!.status);
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  test('unsupported stored schema directs Admin to the stable main entry', () async {
    final repo = AdminFake(SessionScope(userId: 'admin', organizationId: 'o'))
      ..seed()
      ..loadFailure = const FormatException('Unsupported public Coach profile.');
    final cubit = CoachDirectoryAdminCubit(repo);
    await cubit.refresh();
    expect(cubit.state.message, contains('http://localhost:7359/'));
    expect(cubit.state.allowed, isFalse);
    repo.loadFailure = null;
    await cubit.refresh();
    expect(cubit.state.drafts, hasLength(1));
    expect(cubit.state.allowed, isTrue);
    await cubit.close();
  });
  test(
      'Admin retries stable intent; conflict blocks mutation until fresh review; staff denied',
      () async {
    final repo = AdminFake(SessionScope(userId: 'admin', organizationId: 'o'))
      ..seed();
    final cubit = CoachDirectoryAdminCubit(repo);
    await cubit.refresh();
    await cubit.review('coach');
    repo.failure = 'unavailable';
    await cubit.setStatus(CoachDirectoryAction.publish);
    await cubit.setStatus(CoachDirectoryAction.publish);
    expect(repo.requests[0], repo.requests[1]);
    repo.failure = 'aborted';
    await cubit.setStatus(CoachDirectoryAction.publish);
    final count = repo.requests.length;
    await cubit.setStatus(CoachDirectoryAction.deactivate);
    expect(repo.requests.length, count);
    repo.failure = null;
    await cubit.review('coach');
    await cubit.setStatus(CoachDirectoryAction.publish);
    expect(repo.publication!.isPublished, isTrue);
    repo.failure = 'permission-denied';
    await cubit.setStatus(CoachDirectoryAction.deactivate);
    expect(cubit.state.allowed, isFalse);
    expect(cubit.state.review, isNull);
    repo.allowed = false;
    await cubit.refresh();
    expect(cubit.state.allowed, isFalse);
    expect(cubit.state.review, isNull);
    await cubit.close();
  });
  testWidgets(
      'Firebase Admin reviews/publishes then withdraws a public-only profile; no account-management mocks',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = InMemoryAuthRepository();
    final session = await auth.signIn(
        role: AppRole.admin, email: 'admin@example.test', password: 'fixture');
    final repo = AdminFake(session.scope)..seed();
    await tester.pumpWidget(GainPathAdminWebApp(
        authRepository: auth,
        backendConfig: const BackendConfig(BackendMode.firebase),
        accountContactFactory: (_, __) => _EmptyPhotoAccount(),
        coachRepositoryFactory: (_, current) => repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coaches').last);
    await tester.pumpAndSettle();
    expect(
        tester.widget<FilledButton>(
            find.byKey(const ValueKey('add-coach'))).onPressed,
        isNull);
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publish profile'));
    await tester.pumpAndSettle();
    expect(repo.publication!.isPublished, isTrue);
    repo.draft = null;
    await tester.tap(find.byTooltip('Refresh Coaches'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Publish profile'))
            .onPressed,
        isNull);
    await tester.tap(find.text('Deactivate directory profile'));
    await tester.pumpAndSettle();
    expect(repo.publication!.status, 'inactive');
    await auth.signOut();
    await tester.pumpAndSettle();
    expect(find.text('Reviewable bio'), findsNothing);
  });

  test(
      'revoking last approved certification removes BR-5 publication eligibility and re-approving restores it',
      () async {
    final repo = AdminFake(SessionScope(userId: 'admin', organizationId: 'o'))
      ..seed();
    final cubit = CoachDirectoryAdminCubit(repo);
    await cubit.refresh();
    await cubit.review('coach');
    expect(cubit.state.review!.canPublish, isTrue);

    // Revocation drops approved count to 0 and verified to false
    repo.certificationVerified = false;
    repo.approvedCertificationCount = 0;
    await cubit.review('coach');
    expect(cubit.state.review!.certificationVerified, isFalse);
    expect(cubit.state.review!.approvedCertificationCount, 0);
    expect(cubit.state.review!.canPublish, isFalse);

    // Publication attempt is blocked
    await cubit.setStatus(CoachDirectoryAction.publish);
    expect(repo.publication, isNull);

    // Restoring decision (approving) restores BR-5 eligibility
    repo.certificationVerified = true;
    repo.approvedCertificationCount = 1;
    await cubit.review('coach');
    expect(cubit.state.review!.canPublish, isTrue);
    await cubit.setStatus(CoachDirectoryAction.publish);
    expect(repo.publication!.isPublished, isTrue);

    await cubit.close();
  });

  test(
      'cubit filters out unsafe exception messages and preserves safe domain explanations',
      () async {
    final repo = AdminFake(SessionScope(userId: 'admin', organizationId: 'o'))
      ..seed();
    final cubit = CoachDirectoryAdminCubit(repo);
    await cubit.refresh();
    await cubit.review('coach');

    // Unsafe message with internal path or sensitive token is sanitized
    repo.customException = const CoachRepositoryException(
        'failed-precondition', 'Error at orgs/o1/coachProfiles/c1 with token secret_xyz');
    await cubit.setStatus(CoachDirectoryAction.publish);
    expect(cubit.state.message, isNot(contains('secret_xyz')));
    expect(cubit.state.message, isNot(contains('orgs/')));
    expect(cubit.state.message, 'Profile or account eligibility needs review.');

    // Allowlisted message is preserved verbatim
    repo.customException = const CoachRepositoryException(
        'failed-precondition', 'An approved certification is required for publication.');
    await cubit.setStatus(CoachDirectoryAction.publish);
    expect(
        cubit.state.message, 'An approved certification is required for publication.');

    await cubit.close();
  });
}
