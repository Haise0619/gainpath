import 'booking_history_coach_fix_test.dart' show bookingJson;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_mobile/app/home/member_home_screen.dart';
import 'package:gainpath_mobile/app/home/member_home_data.dart';
import 'package:gainpath_mobile/features/workout/data/published_routine.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_attempt.dart';
import 'package:gainpath_mobile/features/gamification/application/app_check_in_cubit.dart';
import 'package:gainpath_mobile/features/gamification/domain/app_check_in.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:google_fonts/google_fonts.dart';

const homeSession = AuthSession(
    userId: 'member',
    organizationId: 'gym',
    email: 'alex@example.test',
    displayName: 'Alex',
    role: AppRole.member);
final homeScope = homeSession.scope;
final homeNow = DateTime.now().toUtc();
PublishedRoutine homeRoutine({int reps = 8}) =>
    PublishedRoutine.fromDocument('routine', {
      'schemaVersion': 1,
      'kind': 'routine',
      'status': 'published',
      'sourceBlueprintId': 'blueprint',
      'title': 'Full Body Foundations',
      'estimatedMinutes': 25,
      'exercises': [
        {
          'exerciseId': 'a12345678901234567890',
          'name': 'Dumbbell Squat',
          'sets': 3,
          'reps': reps,
          'category': 'Legs'
        }
      ],
    });
RoutineAttempt homeAttempt(
        {bool finished = false,
        bool completed = false,
        DateTime? at,
        PublishedRoutine? routine,
        SessionScope? scope}) =>
    RoutineAttempt(
        id: 'attempt',
        scope: scope ?? homeScope,
        routine: routine ?? homeRoutine(),
        day: 1,
        finished: finished,
        updatedAtMicros: (at ?? homeNow).microsecondsSinceEpoch,
        finishedAtMicros:
            finished ? (at ?? homeNow).microsecondsSinceEpoch : null,
        entries: [
          RoutineExerciseResult(
              index: 0,
              status: completed
                  ? RoutineExerciseStatus.completed
                  : RoutineExerciseStatus.notStarted,
              sessionIds: const ['capture'],
              fullRepetitions: completed ? 24 : 0,
              partialRepetitions: 0,
              trackedDurationMicros: 1000000,
              manualSets: 0)
        ]);
RoutineProgress homeRoutines(Iterable<RoutineAttempt> attempts) =>
    RoutineProgress(scope: homeScope, attempts: attempts, asOf: homeNow);
MemberLocalProgress homeProgress() => calculateLocalMemberProgress(
    scope: homeScope,
    records: [
      LocalWorkoutProgressRecord(
          scope: homeScope,
          sessionId: 'capture',
          exerciseId: 'a12345678901234567890',
          startedAt: homeNow.subtract(const Duration(minutes: 10)),
          endedAt: homeNow,
          repetitions: 24,
          partialRepetitions: 0,
          trackedDurationMicros: 1000000,
          rejectedDurationMicros: 0,
          formScorePercent: null,
          scoringVersion: 'v1',
          detectorId: 'd',
          detectorVersion: 'v1',
          cameraView: 'front',
          status: LocalWorkoutRecordStatus.pending)
    ],
    asOf: homeNow);
AppCheckInState homeCheckIn({bool claimed = false}) => AppCheckInState(
    status: AppCheckInStatus.ready,
    snapshot: AppCheckInSnapshot(
        scope: homeScope,
        policyVersion: 'app-check-in-v1',
        timezone: 'Asia/Kuala_Lumpur',
        pointsPerClaim: 10,
        balance: 100,
        today: '2026-11-09',
        claimedToday: claimed,
        currentStreak: 3,
        longestStreak: 5,
        totalClaims: 8,
        serverNowMillis: homeNow.millisecondsSinceEpoch,
        nextResetMillis:
            homeNow.add(const Duration(days: 1)).millisecondsSinceEpoch,
        days: List.generate(
            7,
            (i) => AppCheckInDay(
                '2026-11-${(i + 3).toString().padLeft(2, '0')}',
                i < 3 || (i == 6 && claimed))),
        recentClaims: const [],
        badges: const []));
Widget homeTestApp(
        {RoutineProgress? routines,
        AppCheckInState? checkIn,
        VoidCallback? onStart,
        void Function(RoutineAttempt)? onAttempt,
        Future<void> Function()? onClaim,
        double scale = 1,
        Key? captureKey}) =>
    RepaintBoundary(
        key: captureKey,
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(),
            builder: (c, child) => MediaQuery(
                data: MediaQuery.of(c)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: Scaffold(
                bottomNavigationBar: const SizedBox(
                    key: ValueKey('test-bottom-nav'),
                    height: 64,
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Icon(Icons.home),
                          Icon(Icons.fitness_center),
                          Icon(Icons.emoji_events),
                          Icon(Icons.people),
                          Icon(Icons.person)
                        ])),
                body: MemberHomeScreen(
                    liveSession: homeSession,
                    liveProfile: FitnessProfile(
                        gender: ProfileGender.unspecified,
                        age: 25,
                        heightCm: 170,
                        weightKg: 65,
                        experience: TrainingExperience.beginner,
                        activity: ActivityLevel.moderatelyActive,
                        goals: {
                          FitnessGoal.buildMuscle,
                          FitnessGoal.generalFitness
                        }),
                    publishedRoutine: homeRoutine(),
                    routineProgress: routines,
                    localProgress: homeProgress(),
                    appCheckIn: checkIn ?? homeCheckIn(),
                    onAppClaim: onClaim,
                    onStartWorkout: onStart,
                    onOpenRoutine: onAttempt,
                    onOpenPlan: () {},
                    onOpenBookings: () {},
                    onOpenProgress: () {},
                    onOpenEquipment: () {}))));

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'upcoming coaching stays between weekly and activity, scoped to its member and org',
      (t) async {
    t.view.physicalSize = const Size(1000, 2600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final raw = bookingJson('upcoming',
        DateTime.utc(homeNow.year, homeNow.month, homeNow.day + 1, 2, 30))
      ..['organizationId'] = 'gym';
    final record = PersistedBookingRecord.fromJson(raw);
    var opens = 0;
    await t.pumpWidget(MaterialApp(
        home: MemberHomeScreen(
            liveSession: homeSession,
            onLoadUpcomingCoaching: () async => record,
            onOpenBookings: () => opens++)));
    await t.pumpAndSettle();
    expect(find.text('Upcoming coaching'), findsOneWidget);
    expect(t.getTopLeft(find.text('Weekly progress')).dy,
        lessThan(t.getTopLeft(find.text('Upcoming coaching')).dy));
    expect(t.getTopLeft(find.text('Upcoming coaching')).dy,
        lessThan(t.getTopLeft(find.text('Recent activity')).dy));
    await t.tap(find.text('Coaching session'));
    expect(opens, 1);
    final late = Completer<PersistedBookingRecord?>();
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(MaterialApp(
        home: MemberHomeScreen(
            liveSession: homeSession,
            onLoadUpcomingCoaching: () => late.future)));
    await t.pump();
    await t.pumpWidget(MaterialApp(
        home: MemberHomeScreen(
            liveSession: const AuthSession(
                userId: 'other',
                organizationId: 'other',
                email: 'other@example.test',
                role: AppRole.member))));
    late.complete(record);
    await t.pumpAndSettle();
    expect(find.text('Upcoming coaching'), findsNothing);
  });
  test(
      'workout selection uses matching plan, account and date, never status copy',
      () {
    final a = homeAttempt();
    expect(
        homeWorkoutAttempt(
            homeScope, homeRoutine(), homeRoutines([a]), homeNow),
        same(a));
    expect(
        homeWorkoutAttempt(
            homeScope, homeRoutine(reps: 12), homeRoutines([a]), homeNow),
        isNull);
    expect(
        homeWorkoutAttempt(SessionScope(userId: 'other', organizationId: 'gym'),
            homeRoutine(), homeRoutines([a]), homeNow),
        isNull);
    expect(
        homeWorkoutAttempt(
            homeScope,
            homeRoutine(),
            homeRoutines([
              homeAttempt(
                  finished: true,
                  completed: true,
                  at: homeNow.subtract(const Duration(days: 2)))
            ]),
            homeNow),
        isNull);
  });
  test(
      'activity uses saved names, removes duplicate child captures and preserves backup meaning',
      () {
    final p = homeProgress();
    final standalone = homeRecentActivities(homeScope, p, null, homeRoutine());
    expect(standalone.single.title, 'Dumbbell Squat');
    expect(standalone.single.backupLabel, 'Saved on device · backup pending');
    final merged = homeRecentActivities(
        homeScope,
        p,
        homeRoutines([homeAttempt(finished: true, completed: true)]),
        homeRoutine());
    expect(merged, hasLength(1));
    expect(merged.single.title, 'Full Body Foundations');
    expect(merged.single.backupLabel, 'Saved on device · backup pending');
  });
  for (final finished in [false, true]) {
    testWidgets(
        'saved workout shows ${finished ? 'summary' : 'continue'} and opens the actual attempt',
        (t) async {
      t.view.physicalSize = const Size(800, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final a = homeAttempt(finished: finished, completed: finished);
      RoutineAttempt? opened;
      await t.pumpWidget(homeTestApp(
          routines: homeRoutines([a]), onAttempt: (v) => opened = v));
      await t.pumpAndSettle();
      final label = finished ? 'View summary' : 'Continue workout';
      await t.ensureVisible(find.text(label));
      await t.tap(find.text(label));
      expect(opened, same(a));
      expect(
          find.text(finished ? '1 completed workout' : '0 completed workouts'),
          findsOneWidget);
    });
  }
  testWidgets('claimed check-in shows actual streak and no Claim button',
      (t) async {
    t.view.physicalSize = const Size(360, 820);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(homeTestApp(checkIn: homeCheckIn(claimed: true)));
    await t.pumpAndSettle();
    expect(find.text('3-day streak'), findsOneWidget);
    expect(find.text('Checked in today'), findsOneWidget);
    expect(find.text('Claim 10 points'), findsNothing);
  });
  testWidgets(
      'eligible claim remains callable and zero completed differs from unknown',
      (t) async {
    var claims = 0;
    t.view.physicalSize = const Size(800, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(homeTestApp(
        routines: homeRoutines([]),
        onClaim: () async {
          claims++;
        }));
    await t.pumpAndSettle();
    await t.tap(find.text('Claim 10 points'));
    await t.pumpAndSettle();
    expect(claims, 1);
    expect(find.text('0 completed workouts'), findsOneWidget);
    expect(find.text('Form scored'), findsNothing);
  });
}
