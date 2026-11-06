Map<String, Object?> _object(Object? raw, List<String> fields) {
  if (raw is! Map ||
      raw.length != fields.length ||
      raw.keys.any((k) => k is! String || !fields.contains(k))) {
    throw const FormatException('Invalid recommendation fields.');
  }
  return Map<String, Object?>.from(raw);
}

String _text(Object? raw, [int max = 200]) {
  if (raw is! String ||
      raw.trim().isEmpty ||
      raw.length > max ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(raw)) {
    throw const FormatException('Invalid recommendation text.');
  }
  return raw;
}

String? _optional(Object? raw, [int max = 200]) =>
    raw == null ? null : _text(raw, max);
int _integer(Object? raw, [int min = 0, int max = 9007199254740991]) {
  if (raw is! num ||
      !raw.isFinite ||
      raw != raw.roundToDouble() ||
      raw < min ||
      raw > max) {
    throw const FormatException('Invalid recommendation count.');
  }
  return raw.toInt();
}

double? _measurement(Object? raw, double max) {
  if (raw == null) return null;
  if (raw is! num || !raw.isFinite || raw < 0 || raw > max) {
    throw const FormatException('Invalid recommendation measurement.');
  }
  return raw.toDouble();
}

String _enum(Object? raw, List<String> values) {
  if (raw is! String || !values.contains(raw)) {
    throw const FormatException('Invalid recommendation state.');
  }
  return raw;
}

List<Object?> _array(Object? raw, [int max = 100]) {
  if (raw is! List || raw.length > max) {
    throw const FormatException('Invalid recommendation list.');
  }
  return List<Object?>.from(raw);
}

List<String> _strings(Object? raw, [int max = 100, int length = 200]) {
  final result = _array(raw, max).map((e) => _text(e, length)).toList();
  if (result.toSet().length != result.length) {
    throw const FormatException('Duplicate recommendation values.');
  }
  return List.unmodifiable(result);
}

const queueStatuses = [
  'pending',
  'sent',
  'dismissed',
  'expired',
  'stale',
  'revoked'
];
String queueStatusLabel(String status) =>
    const {
      'all': 'All statuses',
      'pending': 'Pending',
      'sent': 'Prepared locally',
      'dismissed': 'Dismissed',
      'expired': 'Expired',
      'stale': 'Needs refresh',
      'revoked': 'Permission withdrawn'
    }[status] ??
    'Unavailable';
String queueObjectiveLabel(String objective) =>
    const {
      'technique_foundations': 'Technique foundations',
      'movement_control': 'Movement control',
      'progression': 'Progression',
      'endurance': 'Endurance'
    }[objective] ??
    'Unknown';
String malaysiaDate(DateTime time) => time
    .toUtc()
    .add(const Duration(hours: 8))
    .toIso8601String()
    .substring(0, 10);
String malaysiaTime(DateTime time) => time
    .toUtc()
    .add(const Duration(hours: 8))
    .toIso8601String()
    .substring(0, 16)
    .replaceFirst('T', ' ');

class RecommendationQueueQuery {
  const RecommendationQueueQuery(
      {required this.organizationId,
      required this.kind,
      required this.start,
      required this.end,
      this.status = 'pending',
      this.exerciseId,
      this.category,
      this.specialization,
      this.afterLeadId,
      this.limit = 25});
  final String organizationId, kind, status;
  final DateTime start, end;
  final String? exerciseId, category, specialization, afterLeadId;
  final int limit;
  factory RecommendationQueueQuery.recent(
      String org, String kind, DateTime now, int days) {
    if (days < 1 || days > 90) {
      throw const FormatException('Choose at most 90 days.');
    }
    final local = now.toUtc().add(const Duration(hours: 8));
    return RecommendationQueueQuery(
        organizationId: org,
        kind: kind,
        start: DateTime.utc(local.year, local.month, local.day)
            .subtract(Duration(days: days - 1, hours: 8)),
        end: now.toUtc());
  }
  factory RecommendationQueueQuery.calendar(
      String org, String kind, DateTime now, DateTime first, DateTime last) {
    final start = DateTime.utc(first.year, first.month, first.day)
        .subtract(const Duration(hours: 8));
    final end = DateTime.utc(last.year, last.month, last.day)
        .add(const Duration(hours: 16));
    final q = RecommendationQueueQuery(
        organizationId: org,
        kind: kind,
        start: start,
        end: end.isAfter(now.toUtc()) ? now.toUtc() : end);
    q.toJson();
    return q;
  }
  RecommendationQueueQuery filtered(
          {required String status,
          String? exerciseId,
          String? category,
          String? specialization,
          String? afterLeadId}) =>
      RecommendationQueueQuery(
          organizationId: organizationId,
          kind: kind,
          start: start,
          end: end,
          status: status,
          exerciseId: exerciseId,
          category: category,
          specialization: specialization,
          afterLeadId: afterLeadId,
          limit: limit);
  Map<String, Object?> toJson() {
    _text(organizationId, 128);
    _enum(kind, ['trainer', 'content']);
    _enum(status, ['all', ...queueStatuses]);
    if (!end.isAfter(start) ||
        end.difference(start) > const Duration(days: 90) ||
        start.millisecondsSinceEpoch <= 0 ||
        limit < 1 ||
        limit > 25 ||
        (kind == 'content' && specialization != null)) {
      throw const FormatException('Invalid queue query.');
    }
    for (final value in [exerciseId, category, specialization, afterLeadId]) {
      _optional(value, 128);
    }
    return {
      'schemaVersion': 1,
      'organizationId': organizationId,
      'kind': kind,
      'status': status,
      'startAtMillis': start.millisecondsSinceEpoch,
      'endAtMillis': end.millisecondsSinceEpoch,
      'exerciseId': exerciseId,
      'category': category,
      'specialization': specialization,
      'afterLeadId': afterLeadId,
      'limit': limit
    };
  }
}

class RecommendationQueueTarget {
  RecommendationQueueTarget._(this.kind,
      {this.branchId,
      this.observedStart,
      this.observedEnd,
      this.routineId,
      this.exerciseIndex,
      this.dayNumber});
  final String kind;
  final String? branchId, routineId;
  final DateTime? observedStart, observedEnd;
  final int? exerciseIndex, dayNumber;
  factory RecommendationQueueTarget.parse(
      Object? raw, String org, String expectedKind) {
    if (expectedKind == 'trainer') {
      final t = _object(raw, [
        'kind',
        'coachId',
        'branchId',
        'observedStartAtMillis',
        'observedEndAtMillis'
      ]);
      _enum(t['kind'], ['trainer']);
      _text(t['coachId'], 128);
      final start = _integer(t['observedStartAtMillis'], 1),
          end = _integer(t['observedEndAtMillis'], 1);
      if (end <= start || end - start > 3600000) {
        throw const FormatException('Invalid observed option.');
      }
      return RecommendationQueueTarget._('trainer',
          branchId: _text(t['branchId'], 128),
          observedStart:
              DateTime.fromMillisecondsSinceEpoch(start, isUtc: true),
          observedEnd: DateTime.fromMillisecondsSinceEpoch(end, isUtc: true));
    }
    final t = _object(raw, ['kind', 'destination']);
    _enum(t['kind'], ['content']);
    final d = _object(t['destination'], [
      'kind',
      'organizationId',
      'routineId',
      'exerciseIndex',
      'exerciseId',
      'dayNumber'
    ]);
    _enum(d['kind'], ['published_routine_exercise_tutorial']);
    if (d['organizationId'] != org) {
      throw const FormatException('Foreign destination.');
    }
    _text(d['exerciseId'], 128);
    return RecommendationQueueTarget._('content',
        routineId: _text(d['routineId'], 128),
        exerciseIndex: _integer(d['exerciseIndex'], 0, 49),
        dayNumber: _integer(d['dayNumber'], 1, 50));
  }
}

class RecommendationLead {
  RecommendationLead._(
      {required this.id,
      required this.organizationId,
      required this.kind,
      required this.memberLabel,
      required this.exerciseId,
      required this.exerciseLabel,
      required this.category,
      required this.targetLabel,
      required this.specialization,
      required this.branchLabel,
      required this.objective,
      required this.level,
      required this.target,
      required this.evidenceSummary,
      required this.scoredSessions,
      required this.score,
      required this.coverage,
      required this.sourceVersion,
      required this.configVersion,
      required this.origin,
      required this.explanations,
      required this.model,
      required this.promptVersion,
      required this.algorithmVersion,
      required this.fallbackReason,
      required this.createdAt,
      required this.expiresAt,
      required this.status,
      required this.revision,
      required this.dismissReason});
  final String id,
      organizationId,
      kind,
      memberLabel,
      exerciseId,
      exerciseLabel,
      category,
      targetLabel,
      objective,
      level,
      evidenceSummary,
      sourceVersion,
      configVersion,
      origin,
      promptVersion,
      algorithmVersion,
      status;
  final String? specialization,
      branchLabel,
      model,
      fallbackReason,
      dismissReason;
  final RecommendationQueueTarget target;
  final int? scoredSessions;
  final double? score, coverage;
  final List<String> explanations;
  final DateTime createdAt, expiresAt;
  final int revision;
  bool actionable(DateTime now) =>
      status == 'pending' && expiresAt.isAfter(now.toUtc());
  factory RecommendationLead.parse(Object? raw, String org) {
    final l = _object(raw, [
      'schemaVersion',
      'mode',
      'leadId',
      'organizationId',
      'memberId',
      'kind',
      'exerciseId',
      'objective',
      'level',
      'memberLabel',
      'exerciseLabel',
      'category',
      'targetLabel',
      'specialization',
      'branchLabel',
      'target',
      'evidence',
      'ranking',
      'sourceFingerprint',
      'memberFingerprint',
      'runId',
      'createdAtMillis',
      'expiresAtMillis',
      'status',
      'revision',
      'decision'
    ]);
    if (l['schemaVersion'] != 1 ||
        l['mode'] != 'synthetic_local' ||
        l['organizationId'] != org) {
      throw const FormatException('Unsupported recommendation scope.');
    }
    final kind = _enum(l['kind'], ['trainer', 'content']),
        status = _enum(l['status'], queueStatuses);
    for (final key in ['memberId', 'runId']) {
      _text(l[key], 128);
    }
    for (final key in ['sourceFingerprint', 'memberFingerprint']) {
      if (l[key] is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(l[key] as String)) {
        throw const FormatException('Invalid recommendation version.');
      }
    }
    final e = _object(l['evidence'], [
      'summary',
      'scoredSessions',
      'estimatedFormScorePercent',
      'coverage',
      'sourceVersion',
      'configVersion'
    ]);
    final r = _object(l['ranking'], [
      'origin',
      'reasonCodes',
      'explanations',
      'model',
      'promptVersion',
      'algorithmVersion',
      'fallbackReason'
    ]);
    for (final reason in _strings(r['reasonCodes'], 6, 40)) {
      _enum(reason, [
        'exercise_match',
        'objective_match',
        'level_match',
        'available_slot',
        'experience',
        'instructional_focus'
      ]);
    }
    final created = _integer(l['createdAtMillis'], 1),
        expires = _integer(l['expiresAtMillis'], 1);
    if (expires <= created) {
      throw const FormatException('Invalid recommendation dates.');
    }
    String? dismissReason;
    if (l['decision'] != null) {
      final d = _object(l['decision'], [
        'actorId',
        'atMillis',
        'commandId',
        'reason',
        'recipientRecommendationId'
      ]);
      _text(d['actorId'], 128);
      _text(d['commandId'], 128);
      _integer(d['atMillis'], created);
      _optional(d['recipientRecommendationId'], 128);
      dismissReason = _optional(d['reason'], 300);
      if (status == 'pending') {
        throw const FormatException('Pending decision conflict.');
      }
    } else if (status == 'sent' || status == 'dismissed') {
      throw const FormatException('Missing recommendation decision.');
    }
    return RecommendationLead._(
        id: _text(l['leadId'], 128),
        organizationId: org,
        kind: kind,
        memberLabel: _text(l['memberLabel'], 120),
        exerciseId: _text(l['exerciseId'], 128),
        exerciseLabel: _text(l['exerciseLabel'], 120),
        category: _text(l['category'], 120),
        targetLabel: _text(l['targetLabel'], 120),
        specialization: _optional(l['specialization'], 120),
        branchLabel: _optional(l['branchLabel'], 120),
        objective: _enum(l['objective'], [
          'technique_foundations',
          'movement_control',
          'progression',
          'endurance'
        ]),
        level: _enum(l['level'], ['beginner', 'intermediate', 'advanced']),
        target: RecommendationQueueTarget.parse(l['target'], org, kind),
        evidenceSummary: _text(e['summary'], 400),
        scoredSessions:
            e['scoredSessions'] == null ? null : _integer(e['scoredSessions']),
        score: _measurement(e['estimatedFormScorePercent'], 100),
        coverage: _measurement(e['coverage'], 1),
        sourceVersion: _text(e['sourceVersion'], 128),
        configVersion: _text(e['configVersion'], 128),
        origin: _enum(r['origin'], [
          'ai_reranked',
          'deterministic_fallback',
          'deterministic_single_candidate'
        ]),
        explanations: List.unmodifiable(
            _array(r['explanations'], 6).map((s) => _text(s, 300))),
        model: _optional(r['model'], 128),
        promptVersion: _text(r['promptVersion'], 128),
        algorithmVersion: _text(r['algorithmVersion'], 128),
        fallbackReason: _optional(r['fallbackReason'], 128),
        createdAt: DateTime.fromMillisecondsSinceEpoch(created, isUtc: true),
        expiresAt: DateTime.fromMillisecondsSinceEpoch(expires, isUtc: true),
        status: status,
        revision: _integer(l['revision'], 1),
        dismissReason: dismissReason);
  }
}

const queueAbstentionLabels = <String, String>{
  'insufficient_evidence': 'Insufficient evidence',
  'unsupported_evidence': 'Unsupported exercise evidence',
  'missing_consent': 'Required permission unavailable',
  'no_eligible_candidates': 'No eligible candidates',
  'semantic_abstention': 'No supported ranking suggestion',
};

class QueueGenerationSummary {
  QueueGenerationSummary._(
      this.runId,
      this.kind,
      this.status,
      this.processed,
      this.candidateCount,
      this.generated,
      this.abstained,
      this.fallbackCount,
      this.nextCursor,
      this.failureCode,
      this.algorithmVersion,
      this.model,
      this.updatedAt,
      this.abstentionReasons);
  final String runId, kind, status, algorithmVersion;
  final String? nextCursor, failureCode, model;
  final int processed, candidateCount, generated, abstained, fallbackCount;
  final DateTime updatedAt;
  final Map<String, int> abstentionReasons;
  factory QueueGenerationSummary.parse(Object? raw, String kind) {
    final r = _object(raw, [
      'runId',
      'kind',
      'status',
      'processed',
      'candidateCount',
      'generated',
      'abstained',
      'abstentionReasons',
      'fallbackCount',
      'nextCursor',
      'failureCode',
      'algorithmVersion',
      'model',
      'updatedAtMillis'
    ]);
    if (r['kind'] != kind) {
      throw const FormatException('Foreign generation kind.');
    }
    final reasons =
        _object(r['abstentionReasons'], queueAbstentionLabels.keys.toList())
            .map((key, value) => MapEntry(key, _integer(value)));
    if (reasons.values.fold<int>(0, (total, count) => total + count) !=
        _integer(r['abstained'])) {
      throw const FormatException('Inconsistent abstention totals.');
    }
    return QueueGenerationSummary._(
        _text(r['runId'], 128),
        kind,
        _enum(r['status'], ['in_progress', 'complete', 'failed']),
        _integer(r['processed']),
        _integer(r['candidateCount']),
        _integer(r['generated']),
        _integer(r['abstained']),
        _integer(r['fallbackCount']),
        _optional(r['nextCursor'], 256),
        _optional(r['failureCode'], 128),
        _text(r['algorithmVersion'], 128),
        _optional(r['model'], 128),
        DateTime.fromMillisecondsSinceEpoch(_integer(r['updatedAtMillis'], 1),
            isUtc: true),
        Map.unmodifiable(reasons));
  }
}

class QueueExerciseChoice {
  const QueueExerciseChoice(this.id, this.label);
  final String id, label;
}

class RecommendationQueuePage {
  RecommendationQueuePage._(
      {required this.leads,
      required this.nextAfterLeadId,
      required this.pending,
      required this.processed,
      required this.unavailable,
      required this.exercises,
      required this.categories,
      required this.specializations,
      required this.generation,
      required this.capturedAt});
  final List<RecommendationLead> leads;
  final String? nextAfterLeadId;
  final int pending, processed, unavailable;
  final List<QueueExerciseChoice> exercises;
  final List<String> categories, specializations;
  final QueueGenerationSummary? generation;
  final DateTime capturedAt;
  factory RecommendationQueuePage.parse(
      Object? raw, RecommendationQueueQuery query) {
    query.toJson();
    final p = _object(raw, [
      'schemaVersion',
      'mode',
      'organizationId',
      'kind',
      'capturedAtMillis',
      'leads',
      'nextAfterLeadId',
      'summary',
      'facets',
      'generation'
    ]);
    if (p['schemaVersion'] != 1 ||
        p['mode'] != 'synthetic_local' ||
        p['organizationId'] != query.organizationId ||
        p['kind'] != query.kind) {
      throw const FormatException('Unsupported queue scope.');
    }
    final leads = _array(p['leads'], query.limit)
        .map((r) => RecommendationLead.parse(r, query.organizationId))
        .toList();
    String? previous = query.afterLeadId;
    for (final l in leads) {
      if (l.kind != query.kind ||
          (query.status != 'all' && l.status != query.status) ||
          l.createdAt.isBefore(query.start) ||
          !l.createdAt.isBefore(query.end) ||
          (query.exerciseId != null && l.exerciseId != query.exerciseId) ||
          (query.category != null && l.category != query.category) ||
          (query.specialization != null &&
              l.specialization != query.specialization) ||
          (previous != null && l.id.compareTo(previous) <= 0)) {
        throw const FormatException('Queue query drift.');
      }
      previous = l.id;
    }
    final next = _optional(p['nextAfterLeadId'], 128);
    if (next != null && (leads.isEmpty || next != leads.last.id)) {
      throw const FormatException('Invalid queue cursor.');
    }
    final s = _object(p['summary'], ['pending', 'processed', 'unavailable']),
        f = _object(
            p['facets'], ['exercises', 'categories', 'specializations']);
    final exercises = _array(f['exercises']).map((v) {
      final e = _object(v, ['id', 'label']);
      return QueueExerciseChoice(_text(e['id'], 128), _text(e['label'], 120));
    }).toList();
    if (exercises.map((e) => e.id).toSet().length != exercises.length) {
      throw const FormatException('Duplicate exercise choice.');
    }
    return RecommendationQueuePage._(
        leads: List.unmodifiable(leads),
        nextAfterLeadId: next,
        pending: _integer(s['pending']),
        processed: _integer(s['processed']),
        unavailable: _integer(s['unavailable']),
        exercises: List.unmodifiable(exercises),
        categories: _strings(f['categories'], 100, 120),
        specializations: _strings(f['specializations'], 100, 120),
        generation: p['generation'] == null
            ? null
            : QueueGenerationSummary.parse(p['generation'], query.kind),
        capturedAt: DateTime.fromMillisecondsSinceEpoch(
            _integer(p['capturedAtMillis'], 1),
            isUtc: true));
  }
}

class RecommendationDecisionReceipt {
  RecommendationDecisionReceipt._(this.leadId, this.revision, this.status,
      this.outcome, this.deliveryStatus);
  final String leadId, status, outcome, deliveryStatus;
  final int revision;
  factory RecommendationDecisionReceipt.parse(
      Object? raw, String org, String leadId) {
    final r = _object(raw, [
      'schemaVersion',
      'organizationId',
      'leadId',
      'revision',
      'status',
      'outcome',
      'recipientRecommendationId',
      'deliveryStatus'
    ]);
    if (r['schemaVersion'] != 1 ||
        r['organizationId'] != org ||
        r['leadId'] != leadId) {
      throw const FormatException('Foreign decision receipt.');
    }
    final outcome = _enum(r['outcome'], ['prepared', 'dismissed', 'blocked']),
        status = _enum(r['status'], queueStatuses),
        delivery =
            _enum(r['deliveryStatus'], ['prepared_local', 'not_prepared']);
    _optional(r['recipientRecommendationId'], 128);
    if ((outcome == 'prepared' &&
            (status != 'sent' ||
                delivery != 'prepared_local' ||
                r['recipientRecommendationId'] == null)) ||
        (outcome == 'dismissed' && status != 'dismissed') ||
        (outcome != 'prepared' && delivery != 'not_prepared')) {
      throw const FormatException('Inconsistent decision receipt.');
    }
    return RecommendationDecisionReceipt._(
        leadId, _integer(r['revision'], 1), status, outcome, delivery);
  }
}
