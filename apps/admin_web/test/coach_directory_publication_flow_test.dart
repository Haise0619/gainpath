import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_admin_web/app/admin_app.dart';
import 'package:gainpath_admin_web/features/identity/application/coach_directory_admin_cubit.dart';

class AdminFake implements CoachProfileAdminRepository {
  AdminFake(this.scope);
  @override
  final SessionScope scope;
  bool allowed = true;
  String? failure;
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
          {String? afterId}) async =>
      CoachDirectoryPage(draft == null ? [] : [draft!]);
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
          targetMembershipEligible: true);
  @override
  Future<CoachCommandResult> setStatus(
      {required CoachPublicationReview baseline,
      required CoachDirectoryAction action,
      required String requestId}) async {
    requests.add(requestId);
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
        coachRepositoryFactory: (_, current) => repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coaches').last);
    await tester.pumpAndSettle();
    expect(find.text('Add a coach'), findsNothing);
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
}
