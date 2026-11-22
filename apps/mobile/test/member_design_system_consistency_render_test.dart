import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_mobile/app/home/member_home_screen.dart';
import 'package:gainpath_mobile/app/member_typography_theme.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/browse_coaches_screen.dart';
import 'package:gainpath_mobile/features/gamification/application/app_check_in_cubit.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/gamification_dashboard_screen.dart';
import 'package:gainpath_mobile/features/identity/presentation/member/account_settings_screen.dart';
import 'package:gainpath_mobile/features/identity/presentation/member/member_profile_screen.dart';
import 'package:gainpath_mobile/features/workout/application/published_routine_catalog_cubit.dart';
import 'package:gainpath_mobile/features/workout/application/workout_hub_program.dart';
import 'package:gainpath_mobile/features/workout/data/published_routine.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_attempt.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/published_routine_catalog_controls.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_prep_screen.dart';
import '../../../test_support/fyp_render_support.dart';
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;
import 'member_coach_ux_test.dart' show MemberDirectoryFake;

class _FakeAuthBloc extends Fake implements AuthBloc {
  _FakeAuthBloc(this.state);
  final _controller = StreamController<AuthState>.broadcast();

  @override
  AuthState state;

  @override
  Stream<AuthState> get stream => _controller.stream;

  @override
  Future<void> close() async {
    await _controller.close();
  }
}

class _MockPreferencesRepository implements MemberPreferencesRepository {
  @override
  final scope = SessionScope(userId: 'member1', organizationId: 'gym1');
  MemberPreferences value = const MemberPreferences(
    pushNotifications: true,
    emailUpdates: false,
    voiceCoaching: true,
  );

  @override
  Future<MemberPreferences> load() async => value;

  @override
  Future<void> save(MemberPreferences preferences) async {
    value = preferences;
  }
}

class _MockContactRepository
    implements MemberContactDetailsRepository, MemberDisplayNameRepository {
  MemberContactDetails details = const MemberContactDetails(
    displayName: 'Alex Zheng',
    value: '+60 12-345 6789',
    editBaseline: 1,
  );

  @override
  Future<MemberContactDetails> load() async => details;

  @override
  Future<MemberContactDetails> save(
      MemberContactDetails original, String value) async {
    return details = MemberContactDetails(
      displayName: details.displayName,
      value: value,
      editBaseline: 2,
    );
  }

  @override
  Future<MemberContactDetails> saveDisplayName(
      MemberContactDetails original, String value) async {
    return details = MemberContactDetails(
      displayName: value,
      value: details.value,
      editBaseline: 3,
    );
  }
}

MemberAccountLifecycle _makeLifecycle({bool pending = false}) =>
    MemberAccountLifecycle(
      state: pending ? 'pendingDeletion' : 'active',
      revision: pending ? 1 : 0,
      requestedAtMillis: pending ? 1000000 : null,
      retentionEndsAtMillis: pending ? 2593000000 : null,
      policy: pending ? 'grace30Days' : 'pendingApproval',
      sessionNotBeforeSeconds: pending ? 1001 : 0,
      sessionRevocationPending: false,
      reactivationAllowed: false,
      reactivationAvailableAtMillis: pending ? 4900000 : null,
      currentTimeMillis: 1200000,
      lastRequestId: pending ? 'request_0001' : null,
      editBaseline: Object(),
    );

class _MockLifecycleRepository implements MemberAccountLifecycleRepository {
  MemberAccountLifecycle current = _makeLifecycle();

  @override
  Future<MemberAccountLifecycle> load() async => current;

  @override
  Future<void> verifyCurrentPassword(String password) async {}

  @override
  Future<MemberAccountLifecycle> requestDeactivation(
      MemberAccountLifecycle original) async {
    return current = _makeLifecycle(pending: true);
  }

  @override
  Future<MemberAccountLifecycle> cancelDeactivation(
      MemberAccountLifecycle original) async {
    return current = _makeLifecycle(pending: false);
  }
}

void main() {
  setUpAll(loadDemoRenderFonts);

  const testSession = AuthSession(
    userId: 'member1',
    organizationId: 'gym1',
    email: 'alex@gainpath.test',
    displayName: 'Alex Zheng',
    role: AppRole.member,
  );

  PublishedRoutine testRoutine() => PublishedRoutine.fromDocument('routine1', {
        'schemaVersion': 1,
        'kind': 'routine',
        'status': 'published',
        'sourceBlueprintId': 'blueprint1',
        'title': 'Full Body Foundations',
        'estimatedMinutes': 30,
        'exercises': [
          {
            'exerciseId': 'burpee',
            'name': 'Burpee',
            'sets': 1,
            'reps': 40,
            'category': 'Cardio',
          },
          {
            'exerciseId': 'dumbbell_shoulder_press_front_v1',
            'name': 'Dumbbell Shoulder Press',
            'sets': 1,
            'reps': 8,
            'category': 'Shoulders',
          },
          {
            'exerciseId': 'squat',
            'name': 'Squat',
            'sets': 1,
            'reps': 10,
            'category': 'Legs',
          },
        ],
      });

  Future<void> saveScreenshot(
      Key key, WidgetTester tester, String filename) async {
    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/member-ui-renders/$filename');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Widget wrapWithTheme({
    required Widget child,
    required Key key,
    double textScale = 1.0,
  }) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildMemberTypographyTheme(),
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: RepaintBoundary(
          key: key,
          child: c!,
        ),
      ),
      home: child,
    );
  }

  testWidgets('Render Home Page with unified typography & section headers',
      (tester) async {
    final restore = await installFypOfflineFonts();
    addTearDown(restore);

    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(wrapWithTheme(
      key: key,
      child: MemberHomeScreen(
        liveSession: testSession,
        liveProfile: FitnessProfile(
          gender: ProfileGender.unspecified,
          age: 26,
          heightCm: 175,
          weightKg: 70,
          experience: TrainingExperience.beginner,
          activity: ActivityLevel.moderatelyActive,
          goals: {FitnessGoal.buildMuscle},
        ),
        publishedRoutine: testRoutine(),
        appCheckIn: const AppCheckInState(
          status: AppCheckInStatus.ready,
          message: 'Checked in today',
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await saveScreenshot(key, tester, 'v2_home_page_unified.png');
  });

  testWidgets('Render Workout Prep Page with unified cards and exercises',
      (tester) async {
    final restore = await installFypOfflineFonts();
    addTearDown(restore);

    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final routine = testRoutine();
    final attempt = RoutineAttempt(
      id: 'attempt-1',
      scope: SessionScope(userId: 'member1', organizationId: 'gym1'),
      routine: routine,
      day: 1,
      finished: false,
      updatedAtMicros: 1000,
      entries: [
        RoutineExerciseResult(
          index: 0,
          status: RoutineExerciseStatus.skipped,
          sessionIds: [],
          fullRepetitions: 0,
          partialRepetitions: 0,
          trackedDurationMicros: 0,
          manualSets: 0,
        ),
      ],
    );

    final scheduled = ScheduledWorkoutPreview(
      routine: routine,
      day: 1,
      dayKey: 'day-1',
      enrollmentId: 'enrollment-1',
      date: DateTime.utc(2026, 11, 15),
      snapshot: 'Testing snapshot',
      inProgress: true,
      attempt: attempt,
    );

    final key = GlobalKey();
    await tester.pumpWidget(wrapWithTheme(
      key: key,
      child: WorkoutPrepScreen(
        live: true,
        publishedRoutine: routine,
        scheduledWorkout: scheduled,
        organizationId: 'gym1',
        onOpenPrograms: () {},
        onOpenEquipment: () {},
        onBrowseEquipment: () {},
        onOpenProgress: () {},
        onOpenRoutineHistory: () {},
        onOpenSettings: () {},
        routineCatalogControls: PublishedRoutineCatalogControls(
          state: PublishedRoutineCatalogState(
            status: CatalogStatus.ready,
            items: [routine],
            selected: routine,
          ),
          onRefresh: () async {},
          onSelect: (_) {},
          onLoadMore: () async {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await saveScreenshot(key, tester, 'v2_workout_page_unified.png');
  });

  testWidgets('Render Rewards Page with elevated Section Headers',
      (tester) async {
    final restore = await installFypOfflineFonts();
    addTearDown(restore);

    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(
      wrapWithTheme(
        key: key,
        child: const GamificationDashboardScreen(live: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await saveScreenshot(key, tester, 'v2_rewards_page_unified.png');
  });

  testWidgets('Render Browse Coaches Page with unified typography',
      (tester) async {
    final restore = await installFypOfflineFonts();
    addTearDown(restore);

    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(
      wrapWithTheme(
        key: key,
        child: BrowseCoachesScreen(
          live: true,
          liveRepository: MemberDirectoryFake(),
          isCurrent: () => true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await saveScreenshot(key, tester, 'v2_coaches_page_unified.png');
  });

  testWidgets('Render Member Profile Page with clean Eyebrows and summary',
      (tester) async {
    final restore = await installFypOfflineFonts();
    addTearDown(restore);

    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final authBloc = _FakeAuthBloc(
      const AuthState(
        status: AuthStatus.signedIn,
        role: AppRole.member,
        session: testSession,
      ),
    );
    addTearDown(authBloc.close);

    final key = GlobalKey();
    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: wrapWithTheme(
          key: key,
          child: MemberProfileScreen(
            liveSession: testSession,
            liveProfile: FitnessProfile(
              gender: ProfileGender.male,
              age: 26,
              heightCm: 175,
              weightKg: 70,
              experience: TrainingExperience.beginner,
              activity: ActivityLevel.moderatelyActive,
              goals: {FitnessGoal.buildMuscle},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await saveScreenshot(key, tester, 'v2_profile_page_unified.png');
  });

  testWidgets('Render Settings Page with clean Eyebrows and unified cards',
      (tester) async {
    final restore = await installFypOfflineFonts();
    addTearDown(restore);

    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final prefRepo = _MockPreferencesRepository();
    final contactRepo = _MockContactRepository();
    final lifecycleRepo = _MockLifecycleRepository();

    final authBloc = _FakeAuthBloc(
      const AuthState(
        status: AuthStatus.signedIn,
        role: AppRole.member,
        session: testSession,
      ),
    );
    addTearDown(authBloc.close);

    final key = GlobalKey();
    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: wrapWithTheme(
          key: key,
          child: AccountSettingsScreen(
            repository: prefRepo,
            contactSession: testSession,
            contactRepository: contactRepo,
            lifecycleRepository: lifecycleRepo,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await saveScreenshot(key, tester, 'v2_settings_page_unified.png');
  });

  testWidgets('Verify 200% font scaling on Home Page without overflow',
      (tester) async {
    final restore = await installFypOfflineFonts();
    addTearDown(restore);

    tester.view.physicalSize = const Size(360, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(wrapWithTheme(
      key: key,
      textScale: 2.0,
      child: MemberHomeScreen(
        liveSession: testSession,
        publishedRoutine: testRoutine(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull,
        reason: '200% text scale must never cause overflow');
    await saveScreenshot(key, tester, 'v2_home_200pct_font_scale.png');
  });

  testWidgets('Verify narrow screen (320px) without overflow', (tester) async {
    final restore = await installFypOfflineFonts();
    addTearDown(restore);

    tester.view.physicalSize = const Size(320, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(wrapWithTheme(
      key: key,
      child: MemberHomeScreen(
        liveSession: testSession,
        publishedRoutine: testRoutine(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull,
        reason: '320px narrow screen must not overflow');
    await saveScreenshot(key, tester, 'v2_home_320px_narrow.png');
  });
}
