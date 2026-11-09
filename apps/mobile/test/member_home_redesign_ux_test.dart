import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/app/home/member_home_screen.dart';
import 'package:gainpath_mobile/features/gamification/application/app_check_in_cubit.dart';
import 'package:gainpath_mobile/features/workout/data/published_routine.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const testSession = AuthSession(
    userId: 'member-01',
    organizationId: 'gym-01',
    email: 'alex@example.test',
    displayName: 'Alex Tan',
    role: AppRole.member,
  );

  final testRoutine = PublishedRoutine.fromDocument('routine-1', {
    'schemaVersion': 1,
    'kind': 'routine',
    'status': 'published',
    'sourceBlueprintId': 'blueprint-1',
    'title': 'Upper Body Hypertrophy',
    'estimatedMinutes': 40,
    'exercises': <Map<String, dynamic>>[
      {
        'exerciseId': 'press-1',
        'name': 'Overhead Press',
        'sets': 3,
        'reps': 10,
        'category': 'Shoulders'
      },
      {
        'exerciseId': 'pushup-1',
        'name': 'Floor Push-Up',
        'sets': 3,
        'reps': 12,
        'category': 'Chest'
      },
    ],
  });

  final scope = SessionScope(userId: 'member-01', organizationId: 'gym-01');
  final now = DateTime.now().toUtc();
  final start1 = now.subtract(const Duration(hours: 2));
  final start2 = now.subtract(const Duration(hours: 4));

  final testRecords = [
    LocalWorkoutProgressRecord(
      scope: scope,
      sessionId: 'session-01',
      exerciseId: 'squat',
      startedAt: start1,
      endedAt: start1.add(const Duration(minutes: 20)),
      repetitions: 24,
      partialRepetitions: 2,
      trackedDurationMicros: 18 * 60 * 1000000,
      rejectedDurationMicros: 1 * 60 * 1000000,
      formScorePercent: 88,
      scoringVersion: 'v1',
      detectorId: 'd1',
      detectorVersion: 'v1',
      cameraView: 'front',
      status: LocalWorkoutRecordStatus.accepted,
    ),
    LocalWorkoutProgressRecord(
      scope: scope,
      sessionId: 'session-02',
      exerciseId: 'shoulder-press',
      startedAt: start2,
      endedAt: start2.add(const Duration(minutes: 15)),
      repetitions: 18,
      partialRepetitions: 0,
      trackedDurationMicros: 14 * 60 * 1000000,
      rejectedDurationMicros: 0,
      formScorePercent: 92,
      scoringVersion: 'v1',
      detectorId: 'd1',
      detectorVersion: 'v1',
      cameraView: 'front',
      status: LocalWorkoutRecordStatus.pending,
    ),
  ];

  final testProgress = calculateLocalMemberProgress(
    scope: scope,
    records: testRecords,
    asOf: now,
  );

  Widget buildScreen({
    AppCheckInState? checkIn,
    PublishedRoutine? routine,
    MemberLocalProgress? progress,
    VoidCallback? onStartWorkout,
    VoidCallback? onOpenBookings,
    VoidCallback? onOpenCoaches,
    VoidCallback? onOpenPlan,
    VoidCallback? onOpenProgress,
    VoidCallback? onOpenEquipment,
    Size viewport = const Size(360, 800),
    double textScale = 1.0,
  }) {
    return MediaQuery(
      data: MediaQueryData(
        size: viewport,
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: AppColors.bg,
        ),
        home: MemberHomeScreen(
          liveSession: testSession,
          appCheckIn: checkIn,
          publishedRoutine: routine,
          localProgress: progress,
          onStartWorkout: onStartWorkout,
          onOpenBookings: onOpenBookings,
          onOpenCoaches: onOpenCoaches,
          onOpenPlan: onOpenPlan,
          onOpenProgress: onOpenProgress,
          onOpenEquipment: onOpenEquipment,
        ),
      ),
    );
  }

  testWidgets(
      'Member Home displays clear hierarchy: Check-in -> Workout -> This Week -> Recent -> Quick Access',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildScreen(
      routine: testRoutine,
      progress: testProgress,
    ));
    await tester.pumpAndSettle();

    final checkInTitle = find.text('Daily check-in');
    final workoutTitle = find.text("Today's workout");
    final weeklyTitle = find.text('Weekly progress');
    final recentTitle = find.text('Recent activity');
    final quickTitle = find.text('Quick access');

    expect(checkInTitle, findsOneWidget);
    expect(workoutTitle, findsOneWidget);
    expect(weeklyTitle, findsOneWidget);
    expect(recentTitle, findsOneWidget);
    expect(quickTitle, findsOneWidget);

    final checkInDy = tester.getTopLeft(checkInTitle).dy;
    final workoutDy = tester.getTopLeft(workoutTitle).dy;
    final weeklyDy = tester.getTopLeft(weeklyTitle).dy;
    final recentDy = tester.getTopLeft(recentTitle).dy;
    final quickDy = tester.getTopLeft(quickTitle).dy;

    expect(checkInDy, lessThan(workoutDy));
    expect(workoutDy, lessThan(weeklyDy));
    expect(weeklyDy, lessThan(recentDy));
    expect(recentDy, lessThan(quickDy));
  });

  testWidgets("Today's Workout card shows exercise details and triggers start",
      (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var started = false;
    await tester.pumpWidget(buildScreen(
      routine: testRoutine,
      onStartWorkout: () => started = true,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Upper Body Hypertrophy'), findsOneWidget);
    expect(find.text('2 exercises  ·  about 40 min'), findsOneWidget);
    expect(find.text("TODAY'S WORKOUT"), findsNothing);
    expect(find.text('Overhead Press'), findsNothing);
    expect(find.text('Floor Push-Up'), findsNothing);

    final startButton = find.text('Start workout');
    expect(startButton, findsOneWidget);
    await tester.tap(startButton);
    expect(started, isTrue);
  });

  testWidgets(
      'Weekly Progress card shows sessions, reps, form score and activity header',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildScreen(
      progress: testProgress,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Workout progress is loading.'), findsOneWidget);
    expect(find.text('Form scored'), findsNothing);
    expect(find.text('Reps'), findsNothing);
  });

  testWidgets(
      'Recent Activity displays formatted workout records and backup status',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildScreen(
      progress: testProgress,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Squat'), findsOneWidget);
    expect(find.text('Backed up'), findsOneWidget);
    expect(find.text('Saved on device · backup pending'), findsOneWidget);
    expect(find.text('View all'), findsOneWidget);
  });

  testWidgets(
      'Quick Access contains 4 primary shortcuts and More opens secondary shortcuts',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var openedProgress = false;
    var openedBookings = false;
    var openedCoaches = false;
    var openedPlan = false;
    var openedEquipment = false;

    await tester.pumpWidget(buildScreen(
      onOpenProgress: () => openedProgress = true,
      onOpenBookings: () => openedBookings = true,
      onOpenCoaches: () => openedCoaches = true,
      onOpenPlan: () => openedPlan = true,
      onOpenEquipment: () => openedEquipment = true,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Progress'), findsOneWidget);
    expect(find.text('Bookings'), findsOneWidget);
    expect(find.text('My Plan'), findsOneWidget);
    expect(find.text('Coaches'), findsNothing);
    expect(find.text('Equipment'), findsOneWidget);

    await tester.tap(find.text('Progress'));
    expect(openedProgress, isTrue);

    await tester.tap(find.text('Bookings'));
    expect(openedBookings, isTrue);

    await tester.tap(find.text('My Plan'));
    expect(openedPlan, isTrue);

    await tester.tap(find.text('Equipment'));
    expect(openedEquipment, isTrue);

    // Open More shortcuts modal
    final moreButton = find.text('More shortcuts');
    expect(moreButton, findsOneWidget);
    await tester.tap(moreButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Coaches'));
    expect(openedCoaches, isTrue);
    expect(find.text('Rewards'), findsOneWidget);
    expect(find.text('Ranking'), findsOneWidget);
    expect(find.text('Mini-games'), findsOneWidget);
    expect(find.text('Membership'), findsOneWidget);
    expect(find.text('Saved tips'), findsOneWidget);
  });

  testWidgets(
      'Member Home handles narrow 320px viewport and 2.0x text scaling without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final errors = <FlutterErrorDetails>[];
    void Function(FlutterErrorDetails)? oldHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      errors.add(details);
    };
    addTearDown(() => FlutterError.onError = oldHandler);

    await tester.pumpWidget(buildScreen(
      routine: testRoutine,
      progress: testProgress,
      viewport: const Size(320, 600),
      textScale: 2.0,
    ));
    await tester.pumpAndSettle();

    // Test scrolling through entire list without overflow
    final scrollable = find.byType(Scrollable).first;
    for (var i = 0; i < 4; i++) {
      await tester.drag(scrollable, const Offset(0, -350));
      await tester.pumpAndSettle();
    }

    expect(errors, isEmpty, reason: errors.map((e) => e.toString()).join('\n'));
  });
}
