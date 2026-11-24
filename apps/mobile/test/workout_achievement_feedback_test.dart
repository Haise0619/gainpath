import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/gamification/application/member_achievements_controller.dart';
import 'package:gainpath_mobile/features/gamification/domain/member_achievements.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_backup.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/widgets/workout_achievement_feedback.dart';

void main() {
  testWidgets('shows confirmed training progress only after backup and refresh',
      (tester) async {
    final confirmation = Completer<MemberAchievements>();
    var loads = 0;
    final controller = MemberAchievementsController(
      load: () {
        loads++;
        return confirmation.future;
      },
      isCurrent: () => true,
    );
    addTearDown(controller.dispose);

    Future<void> show(BackupRecordStatus status, {required bool enabled}) =>
        tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: WorkoutAchievementFeedback(
                controller: controller, status: status, syncEnabled: enabled),
          ),
        ));

    await show(BackupRecordStatus.localOnly, enabled: false);
    expect(find.textContaining('Turn on workout backup'), findsOneWidget);
    await show(BackupRecordStatus.pendingBackup, enabled: true);
    expect(find.textContaining('after your workout syncs'), findsOneWidget);
    expect(loads, 0);
    await show(BackupRecordStatus.backedUp, enabled: true);
    await tester.pump();
    expect(loads, 1);
    expect(find.text('Checking your achievement progress…'), findsOneWidget);
    confirmation.complete(MemberAchievements(currentStreak: 0, badges: const [
      MemberAchievement(
          id: 'workout-regular',
          title: 'Workout Regular',
          category: 'workout',
          description: 'Complete five qualifying workouts',
          target: 5,
          progress: 3),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('Latest confirmed training progress'), findsOneWidget);
    expect(find.text('3 / 5 workouts'), findsOneWidget);
    expect(find.text('View achievements'), findsOneWidget);
  });
}
