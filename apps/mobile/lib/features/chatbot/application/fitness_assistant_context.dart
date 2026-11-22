import 'dart:async';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_domain/chatbot.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/membership.dart';
import '../../analytics/domain/local_member_progress_repository.dart';
import '../../analytics/domain/member_workout_report.dart';
import '../../recommendation/domain/member_recommendation.dart';
import '../../workout/domain/published_routine_view.dart';
import '../../workout/domain/workout_contracts.dart';
import 'package:gainpath_domain/workout.dart' show exerciseImageUri;

/// Small, read-only contextual assistant. No personal facts reach the provider.
/// Dependencies retain their existing Auth, consent and publication guards.
class FitnessAssistantContext {
  FitnessAssistantContext(
      {required this.scope,
      required this.isCurrent,
      required this.loadProgress,
      this.loadProfile,
      this.loadRoutines,
      this.loadRecommendations,
      this.loadMembership,
      DateTime Function()? clock})
      : clock = clock ?? DateTime.now;
  final SessionScope scope;
  final bool Function() isCurrent;
  final DateTime Function() clock;
  final Future<LocalMemberProgressSnapshot> Function() loadProgress;
  final Future<FitnessProfile?> Function()? loadProfile;
  final Future<List<PublishedRoutine>> Function()? loadRoutines;
  final Future<MemberRecommendationPage> Function()? loadRecommendations;
  final Future<Map<String, dynamic>> Function()? loadMembership;
  final Map<String, PublishedRoutineExercise> tutorialTargets = {};
  final Map<String, PublishedRoutine> routineTargets = {};
  final Map<String, MemberRecommendationDetail> recommendationTargets = {};
  List<PublishedRoutine> _catalogSnapshot = const [];

  void _check() {
    if (!isCurrent()) {
      tutorialTargets.clear();
      routineTargets.clear();
      recommendationTargets.clear();
      _catalogSnapshot = const [];
      throw const ChatFailure(
          'permission-denied', 'Your account changed. Reopen the assistant.');
    }
  }

  Future<T> _read<T>(Future<T> Function() read) async {
    _check();
    final result = await read().timeout(const Duration(seconds: 12));
    _check();
    return result;
  }

  ChatMessage _facts(String text, String title, List<FitnessFact> facts,
          {List<FitnessFactAction> actions = const [],
          List<FitnessContentPreview> contentPreviews = const [],
          String? source}) =>
      ChatMessage(text, false,
          attachment: FitnessFactsAttachment(
              title: title,
              subtitle:
                  source ?? 'Authorized GainPath records · not sent to Gemini',
              facts: List.unmodifiable(facts),
              contentPreviews: List.unmodifiable(contentPreviews),
              actions: List.unmodifiable(actions)),
          sources: [source ?? 'GainPath records']);

  static String? intent(String text) {
    final q = text.toLowerCase();
    if (RegExp(r'\b(membership|premium|basic|free plan|my plan benefits)\b')
        .hasMatch(q)) {
      return 'membership';
    }
    if (RegExp(r'\b(protein|food|nutrition|recipes?|calories|equipment|machines?)\b')
            .hasMatch(q) &&
        !RegExp(r'\b(my workout progress|my workout history|last workout)\b')
            .hasMatch(q)) {
      return null;
    }
    if (RegExp(r'\b(recommendations?|recommended)\b').hasMatch(q) &&
        RegExp(r'\b(why|coach|tutorial|my|existing)\b').hasMatch(q)) {
      return 'recommendations';
    }
    if (RegExp(r'\b(tutorials?|weak exercises?|form guidance|improve in my)\b')
        .hasMatch(q)) {
      return 'tutorials';
    }
    if (RegExp(r'\b(recommend|suggest|plan)\b').hasMatch(q) &&
        RegExp(r'\b(workout|routine|today|training)\b').hasMatch(q)) {
      return 'routines';
    }
    if (RegExp(
            r'\b(my progress|workout progress|progress trending|progress trend|summary of my progress|my workout history)\b')
        .hasMatch(q)) {
      return 'progress';
    }
    if (RegExp(r'\b(unfinished|in progress|incomplete)\b').hasMatch(q) &&
        RegExp(r'\b(routine|workout|attempt)\b').hasMatch(q)) {
      return 'latest';
    }
    if (RegExp(r'\b(last|latest|recent|previous)\b').hasMatch(q) &&
        RegExp(r'\b(workout|exercise|training|session|capture|record)\b')
            .hasMatch(q)) {
      return 'latest';
    }
    if (RegExp(r'\b(my|me)\b').hasMatch(q) &&
        RegExp(r'\b(progress|form score|pose feedback|squats?|repetitions|reps|completed workouts?|history)\b')
            .hasMatch(q)) {
      return 'progress';
    }
    return null;
  }

  Future<ChatMessage?> reply(String text) async {
    _check();
    if (RegExp(
            r'diagnos|\bpain\b|injur|faint|dizz|suicid|self.harm|overdose|steroid|prescri|extreme.{0,15}(diet|weight)|starv',
            caseSensitive: false)
        .hasMatch(text)) {
      return const ChatMessage(
          'I can provide general fitness education, but cannot diagnose conditions, prescribe treatment, or help with unsafe training or drug use. Stop exercising if you feel unwell and seek a qualified clinician. For severe symptoms or immediate danger, contact local emergency services.',
          false,
          sources: ['GainPath safety guidance']);
    }
    final kind = intent(text);
    if (kind == null) return null;
    try {
      return switch (kind) {
        'membership' => await _membership(text),
        'recommendations' => await _recommendations(),
        'tutorials' ||
        'routines' =>
          await _catalog(text, tutorial: kind == 'tutorials'),
        _ => await _workouts(text, latest: kind == 'latest'),
      };
    } on ChatFailure {
      rethrow;
    } on TimeoutException {
      throw const ChatFailure('deadline-exceeded',
          'Reading your records took too long. Your question is safe to retry.');
    } catch (_) {
      _check();
      throw const ChatFailure('unavailable',
          'Your records could not be loaded. Retry or open the relevant GainPath page. No facts were guessed.');
    }
  }

  Future<LocalMemberProgressSnapshot> _progress() async {
    final snapshot = await _read(loadProgress);
    if (snapshot.records.any((r) => r.scope != scope) ||
        snapshot.attempts.any((a) => a.scope != scope) ||
        snapshot.summaries.values.any((s) =>
            s.userId != scope.userId ||
            s.organizationId != scope.organizationId ||
            s.datasetScope != scope.datasetScope)) {
      throw const ChatFailure(
          'permission-denied', 'These records belong to a different account.');
    }
    // Recorded FYP observations can explain exercise context but are never
    // promoted into measured score/trend facts. Actual camera summaries retain
    // their existing, validated nullable score.
    final records = snapshot.records.map((r) {
      final summary = snapshot.summaries[r.sessionId];
      final unscored = const {
        'single-arm-row-side-v1',
        'reverse-lunge-side-v1',
        'dumbbell-shoulder-press-front-v1',
        'standing-lateral-raise-front-v1'
      }.contains(r.scoringVersion);
      if (!unscored &&
          (scope.datasetScope == null ||
              summary?.provenance == WorkoutProvenance.realCamera)) {
        return r;
      }
      return LocalWorkoutProgressRecord(
          scope: r.scope,
          sessionId: r.sessionId,
          exerciseId: r.exerciseId,
          startedAt: r.startedAt,
          endedAt: r.endedAt,
          repetitions: r.repetitions,
          partialRepetitions: r.partialRepetitions,
          trackedDurationMicros: r.trackedDurationMicros,
          rejectedDurationMicros: r.rejectedDurationMicros,
          formScorePercent: null,
          scoringVersion: r.scoringVersion,
          detectorId: r.detectorId,
          detectorVersion: r.detectorVersion,
          cameraView: r.cameraView,
          status: r.status,
          armMode: r.armMode,
          acceptedAt: r.acceptedAt);
    });
    return LocalMemberProgressSnapshot(
        records: records,
        summaries: snapshot.summaries,
        attempts: snapshot.attempts,
        warnings: snapshot.warnings,
        routineHistoryAvailable: snapshot.routineHistoryAvailable);
  }

  String _exercise(String id, Map<String, String> names) =>
      names[id] ??
      (RegExp(r'^[a-z]{2,18}(?:[-_][a-z]{2,18}){0,3}$').hasMatch(id)
          ? id
              .split(RegExp(r'[-_]'))
              .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
              .join(' ')
          : 'Saved exercise');

  Set<String> _words(String text) => text
      .toLowerCase()
      .split(RegExp(r'[^a-z]+'))
      .where((w) => w.length > 2)
      .map((w) => w.endsWith('s') && !w.endsWith('ss')
          ? w.substring(0, w.length - 1)
          : w)
      .toSet();
  String _malaysiaTime(DateTime date) =>
      '${date.toUtc().add(const Duration(hours: 8)).toIso8601String().substring(0, 16).replaceFirst('T', ' ')} MYT (UTC+08:00)';
  Future<ChatMessage> _workouts(String query, {required bool latest}) async {
    final snapshot = await _progress();
    // Reuse names already fetched for this session's content requests. A
    // history question must not wait for another catalogue network request.
    final catalog = _catalogSnapshot;
    _check();
    final names = <String, String>{
      for (final a in snapshot.attempts)
        for (final e in a.routine.exercises) e.exerciseId: e.name,
      for (final r in catalog)
        for (final e in r.exercises) e.exerciseId: e.name
    };
    final queryWords = _words(query);
    final requested = <String>{};
    for (final id in {
      ...names.keys,
      ...snapshot.records.map((r) => r.exerciseId)
    }) {
      final terms =
          _words('${names[id] ?? ''} ${id.replaceAll(RegExp(r'[-_]'), ' ')}')
            ..removeAll({
              'bodyweight',
              'standing',
              'standard',
              'dumbbell',
              'barbell',
              'front',
              'side',
              'left',
              'right',
              'published',
              'exercise',
              'workout',
              'routine',
              'training',
              'progress',
              'form',
              'session',
              'capture',
              'history'
            });
      if (terms.any(queryWords.contains)) requested.add(id);
    }
    if (requested.isEmpty &&
        queryWords.intersection({
          'squat',
          'curl',
          'calf',
          'lunge',
          'row',
          'press',
          'raise',
          'pushup'
        }).isNotEmpty) {
      requested.add('__requested_exercise_unavailable__');
    }
    final lower = query.toLowerCase();
    final explicitCapture = RegExp(r'\bcapture\b').hasMatch(lower);
    final explicitSaved = RegExp(r'\bsaved\b').hasMatch(lower) &&
        RegExp(r'\b(record|workout|routine|attempt)\b').hasMatch(lower);
    final unfinished =
        RegExp(r'\b(unfinished|in progress|incomplete)\b').hasMatch(lower);
    final completed = RegExp(r'\bcompleted\b').hasMatch(lower) && latest;
    final now = clock();
    final records = snapshot.records
        .where((r) =>
            !r.endedAt.isAfter(now) &&
            (requested.isEmpty || requested.contains(r.exerciseId)))
        .toList()
      ..sort((a, b) => b.endedAt.compareTo(a.endedAt));
    final attempts = snapshot.attempts
        .where((a) =>
            (requested.isEmpty ||
                a.routine.exercises
                    .any((e) => requested.contains(e.exerciseId))) &&
            a.startedAtMicros != null &&
            a.startedAtMicros! <= now.microsecondsSinceEpoch &&
            (a.finishedAtMicros ?? a.updatedAtMicros) <=
                now.microsecondsSinceEpoch)
        .toList()
      ..sort((a, b) => (b.finishedAtMicros ?? b.updatedAtMicros)
          .compareTo(a.finishedAtMicros ?? a.updatedAtMicros));
    final eligibleAttempts = attempts
        .where((a) => explicitSaved
            ? true
            : unfinished
                ? !a.finished
                : a.isComplete && a.finishedAtMicros != null)
        .toList();
    final routineSessionIds =
        attempts.expand((a) => a.entries.expand((e) => e.sessionIds)).toSet();
    final independentRecords =
        records.where((r) => !routineSessionIds.contains(r.sessionId)).toList();
    final selectedRoutine = latest &&
            !explicitCapture &&
            (requested.isEmpty || records.isEmpty || completed || unfinished) &&
            eligibleAttempts.isNotEmpty &&
            (completed ||
                unfinished ||
                independentRecords.isEmpty ||
                (eligibleAttempts.first.finishedAtMicros ??
                        eligibleAttempts.first.updatedAtMicros) >=
                    independentRecords.first.endedAt.microsecondsSinceEpoch)
        ? eligibleAttempts.first
        : null;
    final source = scope.datasetScope != null
        ? 'FYP recorded history · not physical camera evidence'
        : 'Saved device records / synced summaries · not server-accepted evidence';
    final facts = <FitnessFact>[];
    String message;
    if (latest &&
        (unfinished || completed || records.isEmpty && attempts.isNotEmpty) &&
        selectedRoutine == null) {
      message = unfinished
          ? 'No unfinished routine is available in the saved records.'
          : 'No completed routine workout is available in the saved records. Individual exercise captures are not proof of a completed routine.';
      facts.add(const FitnessFact(
          'Form Score', 'Not assessed — no matching routine record'));
    } else if (records.isEmpty && attempts.isEmpty ||
        latest && explicitCapture && records.isEmpty) {
      message =
          'No saved workout records are available here. This does not mean you have never trained.';
      facts.add(
          const FitnessFact('Form Score', 'Not assessed — no eligible record'));
    } else if (selectedRoutine != null) {
      final a = selectedRoutine;
      message =
          'Here is your latest saved routine attempt. Completed, partial and self-reported activity stay separate.';
      facts.add(FitnessFact('Routine', a.routine.title));
      facts.add(FitnessFact('Saved record type',
          a.isComplete ? 'Completed routine' : 'Unfinished routine'));
      facts.add(FitnessFact('Status', a.statusLabel));
      final matchingEntries = a.entries
          .where((e) =>
              requested.isEmpty ||
              requested.contains(a.routine.exercises[e.index].exerciseId))
          .toList();
      final full =
              matchingEntries.fold<int>(0, (n, e) => n + e.fullRepetitions),
          partial =
              matchingEntries.fold<int>(0, (n, e) => n + e.partialRepetitions),
          manual = matchingEntries.fold<int>(0, (n, e) => n + e.manualSets);
      facts.add(FitnessFact('Repetitions', '$full full · $partial partial'));
      facts.add(FitnessFact('Completed exercises',
          '${matchingEntries.where((e) => e.completed).length} / ${matchingEntries.length}${requested.isEmpty ? '' : ' matching exercises'}'));
      facts.add(FitnessFact(
          'Self-reported sets', '$manual · separate from camera repetitions'));
      if (a.finishedAtMicros != null) {
        facts.add(FitnessFact(
            'Completed',
            _malaysiaTime(DateTime.fromMicrosecondsSinceEpoch(
                a.finishedAtMicros!,
                isUtc: true))));
      }
      for (final entry in matchingEntries.take(8)) {
        final ex = a.routine.exercises[entry.index];
        facts.add(FitnessFact(
            ex.name,
            '${entry.status.name} · ${entry.fullRepetitions} tracked reps · ${entry.partialRepetitions} partial reps'
            '${entry.manualSets > 0 ? ' · ${entry.manualSets} self-reported sets' : ''}'));
      }
      if (requested.isNotEmpty) {
        final tracked = matchingEntries.fold<int>(
            0,
            (n, e) =>
                n +
                e.trackedDurationMicros +
                (e.guided?.totalActiveMicroseconds ?? 0));
        facts.add(FitnessFact(
            'Duration',
            tracked == 0
                ? 'Not recorded for this exercise'
                : '${reportDuration(tracked)} tracked for this exercise'));
      } else if (a.startedAtMicros != null && a.finishedAtMicros != null) {
        facts.add(FitnessFact('Duration',
            reportDuration(a.finishedAtMicros! - a.startedAtMicros!)));
      }
      facts.add(const FitnessFact('Form Score',
          'Open the report for qualified per-exercise scores; no routine-wide score is inferred.'));
    } else if (latest && records.isNotEmpty) {
      final r = records.first;
      message =
          'Here is your latest saved exercise capture. Estimated form is guidance, not a medical assessment.';
      facts.addAll([
        FitnessFact('Exercise', _exercise(r.exerciseId, names)),
        const FitnessFact('Saved record type', 'Saved exercise capture'),
        FitnessFact('Completed', _malaysiaTime(r.endedAt)),
        FitnessFact('Repetitions',
            '${r.repetitions} full · ${r.partialRepetitions} partial'),
        FitnessFact('Sets', 'Not recorded for an individual capture'),
        FitnessFact('Duration',
            reportDuration(r.endedAt.difference(r.startedAt).inMicroseconds)),
        FitnessFact(
            'Estimated Form Score',
            r.formScorePercent == null
                ? 'Not assessed'
                : '${r.formScorePercent!.toStringAsFixed(1)}% · ${r.cameraView} view'),
        FitnessFact('Tracking',
            '${r.trackedDurationMicros ~/ 1000000}s tracked · ${r.rejectedDurationMicros ~/ 1000000}s rejected'),
        FitnessFact('Sync status', r.status.name)
      ]);
      final metrics = snapshot.summaries[r.sessionId]?.poseMetrics;
      if (metrics != null && metrics.deviations.isNotEmpty) {
        facts.add(FitnessFact(
            'Saved pose observations',
            metrics.deviations.entries
                .map((e) =>
                    '${e.key}: ${e.value.count} saved observations, maximum ${e.value.maximumDegrees.toStringAsFixed(1)}°')
                .take(4)
                .join(' · ')));
      } else {
        facts.add(const FitnessFact('Pose feedback',
            'No saved specific correction is available; no posture issue is inferred.'));
      }
    } else {
      final progress = calculateLocalMemberProgress(
          scope: scope, records: records, asOf: now);
      message =
          'This is a summary of the saved records available to this account. Only compatible exercise, scoring version and camera-view measurements are compared.';
      facts.addAll([
        FitnessFact('Available exercise captures', '${records.length}'),
        FitnessFact('Full / partial repetitions',
            '${progress.allTimeRepetitions} / ${progress.allTimePartialRepetitions}'),
        FitnessFact('This Malaysia week',
            '${progress.weeklySessions} captures · ${progress.weeklyRepetitions} full reps'),
        FitnessFact('Routine attempts',
            '${attempts.length} · kept separate from exercise captures')
      ]);
      for (final group in progress.formSeries.take(3)) {
        facts.add(FitnessFact(
            '${_exercise(group.exerciseId, names)} · ${group.cameraView}',
            group.meanScore == null
                ? 'Not assessed'
                : '${group.meanScore!.toStringAsFixed(1)}% estimated mean · ${group.records.length} comparable captures'));
        final scored = group.records
            .where((r) => r.formScorePercent != null)
            .toList()
          ..sort((a, b) => a.endedAt.compareTo(b.endedAt));
        if (scored.length >= 2) {
          facts.add(FitnessFact('Limited observed change',
              '${scored.first.formScorePercent!.toStringAsFixed(1)}% → ${scored.last.formScorePercent!.toStringAsFixed(1)}% · same measurement group, not proof of improvement'));
        }
      }
    }
    for (final warning in snapshot.warnings.take(2)) {
      facts.add(FitnessFact('Record note', warning));
    }
    return _facts(
        message, latest ? 'Your last workout' : 'Your training snapshot', facts,
        source: source,
        actions: const [
          FitnessFactAction(
              'View workout report', FitnessFactTarget.workoutReport)
        ]);
  }

  Future<ChatMessage> _catalog(String query, {required bool tutorial}) async {
    final catalog = loadRoutines;
    if (catalog == null) {
      return _facts('Published content is unavailable for this account.',
          'Tutorials & routines', const []);
    }
    final routines = await _read(catalog);
    _catalogSnapshot = List.unmodifiable(routines);
    final profile = loadProfile == null ? null : await _read(loadProfile!);
    final snapshot = await _progress();
    final recent = snapshot.records.toList()
      ..sort((a, b) => b.endedAt.compareTo(a.endedAt));
    final lower = query.toLowerCase();
    final matches = <(PublishedRoutine, PublishedRoutineExercise)>[];
    for (final routine in routines) {
      if (profile?.experience == TrainingExperience.beginner &&
          routine.difficulty == 'Advanced') {
        continue;
      }
      for (final ex in routine.exercises) {
        if (tutorial &&
            ex.tutorial.steps.isEmpty &&
            (ex.videoUrl?.trim().isEmpty ?? true)) {
          continue;
        }
        matches.add((routine, ex));
      }
    }
    int rank((PublishedRoutine, PublishedRoutineExercise) row) {
      final ex = row.$2;
      var score = 0;
      if (lower.contains(ex.name.toLowerCase()) ||
          lower.contains(ex.exerciseId.replaceAll('-', ' '))) {
        score += 20;
      }
      if (recent.take(5).any((r) => r.exerciseId == ex.exerciseId)) score += 10;
      if (profile != null &&
          row.$1.difficulty?.toLowerCase() == profile.experience.name) {
        score += 3;
      }
      for (final goal in profile?.goals ?? <FitnessGoal>{}) {
        final terms =
            goal.label.toLowerCase().split(' ').where((w) => w.length > 4);
        if (terms.any((w) => '${row.$1.title} ${ex.category} ${ex.muscleGroup}'
            .toLowerCase()
            .contains(w))) {
          score += 2;
        }
      }
      return score;
    }

    matches.sort((a, b) {
      final diff = rank(b).compareTo(rank(a));
      return diff != 0 ? diff : a.$1.id.compareTo(b.$1.id);
    });
    final selected = <(PublishedRoutine, PublishedRoutineExercise)>[];
    for (final row in matches) {
      if (selected.every((e) => tutorial
          ? e.$2.exerciseId != row.$2.exerciseId
          : e.$1.id != row.$1.id)) {
        selected.add(row);
      }
      if (selected.length == 3) break;
    }
    tutorialTargets.clear();
    routineTargets.clear();
    final facts = <FitnessFact>[
      FitnessFact(
          'Your stated goals',
          profile == null
              ? 'No profile available; no goals inferred'
              : profile.goals.map((g) => g.label).join(', ')),
      FitnessFact(
          'Matching basis',
          recent.isEmpty
              ? 'Current published content and stated experience; no workout history available'
              : 'Recent saved exercise context and stated experience; no weakness or medical need inferred')
    ];
    final actions = <FitnessFactAction>[];
    final previews = <FitnessContentPreview>[];
    for (final row in selected) {
      final ex = row.$2, routine = row.$1;
      final key =
          '${routine.id}:${ex.dayNumber}:${routine.exercises.indexOf(ex)}';
      tutorialTargets[key] = ex;
      routineTargets[routine.id] = routine;
      facts.add(FitnessFact(routine.title,
          '${ex.name} · ${ex.sets} prescribed sets · ${ex.reps == null ? '${ex.durationSeconds}s' : '${ex.reps} reps'} · ${routine.estimatedMinutes} estimated minutes'));
      final action = tutorial
          ? FitnessFactAction(
              'View ${ex.name} tutorial', FitnessFactTarget.tutorial, id: key)
          : FitnessFactAction(
              'View ${routine.title}', FitnessFactTarget.routine,
              id: routine.id);
      actions.add(action);
      for (final candidate in [ex.tutorial.coverImageUrl, ex.imageUrl]) {
        final uri = exerciseImageUri(candidate);
        if (uri != null) {
          previews.add(FitnessContentPreview(
              title: tutorial ? ex.name : routine.title,
              imageUrl: uri.toString(),
              action: action));
          break;
        }
      }
    }
    return _facts(
        selected.isEmpty
            ? 'No matching published content was found in this catalog page. No tutorial or routine was invented.'
            : 'Here are published options to review. These are educational suggestions, not a saved training plan or a diagnosis of weak exercises.',
        tutorial ? 'Tutorials for your training' : 'Options for today',
        facts,
        actions: actions,
        contentPreviews: previews,
        source:
            'Published GainPath catalog · bounded first page · personal context stays in GainPath');
  }

  Future<ChatMessage> _recommendations() async {
    if (loadRecommendations == null) {
      return _facts('Recommendations are unavailable for this account.',
          'Your recommendations', const []);
    }
    final page = await _read(loadRecommendations!);
    recommendationTargets.clear();
    final facts = <FitnessFact>[];
    final actions = <FitnessFactAction>[];
    for (final item in page.records.take(3)) {
      if (item.organizationId != scope.organizationId) {
        throw const ChatFailure(
            'permission-denied', 'Recommendation scope changed.');
      }
      facts.add(FitnessFact(item.title,
          '${item.summary}\n${item.explanations.join('\n')}\nCreated ${reportDate(item.createdAt)} · ${item.state.name}'));
      if (item.available && item.expiresAt.isAfter(clock())) {
        recommendationTargets[item.recommendationId] = item;
        actions.add(FitnessFactAction(
            'Open ${item.targetLabel ?? 'recommendation'}',
            FitnessFactTarget.recommendation,
            id: item.recommendationId));
      }
    }
    return _facts(
        !page.enabled
            ? 'Personalized recommendations are not enabled here. Check your recommendation privacy settings.'
            : page.records.isEmpty
                ? 'No delivered recommendations are available. No new recommendation was generated.'
                : 'These explanations come from your existing delivered recommendations. Their destinations are checked again when opened.',
        'Why these recommendations?',
        facts,
        actions: actions,
        source: scope.datasetScope != null
            ? 'Existing FYP recommendations · recorded sample context'
            : 'Existing Module 13 recommendations · permission-scoped');
  }

  Future<ChatMessage> _membership(String query) async {
    if (loadMembership == null) {
      return _facts(
          'Membership details are unavailable. Open Membership for your current plan.',
          'Membership', const [],
          actions: const [
            FitnessFactAction('Open Membership', FitnessFactTarget.membership)
          ]);
    }
    final data = await _read(loadMembership!);
    if (data['organizationId'] != scope.organizationId ||
        data['memberId'] != scope.userId) {
      throw const ChatFailure(
          'permission-denied', 'Membership belongs to a different account.');
    }
    final rawEntitlement = data['entitlement'];
    final entitlement = rawEntitlement is Map
        ? MembershipEntitlement.fromJson(
            Map<String, dynamic>.from(rawEntitlement),
            expectedOrganizationId: scope.organizationId,
            expectedMemberId: scope.userId,
            historicalOnly: data['cached'] == true)
        : MembershipEntitlement.fromOverview(data);
    final expiry = entitlement.paidExpiresAtMillis;
    final staleExpiry = entitlement.paidStatus == PaidMembershipStatus.active &&
        expiry != null &&
        expiry <= clock().millisecondsSinceEpoch;
    final current =
        entitlement.isResolved && !entitlement.historicalOnly && !staleExpiry;
    final requestedPlans = ['Free', 'Basic', 'Premium']
        .where((tier) =>
            RegExp('\\b${tier.toLowerCase()}\\b').hasMatch(query.toLowerCase()))
        .toList();
    List<String> uniqueBenefits(Iterable<String> values) {
      final seen = <String>{};
      return values
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty && seen.add(s.toLowerCase()))
          .toList();
    }

    final facts = <FitnessFact>[
      if (requestedPlans.isNotEmpty)
        FitnessFact(
            'Requested plan',
            requestedPlans.length > 1
                ? 'Compare plans'
                : requestedPlans.single),
      FitnessFact(
          'Current effective plan',
          !current
              ? 'Unknown — current entitlement could not be verified'
              : entitlement.effectiveTier!.label),
      const FitnessFact('Free digital fitness',
          'Digital fitness is available to Members; a paid plan is not required to ask the assistant.'),
      FitnessFact(
          'Paid plan status',
          staleExpiry
              ? 'Needs refresh — recorded expiry has passed'
              : entitlement.historicalOnly
                  ? 'Historical snapshot — not current access'
                  : entitlement.paidStatus.name),
      FitnessFact(
          'Paid plan expiry',
          expiry == null
              ? (entitlement.isResolved &&
                      entitlement.paidStatus == PaidMembershipStatus.none
                  ? 'Not applicable — no paid plan'
                  : 'Unknown')
              : _malaysiaTime(
                  DateTime.fromMillisecondsSinceEpoch(expiry, isUtc: true))),
      if (current && entitlement.benefits.isNotEmpty)
        FitnessFact('Your verified benefits',
            uniqueBenefits(entitlement.benefits).join('\n')),
      if (entitlement.historicalOnly)
        const FitnessFact('Source',
            'Cached historical snapshot — not proof of current access'),
    ];
    final plans = data['plans'];
    if (plans is List) {
      final published = <(String, List<String>)>[];
      for (final plan in plans.take(10)) {
        if (plan is Map &&
            plan['name'] is String &&
            plan['benefits'] is List &&
            (plan['benefits'] as List).every((v) => v is String)) {
          published.add((
            plan['name'] as String,
            uniqueBenefits((plan['benefits'] as List).cast<String>())
          ));
        }
      }
      final common = published.length < 2
          ? <String>[]
          : published.first.$2
              .where((benefit) => published.skip(1).every((p) =>
                  p.$2.any((b) => b.toLowerCase() == benefit.toLowerCase())))
              .toList();
      if (common.isNotEmpty) {
        facts.add(FitnessFact('Shared published benefits', common.join('\n')));
      }
      for (final plan in published) {
        final extra = plan.$2
            .where(
                (b) => !common.any((c) => c.toLowerCase() == b.toLowerCase()))
            .toList();
        facts.add(FitnessFact(
            common.isEmpty
                ? plan.$1
                : '${plan.$1} — additional published benefits',
            extra.isEmpty
                ? 'No additional benefit is listed beyond the shared published benefits.'
                : extra.join('\n')));
      }
    }
    return _facts(
        'Here are the plan details returned by GainPath. Published plan benefits and your current entitlement are separate; checkout revalidates any purchase.',
        'Your membership',
        facts,
        actions: const [
          FitnessFactAction('Open Membership', FitnessFactTarget.membership)
        ],
        source:
            'Membership service · ${data['cached'] == true ? 'historical cache' : 'server response'}');
  }
}
