import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_admin_web/features/recommendation/application/admin_ai_drafts.dart';

void main() {
  final draft = <String, dynamic>{
    'name': 'Glute Bridge',
    'description': 'Floor guidance',
    'difficulty': 'Beginner',
    'category': 'Accessory',
    'equipment': 'Bodyweight',
    'instructions': ['Set up', 'Lift slowly'],
    'durationMinutes': 20,
    'goal': 'Muscle gain',
    'exercises': [
      {
        'exerciseId': 'real-squat',
        'name': 'Squat',
        'sets': 3,
        'reps': 8,
        'restSeconds': 60,
        'executionMode': 'aiTracked',
        'revision': 2
      }
    ]
  };
  test(
      'exercise seed preserves manual publishing and never enables pose tracking',
      () {
    final seed = aiExerciseSeed(draft);
    expect(seed.title, 'Glute Bridge');
    expect(seed.id, isEmpty);
    expect(seed.status, TutorialStatus.draft);
    expect(seed.trackingCapability.hasPoseTracking, isFalse);
    expect(seed.thumbnailUrl, isEmpty);
    expect(seed.tutorialSteps.length, 2);
  });
  test(
      'routine draft preserves real IDs and prescription without edit identity',
      () {
    final seed = aiRoutineSeed(draft);
    expect(seed.id, isEmpty);
    expect(seed.days.single.exercises.single.exerciseId, 'real-squat');
    expect(seed.days.single.exercises.single.prescription!.restSeconds, 60);
    expect(seed.imageUrl, isEmpty);
  });
}
