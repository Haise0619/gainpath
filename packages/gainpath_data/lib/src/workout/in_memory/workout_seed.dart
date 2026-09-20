import 'package:gainpath_domain/workout.dart';

/// In-memory seed data for the workout feature (frontend prototype).
class WorkoutSeed {
  final routine = <Exercise>[
    Exercise(
      'Barbell Squat',
      'Compound Lower-Body',
      4,
      8,
      'Keep your chest up and drive your knees out.',
      'https://images.unsplash.com/photo-1534368959876-26bf04f2c947?auto=format&fit=crop&w=800&q=80',
      'Quads · Glutes',
    ),
    Exercise(
      'Romanian Deadlift',
      'Compound Lower-Body',
      3,
      10,
      'Keep a neutral spine, hinge from the hips.',
      'https://images.unsplash.com/photo-1583454110551-21f2fa2afe61?auto=format&fit=crop&w=800&q=80',
      'Hamstrings · Glutes',
    ),
    Exercise(
      'Overhead Press',
      'Compound Upper-Body',
      3,
      8,
      'Brace your core, avoid arching your lower back.',
      'https://images.unsplash.com/photo-1541534741688-6078c6bfb5c5?auto=format&fit=crop&w=800&q=80',
      'Shoulders · Triceps',
    ),
    Exercise(
      'Dumbbell Row',
      'Isolation Upper-Body',
      3,
      12,
      'Pull to the hip, keep your shoulder down.',
      'https://images.unsplash.com/photo-1601422407692-ec4eeec1d9b3?auto=format&fit=crop&w=800&q=80',
      'Back · Biceps',
    ),
  ];

  final voiceCues = <String>[
    'Good depth. Hold that.',
    'Drive your knees out.',
    'Chest up.',
    'Nice rep. Keep the tempo.',
    'Slow the descent slightly.',
    'Brace your core.',
  ];

  final gymEquipment = <GymEquipment>[
    GymEquipment(
      id: 'eq1',
      name: 'Squat Rack',
      category: 'Compound Lower-Body',
      description:
          'A fixed barbell rack with adjustable safety arms, used for barbell squats, rack pulls, '
          'and overhead presses started from a supported position.',
      howToUse: [
        'Set the J-hooks to just below shoulder height.',
        'Set the safety arms roughly at your lowest squat depth.',
        'Step under the bar, unrack by standing up, then step back clear of the hooks.',
        'Re-rack by walking forward until the bar contacts the hooks.',
      ],
      safetyTips: [
        'Always set the safety arms before loading the bar.',
        'Load and unload plates evenly on both sides.',
        'Ask for a spot on heavy attempts if the rack has no arms set.',
      ],
      imageUrl:
          'https://images.unsplash.com/photo-1585152968992-d2b9444408cc?auto=format&fit=crop&w=900&q=80',
      muscleGroup: 'Quads · Glutes · Hamstrings',
    ),
    GymEquipment(
      id: 'eq2',
      name: 'Standing Press Station',
      category: 'Compound Upper-Body',
      description:
          'An open barbell station for standing presses — no rack arms overhead, so the bar is '
          'lifted from the floor or a low rack into the starting position.',
      howToUse: [
        'Clean the bar to shoulder height or unrack it from a low set of hooks.',
        'Brace your core and press straight overhead, moving your head back slightly to clear the bar.',
        'Lower back to the shoulders under control before the next rep.',
      ],
      safetyTips: [
        'Keep the bar path close to your face on the way up.',
        'Avoid leaning back excessively — brace the core instead.',
        'Use a lighter warm-up set to confirm the bar path before loading up.',
      ],
      imageUrl:
          'https://images.unsplash.com/photo-1517344884509-a0c97ec11bcc?auto=format&fit=crop&w=900&q=80',
      muscleGroup: 'Shoulders · Triceps',
    ),
    GymEquipment(
      id: 'eq3',
      name: 'Adjustable Bench',
      category: 'Isolation Upper-Body',
      description:
          'A flat-to-incline bench used to support single-arm or bent-over dumbbell work, letting you '
          'brace one side of the body while the other moves freely.',
      howToUse: [
        'Set the bench flat or at a slight incline depending on the exercise.',
        'Brace your supporting knee and hand on the bench for a bent-over row.',
        'Keep your back flat and pull with your elbow, not your hand.',
      ],
      safetyTips: [
        'Check the incline pin is fully locked before loading weight.',
        'Keep the working weight close to the bench, not extended out.',
      ],
      imageUrl:
          'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?auto=format&fit=crop&w=900&q=80',
      muscleGroup: 'Back · Chest · Shoulders',
    ),
    GymEquipment(
      id: 'eq4',
      name: 'Dumbbell Rack',
      category: 'Isolation Upper-Body',
      description:
          'A tiered rack holding paired dumbbells across a full weight range, used for rows, presses, '
          'curls, and most single-limb accessory work.',
      howToUse: [
        'Select a pair from the rack matching the exercise and rep target.',
        'Return dumbbells to their matching slot after your set.',
        'Choose a weight that lets you complete every rep with control.',
      ],
      safetyTips: [
        'Lift dumbbells off the rack with a neutral spine, not a rounded back.',
        'Re-rack with both hands rather than dropping them.',
      ],
      imageUrl:
          'https://images.unsplash.com/photo-1638536532686-d610adfc8e5c?auto=format&fit=crop&w=900&q=80',
      muscleGroup: 'Full body accessory work',
    ),
    GymEquipment(
      id: 'eq5',
      name: 'Cable Crossover Machine',
      category: 'Cable & Machine',
      description:
          'A dual-tower cable station with adjustable pulley height, used for crossovers, face pulls, '
          'tricep pushdowns, and other constant-tension cable work.',
      howToUse: [
        'Select the pin weight and pulley height for your exercise.',
        'Keep tension on the cable throughout the full range of motion.',
        'Move slowly through the stretch position rather than letting the weight stack slam.',
      ],
      safetyTips: [
        'Check the carabiner clip is fully closed before pulling.',
        'Stand with a staggered stance for stability on heavier pulls.',
      ],
      imageUrl:
          'https://images.unsplash.com/photo-1540497077202-7c8a3999166f?auto=format&fit=crop&w=900&q=80',
      muscleGroup: 'Chest · Back · Shoulders',
    ),
    GymEquipment(
      id: 'eq6',
      name: 'Treadmill',
      category: 'Cardio',
      description:
          'A motorised running belt with adjustable speed and incline, used for warm-ups, steady-state '
          'cardio, or interval work.',
      howToUse: [
        'Straddle the belt and start it moving before stepping on.',
        'Clip the safety key to your clothing before you begin.',
        'Increase speed gradually rather than jumping straight to pace.',
      ],
      safetyTips: [
        'Never step off a moving belt from the front — reduce speed to zero first.',
        'Keep the safety key attached at all times.',
      ],
      imageUrl:
          'https://images.unsplash.com/photo-1576678927484-cc907957088c?auto=format&fit=crop&w=900&q=80',
      muscleGroup: 'Cardiovascular',
    ),
  ];

  final history = <WorkoutRecord>[
    WorkoutRecord('Barbell Squat',
        DateTime.now().subtract(const Duration(days: 1)), 32, 84, 42),
    WorkoutRecord('Overhead Press',
        DateTime.now().subtract(const Duration(days: 3)), 24, 79, 35),
    WorkoutRecord('Romanian Deadlift',
        DateTime.now().subtract(const Duration(days: 5)), 30, 71, 38),
    WorkoutRecord('Dumbbell Row',
        DateTime.now().subtract(const Duration(days: 8)), 36, 88, 30),
    WorkoutRecord('Barbell Squat',
        DateTime.now().subtract(const Duration(days: 11)), 28, 68, 40),
    WorkoutRecord('Overhead Press',
        DateTime.now().subtract(const Duration(days: 14)), 24, 74, 33),
  ];

  final heightCm = 170;

  final tutorials = <TutorialVideo>[
    TutorialVideo(
        title: 'Squat Form Fundamentals',
        category: 'Compound Lower-Body',
        status: TutorialStatus.active,
        coversExercise: 'Barbell Squat',
        difficulty: 'Beginner',
        durationMin: 6,
        thumbnailUrl:
            'https://images.unsplash.com/photo-1534368959876-26bf04f2c947?auto=format&fit=crop&w=600&q=80'),
    TutorialVideo(
        title: 'Fixing Knee Valgus',
        category: 'Compound Lower-Body',
        status: TutorialStatus.active,
        difficulty: 'Intermediate',
        durationMin: 4,
        thumbnailUrl:
            'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?auto=format&fit=crop&w=600&q=80'),
    TutorialVideo(
        title: 'RDL Form Basics',
        category: 'Compound Lower-Body',
        status: TutorialStatus.active,
        coversExercise: 'Romanian Deadlift',
        difficulty: 'Beginner',
        durationMin: 5,
        thumbnailUrl:
            'https://images.unsplash.com/photo-1583454110551-21f2fa2afe61?auto=format&fit=crop&w=600&q=80'),
    TutorialVideo(
        title: 'Overhead Press Setup',
        category: 'Compound Upper-Body',
        status: TutorialStatus.active,
        coversExercise: 'Overhead Press',
        difficulty: 'Beginner',
        durationMin: 5,
        thumbnailUrl:
            'https://images.unsplash.com/photo-1541534741688-6078c6bfb5c5?auto=format&fit=crop&w=600&q=80'),
  ];

  final routineTemplates = <RoutineBlueprint>[
    RoutineBlueprint(
      id: 'rt1',
      name: 'Beginner Full Body',
      level: 'Beginner',
      assignedMembers: 62,
      imageUrl:
          'https://images.unsplash.com/photo-1571731956672-f2b94d7dd0cb?auto=format&fit=crop&w=600&q=80',
      days: [
        RoutineDay(1, [
          RoutineExerciseRef('Barbell Squat', 3, 8),
          RoutineExerciseRef('Dumbbell Row', 3, 12),
          RoutineExerciseRef('Plank', 3, 30),
        ]),
        RoutineDay(2, [
          RoutineExerciseRef('Romanian Deadlift', 3, 10),
          RoutineExerciseRef('Overhead Press', 3, 8),
          RoutineExerciseRef('Lat Pulldown', 3, 12),
        ]),
      ],
    ),
    RoutineBlueprint(
      id: 'rt2',
      name: 'Push / Pull / Legs',
      level: 'Intermediate',
      assignedMembers: 84,
      imageUrl:
          'https://images.unsplash.com/photo-1540496905036-5937c10647cc?auto=format&fit=crop&w=600&q=80',
      days: [
        RoutineDay(1, [
          RoutineExerciseRef('Overhead Press', 4, 8),
          RoutineExerciseRef('Incline Bench Press', 4, 10),
          RoutineExerciseRef('Tricep Pushdown', 3, 12),
        ]),
        RoutineDay(2, [
          RoutineExerciseRef('Dumbbell Row', 4, 10),
          RoutineExerciseRef('Lat Pulldown', 4, 10),
          RoutineExerciseRef('Bicep Curl', 3, 12),
        ]),
        RoutineDay(3, [
          RoutineExerciseRef('Barbell Squat', 4, 8),
          RoutineExerciseRef('Romanian Deadlift', 3, 10),
          RoutineExerciseRef('Leg Press', 3, 12),
        ]),
      ],
    ),
    RoutineBlueprint(
      id: 'rt3',
      name: 'Upper / Lower Split',
      level: 'Intermediate',
      assignedMembers: 47,
      imageUrl:
          'https://images.unsplash.com/photo-1600965962102-9d260a71890d?auto=format&fit=crop&w=600&q=80',
      days: [
        RoutineDay(1, [
          RoutineExerciseRef('Overhead Press', 4, 8),
          RoutineExerciseRef('Dumbbell Row', 4, 10),
        ]),
        RoutineDay(2, [
          RoutineExerciseRef('Barbell Squat', 4, 8),
          RoutineExerciseRef('Romanian Deadlift', 4, 10),
        ]),
      ],
    ),
    RoutineBlueprint(
      id: 'rt4',
      name: '5-Day Body Part Split',
      level: 'Advanced',
      assignedMembers: 19,
      imageUrl:
          'https://images.unsplash.com/photo-1546484396-fb3fc6f95f98?auto=format&fit=crop&w=600&q=80',
      days: [
        RoutineDay(1, [RoutineExerciseRef('Barbell Squat', 5, 6)]),
        RoutineDay(2, [RoutineExerciseRef('Overhead Press', 5, 6)]),
        RoutineDay(3, [RoutineExerciseRef('Dumbbell Row', 5, 8)]),
        RoutineDay(4, [RoutineExerciseRef('Romanian Deadlift', 5, 6)]),
        RoutineDay(5, [RoutineExerciseRef('Incline Bench Press', 5, 8)]),
      ],
    ),
  ];
}
