import 'package:gainpath_domain/chatbot.dart';

enum AssistantReplyKind {
  normalText,
  membership,
  workoutSummary,
  trainingInsight,
  coachAction,
  recommendation,
  errorRetry,
}

class AssistantReplyStat {
  const AssistantReplyStat(this.label, this.value);
  final String label, value;
}

/// Presentation only. These values come from existing typed, authorized replies.
/// No model text is parsed into facts, actions, URLs or business decisions.
sealed class AssistantReplyViewModel {
  const AssistantReplyViewModel(this.kind, this._data);
  final AssistantReplyKind kind;
  final _ReplyData _data;
  String get title => _data.title;
  String get conclusion => _data.conclusion;
  List<AssistantReplyStat> get stats => _data.stats;
  List<String> get highlights => _data.highlights;
  List<FitnessFact> get details => _data.details;
  List<String> get sources => _data.sources;
  List<FitnessFactAction> get actions => _data.actions;
  List<String> get moreBenefits => _data.moreBenefits;
  String? get currentTier => _data.currentTier;
  String? get statusLabel => _data.statusLabel;
  String? get benefitsLabel => _data.benefitsLabel;
  String? get retryLabel => _data.retryLabel;
  BookingSuggestionAttachment? get booking => _data.booking;
  List<AssistantCoachOption> get coaches => _data.coaches;

  factory AssistantReplyViewModel.fromMessage(ChatMessage message) {
    final attachment = message.attachment;
    if (attachment is BookingSuggestionAttachment) {
      return _booking(message, attachment);
    }
    if (attachment is CoachDirectoryAttachment) {
      if (attachment.coaches.isEmpty) {
        return ErrorRetryReply._(_ReplyData(
            title: 'No coaches available',
            conclusion: message.text,
            retryLabel: 'Refresh coaches',
            sources: message.sources));
      }
      return CoachActionReply._(_ReplyData(
          title: 'Find your coach',
          conclusion: attachment.coaches.isEmpty
              ? message.text
              : 'Explore these coaches and review a session before booking.',
          coaches: attachment.coaches,
          sources: message.sources));
    }
    if (attachment is FitnessFactsAttachment) {
      final noWorkout = const ['Your last workout', 'Your training snapshot']
              .contains(attachment.title) &&
          !attachment.facts.any((f) => const [
                'Exercise',
                'Routine',
                'Available exercise captures'
              ].contains(f.label));
      if (noWorkout || attachment.facts.isEmpty && attachment.actions.isEmpty) {
        return ErrorRetryReply._(_ReplyData(
            title: noWorkout ? 'No saved workouts available' : attachment.title,
            conclusion: message.text,
            retryLabel: 'Refresh records',
            details: attachment.facts,
            sources: _sources(message, attachment),
            actions: attachment.actions));
      }
      if (attachment.actions
              .any((a) => a.target == FitnessFactTarget.membership) ||
          attachment.title == 'Your membership' ||
          attachment.title == 'Membership') {
        return _membership(message, attachment);
      }
      if (attachment.title == 'Your last workout') {
        return _workout(message, attachment);
      }
      if (attachment.title == 'Your training snapshot') {
        return _insight(message, attachment);
      }
      return _recommendation(message, attachment);
    }
    return NormalTextReply._(_ReplyData(
        title: '', conclusion: message.text, sources: message.sources));
  }

  factory AssistantReplyViewModel.error(String message,
          {String retryLabel = 'Try again',
          String title = 'Unable to complete your request'}) =>
      ErrorRetryReply._(_ReplyData(
          title: title, conclusion: message, retryLabel: retryLabel));
}

final class NormalTextReply extends AssistantReplyViewModel {
  const NormalTextReply._(_ReplyData data)
      : super(AssistantReplyKind.normalText, data);
}

final class MembershipReply extends AssistantReplyViewModel {
  const MembershipReply._(_ReplyData data)
      : super(AssistantReplyKind.membership, data);
}

final class WorkoutSummaryReply extends AssistantReplyViewModel {
  const WorkoutSummaryReply._(_ReplyData data)
      : super(AssistantReplyKind.workoutSummary, data);
}

final class TrainingInsightReply extends AssistantReplyViewModel {
  const TrainingInsightReply._(_ReplyData data)
      : super(AssistantReplyKind.trainingInsight, data);
}

final class CoachActionReply extends AssistantReplyViewModel {
  const CoachActionReply._(_ReplyData data)
      : super(AssistantReplyKind.coachAction, data);
}

final class RecommendationReply extends AssistantReplyViewModel {
  const RecommendationReply._(_ReplyData data)
      : super(AssistantReplyKind.recommendation, data);
}

final class ErrorRetryReply extends AssistantReplyViewModel {
  const ErrorRetryReply._(_ReplyData data)
      : super(AssistantReplyKind.errorRetry, data);
}

class _ReplyData {
  _ReplyData(
      {required this.title,
      required this.conclusion,
      Iterable<AssistantReplyStat> stats = const [],
      Iterable<String> highlights = const [],
      Iterable<FitnessFact> details = const [],
      Iterable<String> sources = const [],
      Iterable<FitnessFactAction> actions = const [],
      Iterable<String> moreBenefits = const [],
      Iterable<AssistantCoachOption> coaches = const [],
      this.currentTier,
      this.statusLabel,
      this.benefitsLabel,
      this.retryLabel,
      this.booking})
      : stats = List.unmodifiable(stats),
        highlights = List.unmodifiable(highlights),
        details = List.unmodifiable(details),
        sources = List.unmodifiable(sources),
        actions = List.unmodifiable(actions),
        moreBenefits = List.unmodifiable(moreBenefits),
        coaches = List.unmodifiable(coaches);
  final String title, conclusion;
  final List<AssistantReplyStat> stats;
  final List<String> highlights, sources, moreBenefits;
  final List<FitnessFact> details;
  final List<FitnessFactAction> actions;
  final List<AssistantCoachOption> coaches;
  final String? currentTier, statusLabel, benefitsLabel, retryLabel;
  final BookingSuggestionAttachment? booking;
}

List<String> _sources(ChatMessage message, FitnessFactsAttachment facts) => {
      if (facts.subtitle.isNotEmpty) facts.subtitle,
      ...message.sources
    }.toList();

FitnessFact? _fact(FitnessFactsAttachment facts, String label) {
  for (final fact in facts.facts) {
    if (fact.label == label) return fact;
  }
  return null;
}

String _humanLabel(String label) => switch (label) {
      'Current effective plan' => 'Current plan',
      'Available exercise captures' => 'Saved captures',
      'Full / partial repetitions' => 'Full / partial reps',
      'This Malaysia week' => 'This week · Malaysia',
      'Estimated Form Score' => 'Estimated form',
      'Form Score' => 'Estimated form',
      _ => label,
    };

MembershipReply _membership(ChatMessage message, FitnessFactsAttachment facts) {
  final plan = _fact(facts, 'Current effective plan');
  final knownTier =
      plan != null && const ['Free', 'Basic', 'Premium'].contains(plan.value);
  final tier = knownTier ? plan.value : 'Unknown';
  final historical = facts.facts.any((f) =>
          f.label == 'Source' && f.value.toLowerCase().contains('cached')) ||
      facts.subtitle.toLowerCase().contains('historical cache');
  final status = historical
      ? 'Historical snapshot'
      : knownTier
          ? 'Current plan'
          : 'Needs verification';
  final verified = _fact(facts, 'Your verified benefits');
  final benefits = <String>[];
  if (verified != null) {
    benefits.addAll(
        verified.value.split('\n').where((line) => line.trim().isNotEmpty));
  } else {
    for (final fact in facts.facts) {
      if (const ['Current effective plan', 'Source', 'Free digital fitness']
          .contains(fact.label)) {
        continue;
      }
      for (final line
          in fact.value.split('\n').where((line) => line.trim().isNotEmpty)) {
        benefits.add('${fact.label} · $line');
      }
    }
  }
  return MembershipReply._(_ReplyData(
      title: 'Your membership',
      conclusion: historical
          ? 'This is a historical membership snapshot. Verify your current plan in Membership.'
          : knownTier
              ? 'Your current plan is $tier.'
              : 'Your current membership could not be verified.',
      currentTier: tier,
      statusLabel: status,
      benefitsLabel: verified == null
          ? 'Published plan options'
          : 'Your verified benefits',
      stats: [
        AssistantReplyStat('Current plan', tier),
        AssistantReplyStat('Status', status)
      ],
      highlights: benefits.take(3),
      moreBenefits: benefits.skip(3),
      // Published plan facts remain separate from the member's active benefits.
      details: facts.facts.where((f) => f != plan && f != verified),
      sources: _sources(message, facts),
      actions: facts.actions));
}

WorkoutSummaryReply _workout(
    ChatMessage message, FitnessFactsAttachment facts) {
  final name = _fact(facts, 'Exercise') ?? _fact(facts, 'Routine');
  final status = _fact(facts, 'Status')?.value ??
      (name?.label == 'Exercise' ? 'Saved exercise capture' : null);
  final primary = <FitnessFact>[];
  final unassessedNote = <String>[];
  for (final label in [
    'Repetitions',
    'Duration',
    'Estimated Form Score',
    'Form Score',
    'Status'
  ]) {
    final value = _fact(facts, label);
    if (value != null && primary.length < 4) {
      if (const ['Form Score', 'Estimated Form Score'].contains(label) &&
          value.value.length > 50) {
        unassessedNote.add('Form score not assessed.');
      } else {
        primary.add(value);
      }
    }
  }
  return WorkoutSummaryReply._(_ReplyData(
      title: 'Your last workout',
      conclusion: name == null
          ? message.text
          : 'Your latest saved ${name.label == 'Routine' ? 'routine' : 'exercise'} is ${name.value}.',
      statusLabel: status,
      highlights: unassessedNote,
      stats: [
        ...primary
            .map((f) => AssistantReplyStat(_humanLabel(f.label), f.value)),
        if (name != null &&
            status != null &&
            primary.length < 4 &&
            _fact(facts, 'Status') == null)
          AssistantReplyStat('Record', status),
      ],
      // Tracking, synchronization, unavailable sets and exact observations are
      // preserved in Details instead of competing with the primary metrics.
      details: facts.facts.where((f) => f != name && !primary.contains(f)),
      sources: _sources(message, facts),
      actions: facts.actions));
}

TrainingInsightReply _insight(
    ChatMessage message, FitnessFactsAttachment facts) {
  // The shape is produced by FitnessAssistantContext, not by model prose.
  final groups = facts.facts
      .where((f) =>
          f.label.contains(' · ') &&
          (f.value.contains('comparable captures') ||
              f.value == 'Not assessed'))
      .toList();
  final assessed = groups.where((f) => f.value != 'Not assessed').toList();
  final stats = <AssistantReplyStat>[];
  final used = <FitnessFact>[];
  String? conclusion;
  if (assessed.isNotEmpty) {
    final group = assessed.first;
    final match =
        RegExp(r'^(\d+(?:\.\d+)?)% estimated mean · (\d+) comparable captures$')
            .firstMatch(group.value);
    if (match != null) {
      final exercise = group.label.split(' · ').first;
      conclusion = 'Your comparable $exercise captures average ${match[1]}%.';
      stats.add(AssistantReplyStat('Estimated mean', '${match[1]}%'));
      stats.add(AssistantReplyStat('Comparable captures', match[2]!));
      final index = facts.facts.indexOf(group);
      if (index + 1 < facts.facts.length &&
          facts.facts[index + 1].label == 'Limited observed change') {
        // The following fact belongs to this exact compatible group. Do not
        // accidentally pair another exercise/version group's change.
        stats.add(AssistantReplyStat('Observed change',
            facts.facts[index + 1].value.split(' · ').first));
      }
    } else {
      conclusion =
          'Your comparable form scores are summarized below. These observations do not establish improvement.';
      stats.add(AssistantReplyStat(group.label, group.value));
    }
  }
  for (final label in [
    'This Malaysia week',
    'Full / partial repetitions',
    'Available exercise captures',
    'Routine attempts'
  ]) {
    final value = _fact(facts, label);
    if (value != null && stats.length < 4) {
      stats.add(AssistantReplyStat(_humanLabel(value.label), value.value));
      used.add(value);
    }
  }
  return TrainingInsightReply._(_ReplyData(
      title: 'Your training snapshot',
      conclusion: conclusion ??
          (stats.isEmpty
              ? message.text
              : 'Here is your saved training activity. No comparable form score is available to infer a trend.'),
      stats: stats,
      highlights: assessed.isEmpty
          ? const []
          : const [
              'Estimated form uses compatible measurements only; an observed change is not proof of improvement.'
            ],
      details: facts.facts.where((f) => !used.contains(f)),
      sources: _sources(message, facts),
      actions: facts.actions));
}

RecommendationReply _recommendation(
    ChatMessage message, FitnessFactsAttachment facts) {
  final highlights = <String>[];
  final details = <FitnessFact>[];
  final existingRecommendation = facts.title == 'Why these recommendations?' ||
      facts.actions.any((a) => a.target == FitnessFactTarget.recommendation);
  String? recordedConclusion;
  for (final fact in facts.facts) {
    if (const ['Your stated goals', 'Matching basis', 'Record note', 'Source']
        .contains(fact.label)) {
      details.add(fact);
      continue;
    }
    // These line breaks belong to the existing deterministic recommendation
    // projection, not model text. Keep all source lines in Details as well.
    final lines =
        fact.value.split('\n').where((line) => line.trim().isNotEmpty).toList();
    if (existingRecommendation) {
      final content =
          lines.where((line) => !line.startsWith('Created ')).toList();
      if (content.isNotEmpty) {
        final reason = content.length > 1 ? content[1] : content.first;
        recordedConclusion ??= '${fact.label}: $reason';
        highlights.addAll(content.take(2));
      }
    } else {
      highlights.add(
          '${fact.label}${lines.isEmpty ? '' : ' · ${lines.take(2).join(' · ')}'}');
    }
    details.add(fact);
  }
  return RecommendationReply._(_ReplyData(
      title: facts.title,
      conclusion: recordedConclusion ??
          (facts.facts.isEmpty
              ? message.text
              : facts.actions
                      .any((a) => a.target == FitnessFactTarget.recommendation)
                  ? 'These are your existing recommendations and their recorded reasons.'
                  : facts.actions
                          .any((a) => a.target == FitnessFactTarget.routine)
                      ? 'Review these published routines for your next session.'
                      : facts.actions.any(
                              (a) => a.target == FitnessFactTarget.tutorial)
                          ? 'Explore these published tutorials for your training.'
                          : message.text),
      highlights: highlights.take(3),
      details: details,
      sources: _sources(message, facts),
      actions: facts.actions));
}

CoachActionReply _booking(
    ChatMessage message, BookingSuggestionAttachment suggestion) {
  final data = suggestion.data;
  return CoachActionReply._(_ReplyData(
      title: 'Your coaching session',
      conclusion:
          'Review this session with ${data['coachName']}. Nothing is reserved or paid.',
      stats: [
        AssistantReplyStat('Coach', data['coachName'] as String),
        AssistantReplyStat('Branch', data['branchName'] as String),
        AssistantReplyStat('Duration', '${suggestion.durationMinutes} minutes'),
        AssistantReplyStat('Price',
            'RM ${((data['amountMinor'] as int) / 100).toStringAsFixed(2)}')
      ],
      highlights: [
        '${suggestion.localDate} · ${data['startLabel']} – ${data['endLabel']}'
      ],
      details: [
        FitnessFact('Date', suggestion.localDate),
        FitnessFact('Time', '${data['startLabel']} – ${data['endLabel']}'),
        FitnessFact('Timezone', data['timeZone'] as String),
        const FitnessFact('Booking status',
            'Suggestion only. Availability and price are checked again in checkout.')
      ],
      sources: message.sources,
      booking: suggestion));
}
