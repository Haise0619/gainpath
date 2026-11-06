import 'package:gainpath_domain/workout.dart';
import 'published_routine_view.dart';

/// Authored local practice entry, explicitly independent of published routines.
/// Registry identity also supports this exercise in future authored routines.
const standardFloorPushUp = PublishedRoutineExercise(
  exerciseId: 'standard-floor-push-up-side-v1',
  dayNumber: 1,
  name: 'Standard Floor Push-Up',
  category: 'Bodyweight',
  muscleGroup: 'Chest',
  sets: 3,
  reps: 8,
  restSeconds: 60,
  imageUrl: '',
  cue: 'Lower with control, keep hips aligned, then extend fully.',
  tutorial: ExerciseTutorialDetails(
    description:
        'Standard push-ups from a floor plank. Provisional visible-side AI guidance.',
    difficulty: 'Intermediate',
    equipment: 'Clear floor space; optional exercise mat',
    steps: [
      ExerciseTutorialStep(
          title: 'Set up the camera',
          description:
              'Use Left Side View or Right Side View at floor height. Keep your whole body and both shoulders visible, with the near elbow clear.'),
      ExerciseTutorialStep(
          title: 'Hold the top',
          description:
              'Place palms on the floor and extend your arms in a plank from shoulders to ankles. Hold steady until tracking is ready.'),
      ExerciseTutorialStep(
          title: 'Lower and return',
          description:
              'Lower your chest with control, keep hips aligned, and push back to extended arms. After an interruption, hold the top again.'),
    ],
  ),
);
