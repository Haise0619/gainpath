import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/chatbot.dart';
import 'package:gainpath_mobile/features/chatbot/presentation/member/assistant_reply_view_model.dart';

void main() {
  ChatMessage facts(String title, List<FitnessFact> rows,
          {List<FitnessFactAction> actions = const []}) =>
      ChatMessage('Original factual explanation.', false,
          attachment: FitnessFactsAttachment(
              title: title,
              subtitle: 'Saved records · bounded sample',
              facts: rows,
              actions: actions),
          sources: const ['GainPath source']);

  test('plain model text never becomes an actionable card', () {
    const text = '{"membership":"Premium","route":"/pay"}';
    final view =
        AssistantReplyViewModel.fromMessage(const ChatMessage(text, false));
    expect(view, isA<NormalTextReply>());
    expect(view.conclusion, text);
    expect(view.actions, isEmpty);
  });
  test(
      'membership distinguishes verified status and shows only three lead benefits',
      () {
    const action =
        FitnessFactAction('Open Membership', FitnessFactTarget.membership);
    final view =
        AssistantReplyViewModel.fromMessage(facts('Your membership', const [
      FitnessFact('Current effective plan', 'Basic'),
      FitnessFact('Your verified benefits',
          'Gym access\nCoach booking\nMini games\nRegular rewards'),
      FitnessFact('Source', 'Server response'),
    ], actions: [
      action
    ]));
    expect(view, isA<MembershipReply>());
    expect(view.currentTier, 'Basic');
    expect(view.conclusion, contains('Basic'));
    expect(view.highlights, ['Gym access', 'Coach booking', 'Mini games']);
    expect(view.moreBenefits, ['Regular rewards']);
    expect(view.benefitsLabel, 'Your verified benefits');
    expect(identical(view.actions.single, action), isTrue);
    expect(view.details.any((f) => f.label == 'Source'), isTrue);
  });
  test('unknown membership cannot be promoted to Premium from a published plan',
      () {
    final view =
        AssistantReplyViewModel.fromMessage(facts('Your membership', const [
      FitnessFact('Current effective plan',
          'Unknown — current entitlement could not be verified'),
      FitnessFact('Premium', 'Published Premium benefit'),
    ]));
    expect(view.currentTier, 'Unknown');
    expect(view.statusLabel, 'Needs verification');
    expect(view.conclusion, isNot(contains('Your current plan is Premium')));
    expect(view.highlights.single, 'Premium · Published Premium benefit');
    expect(view.benefitsLabel, 'Published plan options');
  });
  test('workout selects useful primary stats and preserves missing score', () {
    final view =
        AssistantReplyViewModel.fromMessage(facts('Your last workout', const [
      FitnessFact('Exercise', 'Squat'),
      FitnessFact('Repetitions', '7 full · 1 partial'),
      FitnessFact('Duration', '1m 0s'),
      FitnessFact('Estimated Form Score', 'Not assessed'),
      FitnessFact('Tracking', '30s tracked · 1s rejected'),
      FitnessFact('Sync status', 'localOnly'),
      FitnessFact('Sets', 'Not recorded for an individual capture'),
    ]));
    expect(view, isA<WorkoutSummaryReply>());
    expect(view.stats.length, 2);
    expect(view.highlights, contains('Form score not assessed.'));
    expect(view.statusLabel, 'Saved exercise capture');
    expect(view.conclusion, 'Your latest saved exercise is Squat.');
    expect(view.details.any((f) => f.label == 'Sync status'), isTrue);
  });
  test('unfinished routine is never presented as a completed workout', () {
    final view =
        AssistantReplyViewModel.fromMessage(facts('Your last workout', const [
      FitnessFact('Routine', 'Full Body Foundations'),
      FitnessFact('Saved record type', 'Unfinished routine'),
      FitnessFact('Status', 'In progress'),
      FitnessFact('Repetitions', '12 full · 2 partial'),
      FitnessFact('Duration', '3m 10s'),
      FitnessFact('Completed exercises', '1 / 3')
    ]));
    expect(view.conclusion, contains('unfinished'));
    expect(view.conclusion, isNot(contains('completed workout')));
    expect(view.stats.map((s) => s.label),
        ['Repetitions', 'Duration', 'Completed exercises']);
  });
  test('insight never invents improvement or merges separate score groups', () {
    final view = AssistantReplyViewModel.fromMessage(
        facts('Your training snapshot', const [
      FitnessFact('Available exercise captures', '3'),
      FitnessFact('Full / partial repetitions', '21 / 2'),
      FitnessFact('This Malaysia week', '2 captures · 14 full reps'),
      FitnessFact('Routine attempts', '1'),
      FitnessFact('squat · side', '78% estimated mean · 2 comparable captures'),
      FitnessFact('Limited observed change',
          '70% → 80% · same measurement group, not proof of improvement'),
    ]));
    expect(view, isA<TrainingInsightReply>());
    expect(view.stats.length, lessThanOrEqualTo(4));
    expect(view.stats.first.value, '78%');
    expect(view.conclusion, 'Your comparable squat captures average 78%.');
    expect(
        view.stats
            .any((s) => s.label == 'Comparable captures' && s.value == '2'),
        isTrue);
    expect(
        view.stats
            .any((s) => s.label == 'Observed change' && s.value == '70% → 80%'),
        isTrue);
    expect(view.conclusion, isNot(contains('improved')));
    expect(
        view.details.any((f) => f.value.contains('not proof of improvement')),
        isTrue);
  });
  test('recommendation retains exact authorized target and explanation', () {
    const action = FitnessFactAction(
        'Open tutorial', FitnessFactTarget.recommendation,
        id: 'rec-1');
    final view = AssistantReplyViewModel.fromMessage(
        facts('Why these recommendations?', const [
      FitnessFact('Practice foundations',
          'Saved recommendation summary\nExact exercise match\nCreated 2026-11-16 · available'),
    ], actions: [
      action
    ]));
    expect(view, isA<RecommendationReply>());
    expect(view.highlights.join(' '), contains('Exact exercise match'));
    expect(view.actions.single.id, 'rec-1');
    expect(view.conclusion, 'Practice foundations: Exact exercise match');
    expect(view.details.single.value, contains('Created 2026-11-16'));
  });
  test('error is explicit and preserves the retry instruction', () {
    final view = AssistantReplyViewModel.error('Connection unavailable.',
        retryLabel: 'Retry question');
    expect(view, isA<ErrorRetryReply>());
    expect(view.retryLabel, 'Retry question');
    expect(view.conclusion, 'Connection unavailable.');
    expect(view.actions, isEmpty);
  });
  test(
      'empty trusted records have a refresh action and preserve source meaning',
      () {
    final view = AssistantReplyViewModel.fromMessage(ChatMessage(
        'No delivered recommendations are available.', false,
        attachment: const FitnessFactsAttachment(
            title: 'Your recommendations',
            subtitle: 'Permission-scoped records',
            facts: [])));
    expect(view, isA<ErrorRetryReply>());
    expect(view.title, 'Your recommendations');
    expect(view.conclusion, 'No delivered recommendations are available.');
    expect(view.retryLabel, 'Refresh records');
    expect(view.sources, contains('Permission-scoped records'));
  });
  test('missing workout preserves the report target and exposes refresh', () {
    const target = FitnessFactAction(
        'View workout report', FitnessFactTarget.workoutReport);
    final view = AssistantReplyViewModel.fromMessage(facts('Your last workout',
        const [FitnessFact('Form Score', 'Not assessed — no eligible record')],
        actions: [target]));
    expect(view, isA<ErrorRetryReply>());
    expect(view.title, 'No saved workouts available');
    expect(view.retryLabel, 'Refresh records');
    expect(identical(view.actions.single, target), isTrue);
  });
  test('unscored FYP insight cannot claim measured form or improvement', () {
    final view = AssistantReplyViewModel.fromMessage(
        facts('Your training snapshot', const [
      FitnessFact('Available exercise captures', '3'),
      FitnessFact('squat · side', 'Not assessed'),
      FitnessFact('Record note',
          'Fictional recorded observations, not physical evidence'),
    ]));
    expect(view.conclusion, contains('No comparable form score'));
    expect(view.conclusion, isNot(contains('average')));
    expect(view.details.any((f) => f.value.contains('Fictional')), isTrue);
  });
  test(
      'routine long unknown-score explanation becomes a short note plus details',
      () {
    final view =
        AssistantReplyViewModel.fromMessage(facts('Your last workout', const [
      FitnessFact('Routine', 'Foundation'),
      FitnessFact('Status', 'Finished attempt'),
      FitnessFact('Duration', '5m 0s'),
      FitnessFact('Form Score',
          'Open the report for qualified per-exercise scores; no routine-wide score is inferred.'),
    ]));
    expect(
        view.stats.any((s) => s.value.startsWith('Open the report')), isFalse);
    expect(view.highlights, contains('Form score not assessed.'));
    expect(view.details.any((f) => f.label == 'Form Score'), isTrue);
  });
  test('coach directory preserves server option identities and quoted prices',
      () {
    final option = AssistantCoachOption(
        coachId: 'coach-1',
        name: 'Fixture Coach',
        branchName: 'Main',
        amountMinor: 12000);
    final view = AssistantReplyViewModel.fromMessage(ChatMessage(
        'Directory facts.', false,
        attachment: CoachDirectoryAttachment([option])));
    expect(view, isA<CoachActionReply>());
    expect(identical(view.coaches.single, option), isTrue);
    expect(view.coaches.single.amountMinor, 12000);
    expect(view.coaches.single.durationMinutes, 60);
    expect(view.booking, isNull);
    expect(view.conclusion, isNot(contains('reserved')));
  });
  test('empty coach directory exposes refresh without inventing options', () {
    final view = AssistantReplyViewModel.fromMessage(ChatMessage(
        'No eligible coaches on this page.', false,
        attachment: CoachDirectoryAttachment([]),
        sources: const ['Published coaches']));
    expect(view, isA<ErrorRetryReply>());
    expect(view.title, 'No coaches available');
    expect(view.retryLabel, 'Refresh coaches');
    expect(view.coaches, isEmpty);
  });
  test('booking view keeps unreserved status and the exact checkout attachment',
      () {
    final suggestion = BookingSuggestionAttachment.fromJson({
      'schemaVersion': 1,
      'coachId': 'coach-1',
      'coachName': 'Fixture Coach',
      'branchId': 'main',
      'branchName': 'Main',
      'localDate': '2030-01-01',
      'timeZone': 'Asia/Kuala_Lumpur',
      'startAtMillis': 1893488400000,
      'endAtMillis': 1893492000000,
      'startLabel': '9:00 AM',
      'endLabel': '10:00 AM',
      'durationMinutes': 60,
      'amountMinor': 12000,
      'currency': 'MYR',
      'expiresAtMillis': 1893488300000,
      'requiresConfirmation': true,
    });
    final view = AssistantReplyViewModel.fromMessage(
        ChatMessage('Suggestion only.', false, attachment: suggestion));
    expect(view, isA<CoachActionReply>());
    expect(identical(view.booking, suggestion), isTrue);
    expect(view.conclusion, contains('Nothing is reserved or paid'));
    expect(
        view.stats.singleWhere((s) => s.label == 'Price').value, 'RM 120.00');
    expect(view.stats.any((s) => s.label == 'Branch' && s.value == 'Main'),
        isTrue);
    expect(
        view.stats.any((s) => s.label == 'Duration' && s.value == '60 minutes'),
        isTrue);
  });
}
