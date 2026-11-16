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
          String id = 'capture',
          int minutes = 1}) =>
      LocalWorkoutProgressRecord(
          scope: owner ?? scope,
          sessionId: id,
          exerciseId: 'squat',
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
