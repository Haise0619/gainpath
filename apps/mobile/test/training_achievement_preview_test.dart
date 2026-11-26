import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/app/member_typography_theme.dart';
import 'package:gainpath_mobile/features/gamification/application/app_check_in_cubit.dart';
import 'package:gainpath_mobile/features/gamification/application/member_achievements_controller.dart';
import 'package:gainpath_mobile/features/gamification/domain/app_check_in.dart';
import 'package:gainpath_mobile/features/gamification/domain/member_achievements.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/achievement_artwork.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/app_check_in_dashboard.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/training_achievement_preview.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_check_in_test.dart' show snapshotJson;
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;

MemberAchievements training({int unlocked = 3, bool complete = true}) {
  final badges = [
    ('first-workout', 'First Workout', 1),
    ('workout-regular', 'Workout Regular', 10),
    ('routine-finisher', 'Routine Finisher', 1),
    ('century-club', 'Century Club', 100),
  ];
  return MemberAchievements(
    currentStreak: 3,
    complete: complete,
    badges: [
      for (var i = 0; i < badges.length; i++)
        MemberAchievement(
          id: badges[i].$1,
          title: badges[i].$2,
          category: 'workout',
          description: '',
          target: badges[i].$3,
          progress: i < unlocked
              ? badges[i].$3
              : i == 3
                  ? 74
                  : 0,
          unlockedAtMillis: i < unlocked ? 1794735000000 : null,
        ),
      const MemberAchievement(
        id: 'check-in-streak-7',
        title: 'Seven-day Streak',
        category: 'check-in',
        description: '',
        target: 7,
        progress: 6,
      ),
    ],
  );
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUpAll(loadDemoRenderFonts);

  Widget preview(MemberAchievementsController source, {double scale = 1}) =>
      MaterialApp(
        theme: buildMemberTypographyTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
            body: SingleChildScrollView(
                child: TrainingAchievementPreview(
                    controller: source, onViewAll: () {}))),
      );

  for (final width in [320.0, 360.0, 393.0, 430.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('training preview fits ${width.toInt()}dp at ${scale}x',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 850);
        addTearDown(tester.view.reset);
        final source = MemberAchievementsController(
            load: () async => training(), isCurrent: () => true);
        addTearDown(source.dispose);
        await source.refresh();
        await tester.pumpWidget(preview(source, scale: scale));
        final semantics = tester.ensureSemantics();
        expect(find.text('3/4 badges unlocked'), findsOneWidget);
        expect(find.byType(AchievementArtwork), findsNWidgets(4));
        expect(find.byIcon(Icons.lock_outline), findsOneWidget);
        expect(find.bySemanticsLabel('Century Club, locked'), findsOneWidget);
        expect(find.text('74 / 100 reps'), findsOneWidget);
        expect(
            tester
                .widget<LinearProgressIndicator>(
                    find.byType(LinearProgressIndicator))
                .value,
            .74);
        expect(find.text('Seven-day Streak'), findsNothing);
        semantics.dispose();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('zero, complete, pending and failed results use confirmed facts',
      (tester) async {
    var data = training(unlocked: 0);
    var fail = false;
    final source = MemberAchievementsController(
        load: () async {
          if (fail) throw StateError('offline');
          return data;
        },
        isCurrent: () => true);
    addTearDown(source.dispose);
    await tester.pumpWidget(preview(source));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await source.refresh();
    await tester.pumpAndSettle();
    expect(find.text('0/4 badges unlocked'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(4));
    data = training(unlocked: 4);
    await source.refresh();
    await tester.pumpAndSettle();
    expect(find.text('4/4 badges unlocked'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    data = training(complete: false);
    await source.refresh();
    await tester.pumpAndSettle();
    expect(
        find.text('Waiting for confirmed training progress'), findsOneWidget);
    expect(find.byType(AchievementArtwork), findsNothing);
    fail = true;
    final unknown = MemberAchievementsController(
        load: () async => throw StateError('offline'), isCurrent: () => true);
    addTearDown(unknown.dispose);
    await unknown.refresh();
    await tester.pumpWidget(preview(unknown));
    expect(find.text('Could not load training badges'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('cached artwork never shows stale next progress', (tester) async {
    final request = Completer<MemberAchievements>();
    final source = MemberAchievementsController(
      load: () => request.future,
      readCache: () async => training(),
      isCurrent: () => true,
    );
    addTearDown(source.dispose);
    final refresh = source.refresh();
    await tester.pumpWidget(preview(source));
    await tester.pump();
    expect(find.text('3/4 badges unlocked'), findsOneWidget);
    expect(find.text('Showing last confirmed badges'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    request.complete(training());
    await refresh;
  });

  testWidgets('render Rewards with confirmed training preview', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.reset);
    final source = MemberAchievementsController(
        load: () async => training(), isCurrent: () => true);
    addTearDown(source.dispose);
    await source.refresh();
    final scope = SessionScope(userId: 'member-1', organizationId: 'gym-1');
    final snapshot =
        AppCheckInSnapshot.fromJson(snapshotJson(scope, claimed: false), scope);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildMemberTypographyTheme(),
        home: Scaffold(
          body: AppCheckInDashboard(
            state: AppCheckInState(
                status: AppCheckInStatus.ready, snapshot: snapshot),
            achievements: source,
            onClaim: () async {},
            onRefresh: () async {},
            gamesSection: const SizedBox.shrink(),
            weeklyRankSection: const SizedBox.shrink(),
            rewardGoalSection: const SizedBox.shrink(),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('3/4 badges unlocked'), findsOneWidget);
    await tester.runAsync(() async {
      final image = await tester
          .renderObject<RenderRepaintBoundary>(find.byKey(key))
          .toImage(pixelRatio: 1.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('../../build/training-achievement-preview/rewards.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
