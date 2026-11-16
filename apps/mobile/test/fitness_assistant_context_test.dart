import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/chatbot.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';
import 'package:gainpath_mobile/features/recommendation/application/member_recommendation_repository.dart';
import 'package:gainpath_mobile/features/chatbot/application/fitness_assistant_context.dart';
import 'package:gainpath_mobile/features/analytics/domain/local_member_progress_repository.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_attempt.dart';

void main() {
  final scope = SessionScope(userId: 'member', organizationId: 'org');
  final now = DateTime.utc(2026, 11, 16, 5);
  test(
      'unsafe health intent cannot bypass safety through local workout suggestions',
      () async {
    var reads = 0;
    final assistant = FitnessAssistantContext(
        scope: scope,
        isCurrent: () => true,
        loadProgress: () async {
          reads++;
          return LocalMemberProgressSnapshot(records: []);
        },
        loadRoutines: () async {
          reads++;
          return [];
        });
    final answer = await assistant
        .reply('I have chest pain, recommend a workout for today');
    expect(answer!.text, contains('Stop exercising'));
    expect(answer.attachment, isNull);
    expect(reads, 0);
  });
  LocalWorkoutProgressRecord record(
          {SessionScope? owner,
          double? score,
          String version = 'squat-v1',
          String exercise = 'squat',
          String id = 'capture',
          int minutes = 1}) =>
      LocalWorkoutProgressRecord(
          scope: owner ?? scope,
          sessionId: id,
          exerciseId: exercise,
          startedAt: now.subtract(Duration(minutes: minutes + 1)),
          endedAt: now.subtract(Duration(minutes: minutes)),
          repetitions: 7,
          partialRepetitions: 1,
          trackedDurationMicros: 30000000,
          rejectedDurationMicros: 1000000,
          formScorePercent: score,
          scoringVersion: version,
          detectorId: 'blazepose',
          detectorVersion: 'v1',
          cameraView: 'side',
          status: LocalWorkoutRecordStatus.localOnly);
  String values(ChatMessage message) =>
      (message.attachment! as FitnessFactsAttachment)
          .facts
          .map((f) => '${f.label}: ${f.value}')
          .join('\n');
  const catalogExercise = PublishedRoutineExercise(
      exerciseId: 'squat',
      dayNumber: 1,
      name: 'Published Squat',
      category: 'Strength',
      sets: 3,
      reps: 8,
      cue: 'Steady',
      imageUrl: 'https://example.invalid/squat.jpg',
      muscleGroup: 'Legs');
  const catalogRoutine = PublishedRoutine(
      id: 'routine',
      sourceBlueprintId: 'blueprint',
      title: 'Published Foundation',
      estimatedMinutes: 10,
      exercises: [catalogExercise]);
  RoutineAttempt attempt(
          {required String id,
          required bool finished,
          required int minutesAgo,
          bool complete = true}) =>
      RoutineAttempt(
          id: id,
          scope: scope,
          routine: catalogRoutine,
          day: 1,
          finished: finished,
          startedAtMicros: now
              .subtract(Duration(minutes: minutesAgo + 5))
              .microsecondsSinceEpoch,
          finishedAtMicros: finished
              ? now
                  .subtract(Duration(minutes: minutesAgo))
                  .microsecondsSinceEpoch
              : null,
          updatedAtMicros: now
              .subtract(Duration(minutes: minutesAgo))
              .microsecondsSinceEpoch,
          entries: [
            RoutineExerciseResult(
                index: 0,
                status: complete && finished
                    ? RoutineExerciseStatus.completed
                    : RoutineExerciseStatus.partial,
                sessionIds: [],
                fullRepetitions: finished ? 8 : 3,
                partialRepetitions: 1,
                trackedDurationMicros: 30000000,
                manualSets: 0)
          ]);
  test(
      'last workout never substitutes a newer unfinished routine for completed work',
      () async {
    final assistant = FitnessAssistantContext(
        scope: scope,
        isCurrent: () => true,
        clock: () => now,
        loadProgress: () async =>
            LocalMemberProgressSnapshot(records: [], attempts: [
              attempt(id: 'done', finished: true, minutesAgo: 20),
              attempt(id: 'unfinished', finished: false, minutesAgo: 1)
            ]));
    final answer = (await assistant.reply('How was my last workout?'))!;
    expect(values(answer), contains('Saved record type: Completed routine'));
    expect(values(answer), contains('Repetitions: 8 full · 1 partial'));
    expect(values(answer), contains('Completed exercises: 1 / 1'));
    expect(values(answer), isNot(contains('Repetitions: 3 full')));
  });
  test(
      'unfinished routine and latest saved capture are explicit separate requests',
      () async {
    final assistant = FitnessAssistantContext(
        scope: scope,
        isCurrent: () => true,
        clock: () => now,
        loadProgress: () async => LocalMemberProgressSnapshot(records: [
              record()
            ], attempts: [
              attempt(id: 'unfinished', finished: false, minutesAgo: 0)
            ]));
    expect(values((await assistant.reply('Show my unfinished routine'))!),
        contains('Saved record type: Unfinished routine'));
    expect(values((await assistant.reply('Show my latest saved capture'))!),
        contains('Saved record type: Saved exercise capture'));
  });
  test(
      'completed workout query does not label an individual capture completed routine',
      () async {
    final assistant = FitnessAssistantContext(
        scope: scope,
        isCurrent: () => true,
        clock: () => now,
        loadProgress: () async => LocalMemberProgressSnapshot(records: [
              record()
            ], attempts: [
              attempt(id: 'unfinished', finished: false, minutesAgo: 0)
            ]));
    expect((await assistant.reply('Show my latest completed workout'))!.text,
        contains('No completed routine'));
  });
  test(
      'specific exercise uses published name and excludes unrelated scores and repetitions',
      () async {
    var catalogReads = 0;
    final assistant = FitnessAssistantContext(
        scope: scope,
        isCurrent: () => true,
        clock: () => now,
        loadRoutines: () async {
          catalogReads++;
          return [catalogRoutine];
        },
        loadProgress: () async => LocalMemberProgressSnapshot(records: [
              record(score: 75),
              record(exercise: 'calf-raise', id: 'calf', score: 99, minutes: 2)
            ]));
    await assistant.reply('Recommend a workout for today');
    final answer = (await assistant.reply('Show my squat progress'))!;
    expect(catalogReads, 1);
    expect(values(answer), contains('Published Squat'));
    expect(values(answer), contains('Full / partial repetitions: 7 / 1'));
    expect(values(answer), isNot(contains('99.0%')));
  });
  test('history uses saved or cached names without a fresh catalog request',
      () async {
    var catalogReads = 0;
    final assistant = FitnessAssistantContext(
        scope: scope,
        isCurrent: () => true,
        clock: () => now,
        loadRoutines: () async {
          catalogReads++;
          return [catalogRoutine];
        },
        loadProgress: () async =>
            LocalMemberProgressSnapshot(records: [record()]));
    final answer = (await assistant.reply('How was my last workout?'))!;
    expect(catalogReads, 0);
    expect(values(answer), contains('Squat'));
  });
  test('latest saved record is distinct from last completed routine', () async {
    final assistant = FitnessAssistantContext(
        scope: scope,
        isCurrent: () => true,
        clock: () => now,
        loadProgress: () async =>
            LocalMemberProgressSnapshot(records: [], attempts: [
              attempt(id: 'done', finished: true, minutesAgo: 20),
              attempt(id: 'draft', finished: false, minutesAgo: 1)
            ]));
    expect(values((await assistant.reply('Show my latest saved record'))!),
        contains('Saved record type: Unfinished routine'));
    expect(values((await assistant.reply('Show my latest completed workout'))!),
        contains('Saved record type: Completed routine'));
  });
  test('specific exercise in a mixed routine counts only the matching rows',
      () async {
    const other = PublishedRoutineExercise(
        exerciseId: 'calf-raise',
        dayNumber: 1,
        name: 'Calf Raise',
        category: 'Strength',
        sets: 3,
        reps: 10,
        cue: 'Steady',
        imageUrl: '',
        muscleGroup: 'Legs');
    const routine = PublishedRoutine(
        id: 'mixed',
        sourceBlueprintId: 'mixed-source',
        title: 'Mixed routine',
        estimatedMinutes: 20,
        exercises: [catalogExercise, other]);
    final mixed = RoutineAttempt(
        id: 'mixed-attempt',
        scope: scope,
        routine: routine,
        day: 1,
        finished: true,
        startedAtMicros:
            now.subtract(const Duration(minutes: 12)).microsecondsSinceEpoch,
        finishedAtMicros:
            now.subtract(const Duration(minutes: 2)).microsecondsSinceEpoch,
        updatedAtMicros:
            now.subtract(const Duration(minutes: 2)).microsecondsSinceEpoch,
        entries: [
          RoutineExerciseResult(
              index: 0,
              status: RoutineExerciseStatus.completed,
              sessionIds: [],
              fullRepetitions: 8,
              partialRepetitions: 1,
              trackedDurationMicros: 30000000,
              manualSets: 0),
          RoutineExerciseResult(
              index: 1,
              status: RoutineExerciseStatus.completed,
              sessionIds: [],
              fullRepetitions: 99,
              partialRepetitions: 3,
              trackedDurationMicros: 120000000,
              manualSets: 2)
        ]);
    final assistant = FitnessAssistantContext(
        scope: scope,
        isCurrent: () => true,
        clock: () => now,
        loadProgress: () async =>
            LocalMemberProgressSnapshot(records: [], attempts: [mixed]));
    final answer = (await assistant.reply('Show my last squat workout'))!;
    expect(values(answer), contains('Repetitions: 8 full · 1 partial'));
    expect(values(answer), contains('0m 30s tracked for this exercise'));
    expect(values(answer), isNot(contains('107 full')));
    expect(values(answer), isNot(contains('Calf Raise')));
  });
  test(
      'specific exercise with no matching record never returns an unrelated capture',
      () async {
    final assistant = FitnessAssistantContext(
        scope: scope,
        isCurrent: () => true,
        clock: () => now,
        loadProgress: () async => LocalMemberProgressSnapshot(
            records: [record(exercise: 'calf-raise', score: 95)]));
    final answer = (await assistant.reply('Show my last squat workout'))!;
    expect(answer.text, contains('No saved workout'));
    expect(values(answer), isNot(contains('95.0%')));
  });
  test('unscored exercise rules cannot acquire numeric form or trends',
      () async {
    final assistant = FitnessAssistantContext(
        scope: scope,
        isCurrent: () => true,
        clock: () => now,
        loadProgress: () async => LocalMemberProgressSnapshot(records: [
              record(
                  exercise: 'single-arm-row',
                  version: 'single-arm-row-side-v1',
                  score: 95)
            ]));
    final answer = (await assistant.reply('Show my row progress'))!;
    expect(values(answer), contains('Not assessed'));
    expect(values(answer), isNot(contains('95.0%')));
  });
  test(
      'tutorial previews use only actual known HTTPS image fields and action identity',
      () async {
    final assistant = FitnessAssistantContext(
        scope: scope,
        isCurrent: () => true,
        clock: () => now,
        loadProgress: () async => LocalMemberProgressSnapshot(records: []),
        loadRoutines: () async => [catalogRoutine]);
    final card = (await assistant.reply('Find tutorials'))!.attachment!
        as FitnessFactsAttachment;
    // This fixture has a published cover but no authored tutorial, so it should
    // not be invented as a tutorial destination. The routine is still valid.
    expect(card.contentPreviews, isEmpty);
    final routine = (await assistant.reply('Recommend a workout for today'))!
        .attachment! as FitnessFactsAttachment;
    expect(routine.contentPreviews.single.imageUrl,
        'https://example.invalid/squat.jpg');
    expect(
        identical(
            routine.contentPreviews.single.action, routine.actions.single),
        isTrue);
  });
  test(
      'generic nutrition and equipment do not trigger history or catalog reads',
      () async {
    var reads = 0;
    final assistant = FitnessAssistantContext(
        scope: scope,
        isCurrent: () => true,
        loadProgress: () async {
          reads++;
          return LocalMemberProgressSnapshot(records: []);
        },
        loadRoutines: () async {
          reads++;
          return [];
        });
    expect(await assistant.reply('Explain protein for my workouts'), isNull);
    expect(await assistant.reply('Which equipment works my chest?'), isNull);
    expect(reads, 0);
  });
  test(
      'membership shows server expiry in Malaysia time and separates common benefits',
      () async {
    final expires = now.add(const Duration(days: 1)).millisecondsSinceEpoch;
    final assistant = FitnessAssistantContext(
        scope: scope,
        isCurrent: () => true,
        clock: () => now,
        loadProgress: () async => LocalMemberProgressSnapshot(records: []),
        loadMembership: () async => {
              'organizationId': 'org',
              'memberId': 'member',
              'entitlement': {
                'schemaVersion': 1,
                'policyVersion': 'gainpath-effective-membership-v1',
                'organizationId': 'org',
                'memberId': 'member',
                'resolvedAtMillis': now.millisecondsSinceEpoch,
                'status': 'resolved',
                'reason': 'active_paid_membership',
                'effectiveTier': 'basic',
                'paidTier': 'basic',
                'paidPlanId': 'basic',
                'paidPlanName': 'Basic',
                'paidExpiresAtMillis': expires,
                'paidStatus': 'active',
                'benefits': ['Gym access', 'Gym access', 'Coach booking']
              },
              'plans': [
                {
                  'name': 'Basic',
                  'benefits': ['Gym access', 'Coach booking', 'Gym access']
                },
                {
                  'name': 'Premium',
                  'benefits': [
                    'Gym access',
                    'Coach booking',
                    'Published premium reward'
                  ]
                }
              ]
            });
    final answer =
        (await assistant.reply('Compare Basic and Premium membership'))!;
    expect(values(answer),
        contains('Paid plan expiry: 2026-11-17 13:00 MYT (UTC+08:00)'));
    final rows = (answer.attachment! as FitnessFactsAttachment).facts;
    expect(rows.singleWhere((f) => f.label == 'Your verified benefits').value,
        'Gym access\nCoach booking');
    expect(
        rows.singleWhere((f) => f.label == 'Shared published benefits').value,
        'Gym access\nCoach booking');
    expect(
        rows
            .singleWhere(
                (f) => f.label == 'Premium — additional published benefits')
            .value,
        'Published premium reward');
  });
  test(
      'a passed recorded expiry cannot still be called current active membership',
      () async {
    final assistant = FitnessAssistantContext(
        scope: scope,
        isCurrent: () => true,
        clock: () => now,
        loadProgress: () async => LocalMemberProgressSnapshot(records: []),
        loadMembership: () async => {
              'organizationId': 'org',
              'memberId': 'member',
              'entitlement': {
                'schemaVersion': 1,
                'policyVersion': 'gainpath-effective-membership-v1',
                'organizationId': 'org',
                'memberId': 'member',
                'resolvedAtMillis': now
                    .subtract(const Duration(days: 2))
                    .millisecondsSinceEpoch,
                'status': 'resolved',
                'reason': 'active_paid_membership',
                'effectiveTier': 'premium',
                'paidTier': 'premium',
                'paidPlanId': 'premium',
                'paidPlanName': 'Premium',
                'paidExpiresAtMillis': now
                    .subtract(const Duration(days: 1))
                    .millisecondsSinceEpoch,
                'paidStatus': 'active',
                'benefits': ['Old benefit']
              },
              'plans': []
            });
    final rows = ((await assistant.reply('My membership'))!.attachment!
            as FitnessFactsAttachment)
        .facts;
    expect(rows.singleWhere((f) => f.label == 'Current effective plan').value,
        startsWith('Unknown'));
    expect(rows.any((f) => f.label == 'Your verified benefits'), isFalse);
  });
  test('latest records preserve unassessed score and actual partial reps',
      () async {
    final assistant = FitnessAssistantContext(
        scope: scope,
        isCurrent: () => true,
        clock: () => now,
        loadProgress: () async =>
            LocalMemberProgressSnapshot(records: [record()]));
    final answer = (await assistant.reply('How was my last workout?'))!;
    expect(values(answer), contains('7 full · 1 partial'));
    expect(values(answer), contains('Not assessed'));
    expect(values(answer).toLowerCase(), contains('not recorded'));
  });
  test('scoped records cannot be substituted from another Member', () async {
    final assistant = FitnessAssistantContext(
        scope: scope,
        isCurrent: () => true,
        clock: () => now,
        loadProgress: () async => LocalMemberProgressSnapshot(records: [
              record(
                  owner: SessionScope(userId: 'other', organizationId: 'org'))
            ]));
    await expectLater(
        assistant.reply('My progress'), throwsA(isA<ChatFailure>()));
  });
  test('incompatible score versions never form a combined trend', () async {
    final assistant = FitnessAssistantContext(
        scope: scope,
        isCurrent: () => true,
        clock: () => now,
        loadProgress: () async => LocalMemberProgressSnapshot(records: [
              record(score: 40),
              record(id: 'new', version: 'different', score: 90, minutes: 3)
            ]));
    final answer = (await assistant.reply('My progress'))!;
    expect(values(answer), isNot(contains('Limited observed change')));
  });
  test('FYP source stays explicitly recorded sample context', () async {
    final fyp = SessionScope(
        userId: 'fyp',
        organizationId: 'org',
        datasetScope: const VerifiedDatasetScope(
            datasetId: 'fyp-v1',
            seedId: 'seed',
            revision: 1,
            rootPath: 'orgs/org/cohorts/fyp-v1'));
    final assistant = FitnessAssistantContext(
        scope: fyp,
        isCurrent: () => true,
        clock: () => now,
        loadProgress: () async => LocalMemberProgressSnapshot(
            records: [record(owner: fyp)],
            warnings: ['Recorded fictional observations']));
    final answer = (await assistant.reply('My progress'))!;
    expect(answer.sources.single, contains('not physical camera evidence'));
    expect(values(answer), contains('fictional'));
  });
  test('future records are excluded from last workout', () async {
    final assistant = FitnessAssistantContext(
        scope: scope,
        isCurrent: () => true,
        clock: () => now,
        loadProgress: () async =>
            LocalMemberProgressSnapshot(records: [record(minutes: -3)]));
    expect((await assistant.reply('Last workout'))!.text,
        contains('No saved workout'));
  });
  test('tutorial and recommendation question intents remain distinct', () {
    expect(
        FitnessAssistantContext.intent(
            'Show me tutorials for my weak exercises'),
        'tutorials');
    expect(
        FitnessAssistantContext.intent('Why was this coach recommended to me?'),
        'recommendations');
    expect(FitnessAssistantContext.intent('Recommend a workout for today'),
        'routines');
  });
  test('published routines produce controlled tutorial and routine actions',
      () async {
    const ex = PublishedRoutineExercise(
        exerciseId: 'squat',
        dayNumber: 1,
        name: 'Squat',
        category: 'Strength',
        sets: 3,
        reps: 8,
        cue: 'Controlled movement',
        imageUrl: '',
        muscleGroup: 'Legs',
        tutorial: ExerciseTutorialDetails(steps: [
          ExerciseTutorialStep(
              title: 'Prepare', description: 'Stand comfortably')
        ]));
    final assistant = FitnessAssistantContext(
        scope: scope,
        isCurrent: () => true,
        clock: () => now,
        loadProgress: () async => LocalMemberProgressSnapshot(records: []),
        loadRoutines: () async => [
              const PublishedRoutine(
                  id: 'r',
                  sourceBlueprintId: 'b',
                  title: 'Foundation',
                  estimatedMinutes: 10,
                  exercises: [ex])
            ]);
    final tutorial = (await assistant.reply('Find tutorials'))!.attachment!
        as FitnessFactsAttachment;
    expect(tutorial.actions.single.target, FitnessFactTarget.tutorial);
    final routine = (await assistant.reply('Recommend a workout for today'))!
        .attachment! as FitnessFactsAttachment;
    expect(routine.actions.single.target, FitnessFactTarget.routine);
    expect(routine.actions.single.id, 'r');
  });
  test(
      'recommendation explanations use only delivered facts and unavailable targets stay closed',
      () async {
    final assistant = FitnessAssistantContext(
        scope: scope,
        isCurrent: () => true,
        clock: () => now,
        loadProgress: () async => LocalMemberProgressSnapshot(records: []),
        loadRecommendations: () async => MemberRecommendationPage(records: [
              MemberRecommendationDetail(
                  organizationId: 'org',
                  recommendationId: 'rec',
                  kind: RecommendationKind.content,
                  revision: 1,
                  state: MemberRecommendationState.unavailable,
                  title: 'Practice foundations',
                  summary: 'Existing summary',
                  explanations: ['Exact exercise match'],
                  createdAt: now.subtract(const Duration(days: 1)),
                  expiresAt: now.add(const Duration(days: 1)))
            ]));
    final answer = (await assistant.reply('My recommendations'))!;
    expect(values(answer), contains('Exact exercise match'));
    expect((answer.attachment! as FitnessFactsAttachment).actions, isEmpty);
  });
  test('membership rejects foreign ownership and never derives a plan',
      () async {
    final assistant = FitnessAssistantContext(
        scope: scope,
        isCurrent: () => true,
        loadProgress: () async => LocalMemberProgressSnapshot(records: []),
        loadMembership: () async =>
            {'organizationId': 'org', 'memberId': 'other'});
    await expectLater(assistant.reply('What benefits does Premium offer?'),
        throwsA(isA<ChatFailure>()));
  });
  test(
      'missing entitlement remains unknown while published benefits remain factual',
      () async {
    final assistant = FitnessAssistantContext(
        scope: scope,
        isCurrent: () => true,
        loadProgress: () async => LocalMemberProgressSnapshot(records: []),
        loadMembership: () async => {
              'organizationId': 'org',
              'memberId': 'member',
              'plans': [
                {
                  'name': 'Published Premium',
                  'benefits': ['Published benefit only']
                }
              ]
            });
    final answer =
        (await assistant.reply('What benefits does Premium offer?'))!;
    expect(values(answer), contains('Unknown'));
    expect(values(answer), contains('Published benefit only'));
  });
  test('generic education never loads personal records', () async {
    var reads = 0;
    final assistant = FitnessAssistantContext(
        scope: scope,
        isCurrent: () => true,
        loadProgress: () async {
          reads++;
          return LocalMemberProgressSnapshot(records: []);
        });
    expect(await assistant.reply('Explain progressive overload'), isNull);
    expect(reads, 0);
  });
  test('empty workouts stay unknown rather than fabricated measurements',
      () async {
    final assistant = FitnessAssistantContext(
        scope: scope,
        isCurrent: () => true,
        loadProgress: () async => LocalMemberProgressSnapshot(records: []));
    final reply = await assistant.reply('How was my last workout?');
    expect(reply!.attachment, isA<FitnessFactsAttachment>());
    expect(reply.text, contains('No saved workout'));
    expect(reply.text, isNot(contains('0%')));
  });
  test('account revocation after load suppresses personal facts', () async {
    var active = true;
    final assistant = FitnessAssistantContext(
        scope: scope,
        isCurrent: () => active,
        loadProgress: () async {
          active = false;
          return LocalMemberProgressSnapshot(records: []);
        });
    await expectLater(
        assistant.reply('My progress'), throwsA(isA<ChatFailure>()));
  });
}
