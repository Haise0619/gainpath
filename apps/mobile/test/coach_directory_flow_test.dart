import 'support/coach_account_gateway_fake.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_mobile/app/mobile_app.dart';
import 'package:gainpath_mobile/features/identity/presentation/coach/live_coach_profile_views.dart';
import 'package:gainpath_mobile/features/analytics/data/local_member_progress_repository.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'package:gainpath_mobile/features/workout/domain/real_workout_sync.dart';
import 'coach_profile_state_test.dart' show ProfileFake;
import 'support/fitness_profile_fake.dart';
import 'support/coach_availability_fake.dart';

PublishedCoachProfile published(String bio) => PublishedCoachProfile(
    id: 'coach',
    fields: CoachProfessionalFields(
        displayName: 'Real contract Coach',
        specialty: 'Strength',
        bio: bio,
        specializationTags: ['Strength'],
        yearsExperience: null),
    revision: 1,
    sourceRevision: 1,
    status: 'published',
    branchIds: ['main'],
    createdAtMillis: 1,
    updatedAtMillis: 2,
    publishedAtMillis: 2);

class DirectoryFake implements CoachDirectoryRepository {
  DirectoryFake(this.scope);
  @override
  final SessionScope scope;
  PublishedCoachProfile? profile = published('Public bio');
  @override
  Future<CoachDirectoryPage<PublishedCoachProfile>> loadPage(
          {String? afterId}) async =>
      CoachDirectoryPage(profile == null ? [] : [profile!]);
  @override
  Future<PublishedCoachProfile?> loadPublished(String coachId) async =>
      profile?.id == coachId ? profile : null;
}

class DriftingCoachAuth extends InMemoryAuthRepository {
  DriftingCoachAuth(this.current);
  AuthSession? current;
  final changes = StreamController<AuthSession?>.broadcast();
  @override
  Stream<AuthSession?> get sessionChanges => changes.stream;
  @override
  Future<AuthSession?> restoreSession() async => current;
  void drift(AuthSession next) {
    current = next;
    changes.add(next);
  }

  @override
  Future<void> signOut() async {
    current = null;
    changes.add(null);
  }

  @override
  Future<void> dispose() async {
    await changes.close();
    await super.dispose();
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final verification in [false, true]) {
    testWidgets(
        'pushed Coach editor is removed after ${verification ? 'verification' : 'branch'} drift',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const baseline = AuthSession(
          userId: 'coach',
          organizationId: 'o',
          branchIds: ['main'],
          email: 'fixture@example.test',
          role: AppRole.coach);
      final auth = DriftingCoachAuth(baseline), repo = ProfileFake();
      await tester.pumpWidget(GainPathMobileApp.injected(
          authRepository: auth,
          coachProfileFactory: (_, current) => repo,
          coachAccountFactory: (_, current) => CoachAccountGatewayFake()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bio & specialties'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byWidgetPredicate(
              (w) => w is TextField && w.decoration?.labelText == 'Bio'),
          'Old private edit');
      auth.drift(AuthSession(
          userId: baseline.userId,
          organizationId: baseline.organizationId,
          email: baseline.email,
          role: baseline.role,
          branchIds: verification ? baseline.branchIds : ['other'],
          needsVerification: verification));
      // Verification uses an indeterminate progress animation while refreshing.
      // A bounded pump still verifies that private editor state is disposed.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(LiveCoachProfileEditor), findsNothing);
      expect(
          find.byWidgetPredicate((w) =>
              w is EditableText && w.controller.text == 'Old private edit'),
          findsNothing);
      await tester.pumpWidget(const SizedBox());
      await auth.dispose();
    });
  }
  testWidgets(
      'Firebase Coach opens only real profile editing and saves a pending draft',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = InMemoryAuthRepository();
    await auth.signIn(
        role: AppRole.coach, email: 'coach@example.com', password: 'fixture');
    final repo = ProfileFake();
    await tester.pumpWidget(GainPathMobileApp.injected(
        authRepository: auth,
        coachProfileFactory: (_, current) => repo,
        coachAccountFactory: (_, current) => CoachAccountGatewayFake(),
        coachAvailabilityFactory: (_, current) => AvailabilityFake()));
    await tester.pumpAndSettle();
    expect(find.text('Not published in directory'), findsOneWidget);
    await tester.tap(find.text('Bio & specialties'));
    await tester.pumpAndSettle();
    for (final entry in {
      'Display name': 'Fixture Coach',
      'Specialty': 'Strength',
      'Bio': 'Saved draft',
      'Specialization tags (comma separated)': 'Strength'
    }.entries) {
      await tester.enterText(
          find.byWidgetPredicate(
              (w) => w is TextField && w.decoration?.labelText == entry.key),
          entry.value);
    }
    await tester.scrollUntilVisible(find.text('Save profile'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Save profile'));
    await tester.pumpAndSettle();
    expect(repo.profile!.fields.bio, 'Saved draft');
    expect(find.text('Profile saved. Admin publication is required.'),
        findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Not published in directory'), findsOneWidget);
    await tester.tap(find.text('Availability').last);
    await tester.pumpAndSettle();
    expect(find.text('THIS WEEK AT A GLANCE'), findsOneWidget);
    await auth.signOut();
    await tester.pumpAndSettle();
    expect(find.text('Saved draft'), findsNothing);
  });
  testWidgets(
      'Firebase Member reads stable-ID directory/detail/refresh and withdrawal without local activity writes',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = InMemoryAuthRepository(), profiles = FakeProfileGateway();
    final session =
        await auth.signIn(email: 'member@example.test', password: 'fixture');
    await profiles.repository(session.scope).save(sampleProfile());
    final directory = DirectoryFake(session.scope),
        store = InMemoryWorkoutSessionStore(scope: session.scope),
        sync = MemoryRealWorkoutSyncStore(scope: session.scope);
    final before = (await sync.read()).toJson();
    await tester.pumpWidget(GainPathMobileApp.injected(
        authRepository: auth,
        profileRepositoryFactory: profiles.repository,
        routineLoaderFactory: (_) async => null,
        coachDirectoryFactory: (_, current) => directory,
        progressRepositoryFactory: (scope, active) async =>
            StoredLocalMemberProgressRepository(
                scope: scope,
                workoutStore: store,
                syncStore: sync,
                activeScope: active)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coaches').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Real contract Coach'));
    await tester.pumpAndSettle();
    expect(find.text('Public bio'), findsOneWidget);
    directory.profile = published('Updated public bio');
    await tester.tap(find.byTooltip('Refresh profile'));
    await tester.pumpAndSettle();
    expect(find.text('Updated public bio'), findsOneWidget);
    directory.profile = null;
    await tester.tap(find.byTooltip('Refresh profile'));
    await tester.pumpAndSettle();
    expect(find.text('This Coach profile is no longer published.'),
        findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Refresh Coaches'));
    await tester.pumpAndSettle();
    expect(find.text('No coaches available yet.'), findsOneWidget);
    expect(await store.read(), isEmpty);
    expect((await sync.read()).toJson(), before);
  });
}
