import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_mobile/features/gamification/application/app_check_in_cubit.dart';
import 'package:gainpath_mobile/features/gamification/application/member_achievements_controller.dart';
import 'package:gainpath_mobile/features/gamification/domain/member_achievements.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/app_check_in_dashboard.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/member_achievements_screen.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/achievement_celebration_host.dart';
import 'package:gainpath_mobile/features/identity/presentation/member/member_profile_screen.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_app_check_in_repository.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  final data = MemberAchievements(currentStreak: 2, badges: const [
    MemberAchievement(
        id: 'first-check-in',
        title: 'First Check-in',
        category: 'check-in',
        description: 'Claim your first check-in.',
        target: 1,
        progress: 1,
        unlockedAtMillis: 1794735000000),
    MemberAchievement(
        id: 'check-in-streak-3',
        title: 'Three-day Streak',
        category: 'check-in',
        description: 'Check in for three days.',
        target: 3,
        progress: 2),
    MemberAchievement(
        id: 'first-workout',
        title: 'First Workout',
        category: 'workout',
        description: 'Complete a workout.',
        target: 1,
        progress: 0),
  ]);

  testWidgets('badge labels stay readable with inherited white title styles',
      (tester) async {
    final base = ThemeData.light();
    final controller = MemberAchievementsController(
        load: () async => data, isCurrent: () => true);
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: base.copyWith(
        textTheme: base.textTheme.apply(bodyColor: Colors.white),
      ),
      home: MemberAchievementsScreen(controller: controller),
    ));
    await tester.pumpAndSettle();

    for (final label in [
      'First Check-in',
      'Three-day Streak',
      'Unlocked',
      'Locked',
    ]) {
      final text = find.text(label).last;
      final rich = tester.widget<RichText>(find.descendant(
        of: text,
        matching: find.byType(RichText),
      ));
      final card = tester
          .widgetList<Material>(
              find.ancestor(of: text, matching: find.byType(Material)))
          .firstWhere((material) =>
              material.shape is RoundedRectangleBorder &&
              material.color != null);
      final foreground = rich.text.style!.color!.computeLuminance();
      final status = label == 'Unlocked' || label == 'Locked';
      final backgroundColor = status
          ? (tester
              .widgetList<DecoratedBox>(
                  find.ancestor(of: text, matching: find.byType(DecoratedBox)))
              .map((box) => box.decoration)
              .whereType<BoxDecoration>()
              .firstWhere((decoration) => decoration.color != null)
              .color!)
          : card.color!;
      final background = backgroundColor.computeLuminance();
      final lighter = foreground > background ? foreground : background;
      final darker = foreground > background ? background : foreground;
      expect((lighter + .05) / (darker + .05), greaterThanOrEqualTo(4.5),
          reason: label);
    }
    final earned = find
        .ancestor(
          of: find.text('First Check-in'),
          matching: find.byType(InkWell),
        )
        .first;
    final locked = find
        .ancestor(
          of: find.text('Three-day Streak').last,
          matching: find.byType(InkWell),
        )
        .first;
    expect(
        find.descendant(
            of: earned, matching: find.byIcon(Icons.check_circle_rounded)),
        findsOneWidget);
    expect(
        find.descendant(of: locked, matching: find.byIcon(Icons.lock_rounded)),
        findsOneWidget);
    await tester.ensureVisible(locked);
    await tester.pumpAndSettle();
    await tester.tap(locked);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Unlock requirement'), findsOneWidget);
    final progress = tester.widgetList<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator));
    expect(progress, hasLength(2));
    expect(
        progress.every((bar) => bar.stopIndicatorColor == Colors.transparent),
        isTrue);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('collection and locked detail at width $width and 200% text',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 700);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = MemberAchievementsController(
          load: () async => data, isCurrent: () => true);
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: MemberAchievementsScreen(controller: controller),
      ));
      await tester.pumpAndSettle();
      expect(find.text('1 / 3 badges unlocked'), findsOneWidget);
      expect(find.text('Next Achievement'), findsOneWidget);
      final nextTitle = find.text('Three-day Streak').first;
      await tester.ensureVisible(nextTitle);
      await tester.pumpAndSettle();
      await tester.tap(nextTitle);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(BottomSheet),
              matching: find.text('Check in for three days.')),
          findsOneWidget);
      expect(find.text('Share Achievement'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      final unlockedTitle = find.text('First Check-in');
      await tester.scrollUntilVisible(unlockedTitle, 120);
      await tester.ensureVisible(unlockedTitle);
      await tester.pumpAndSettle();
      await tester.tap(unlockedTitle);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  test('fresh unlocks are reported once and offline keeps confirmed data',
      () async {
    var current = true, offline = false;
    var response = MemberAchievements(currentStreak: 0, badges: const []);
    final controller = MemberAchievementsController(
        load: () async {
          if (offline) throw StateError('Offline');
          return response;
        },
        isCurrent: () => current);
    addTearDown(controller.dispose);
    await controller.refresh();
    response = data;
    await controller.refresh();
    expect(controller.takeUnlocks().single.id, 'first-check-in');
    await controller.refresh();
    expect(controller.takeUnlocks(), isEmpty);
    offline = true;
    await controller.refresh();
    expect(controller.snapshot, same(data));
    expect(controller.stale, isTrue);
    current = false;
    controller.invalidate();
    expect(controller.snapshot, isNull);
  });

  test(
      'offline startup restores only cached display progress and reconnect refreshes',
      () async {
    var offline = true;
    final controller = MemberAchievementsController(
      load: () async {
        if (offline) throw StateError('Offline');
        return data;
      },
      readCache: () async => data,
      isCurrent: () => true,
    );
    addTearDown(controller.dispose);
    await controller.refresh();
    expect(controller.snapshot, same(data));
    expect(controller.stale, isTrue);
    offline = false;
    await controller.refresh();
    expect(controller.stale, isFalse);
    expect(controller.takeUnlocks(), isEmpty);
  });

  test('obsolete in-flight result stays hidden across account revalidation',
      () async {
    final older = Completer<MemberAchievements>();
    var calls = 0, current = true;
    final controller = MemberAchievementsController(
      load: () => calls++ == 0
          ? older.future
          : Future.value(
              MemberAchievements(currentStreak: 0, badges: const [])),
      isCurrent: () => current,
    );
    addTearDown(controller.dispose);
    final oldRequest = controller.refresh();
    await Future<void>.delayed(Duration.zero);
    current = false;
    controller.invalidate();
    current = true;
    await controller.refresh();
    older.complete(data);
    await oldRequest;
    expect(controller.snapshot?.unlockedCount, 0);
    expect(controller.takeUnlocks(), isEmpty);
  });

  test(
      'achievement action keeps legacy dataset scope away from canonical reads',
      () async {
    final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
    final isolated = SessionScope(
      userId: scope.userId,
      organizationId: scope.organizationId,
      datasetScope: const VerifiedDatasetScope(
          datasetId: 'fyp',
          seedId: 'fixture',
          revision: 1,
          rootPath: 'datasets/fyp'),
    );
    var calls = 0;
    Future<Object?> invoke(Map<String, Object?> request) async {
      calls++;
      expect(request['action'], 'achievements');
      expect(request['organizationId'], 'gainpath');
      return data.toJson();
    }

    final canonical = FirebaseAppCheckInRepository(
        scope: scope, activeScope: () => scope, invoke: invoke);
    final sandbox = FirebaseAppCheckInRepository(
        scope: isolated, activeScope: () => isolated, invoke: invoke);
    expect((await canonical.achievements()).badges.length, 3);
    await expectLater(sandbox.achievements(), throwsStateError);
    expect(calls, 1);
  });

  testWidgets('Rewards and Profile reuse the same cached collection route',
      (tester) async {
    final auth = AuthBloc(repository: InMemoryAuthRepository());
    addTearDown(auth.close);
    var reads = 0;
    final controller = MemberAchievementsController(
      load: () async {
        reads++;
        return data;
      },
      isCurrent: () => true,
    );
    addTearDown(controller.dispose);
    await controller.refresh();
    await tester.pumpWidget(BlocProvider.value(
      value: auth,
      child: MaterialApp(home: Builder(builder: (context) {
        void open(WidgetBuilder builder) => Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: builder));
        return Scaffold(
            body: Column(children: [
          TextButton(
              onPressed: () => open((_) => AppCheckInDashboard(
                    state: const AppCheckInState(
                        status: AppCheckInStatus.unavailable),
                    onClaim: () async {},
                    onRefresh: () async {},
                    achievements: controller,
                    gamesSection: const SizedBox.shrink(),
                    weeklyRankSection: const SizedBox.shrink(),
                    rewardGoalSection: const SizedBox.shrink(),
                  )),
              child: const Text('Open Rewards')),
          TextButton(
              onPressed: () => open((profileContext) => MemberProfileScreen(
                    liveSession: const AuthSession(
                        email: 'm@example.test', role: AppRole.member),
                    onOpenAchievements: () => Navigator.of(profileContext).push(
                        MaterialPageRoute<void>(
                            builder: (_) => MemberAchievementsScreen(
                                controller: controller))),
                  )),
              child: const Text('Open Profile')),
        ]));
      })),
    ));
    await tester.tap(find.text('Open Rewards'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Badges'), 180);
    expect(find.text('1 / 3 unlocked'), findsOneWidget);
    await tester.tap(find.text('Badges'));
    await tester.pumpAndSettle();
    expect(find.text('My Achievements'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Profile'));
    await tester.pumpAndSettle();
    final profileAchievement = find.text('View Achievements');
    await tester.scrollUntilVisible(profileAchievement, 120);
    await tester.ensureVisible(profileAchievement);
    await tester.pumpAndSettle();
    await tester.tap(profileAchievement);
    await tester.pumpAndSettle();
    expect(find.text('My Achievements'), findsOneWidget);
    expect(reads, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'confirmed unlock celebrates once and can be dismissed with reduced motion',
      (tester) async {
    var response = MemberAchievements(currentStreak: 0, badges: const []);
    final controller = MemberAchievementsController(
        load: () async => response, isCurrent: () => true);
    addTearDown(controller.dispose);
    await controller.refresh();
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!),
      home: Scaffold(
          body: AchievementCelebrationHost(
              controller: controller,
              child: const Text('Workout results saved'))),
    ));
    response = data;
    await controller.refresh();
    await tester.pump();
    expect(find.text('Achievement Unlocked!'), findsOneWidget);
    expect(find.text('Workout results saved'), findsOneWidget);
    await tester.tap(find.byTooltip('Dismiss achievement'));
    await tester.pump();
    await controller.refresh();
    await tester.pump();
    expect(find.text('Achievement Unlocked!'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
