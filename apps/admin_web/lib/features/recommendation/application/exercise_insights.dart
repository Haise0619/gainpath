Map<String, Object?> _map(Object? raw, Set<String> keys) {
  if (raw is! Map ||
      raw.keys.any((k) => k is! String) ||
      raw.length != keys.length ||
      !raw.keys.toSet().containsAll(keys)) {
    throw const FormatException('Invalid exercise insights fields.');
  }
  return Map<String, Object?>.from(raw);
}

int _int(Object? raw, [int max = 2000]) {
  if (raw is! num ||
      !raw.isFinite ||
      raw != raw.roundToDouble() ||
      raw < 0 ||
      raw > max) {
    throw const FormatException('Invalid insights count.');
  }
  return raw.toInt();
}

String _text(Object? raw, [int max = 200]) {
  if (raw is! String ||
      raw.trim().isEmpty ||
      raw.length > max ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(raw)) {
    throw const FormatException('Invalid insights text.');
  }
  return raw;
}

List<Object?> _list(Object? raw, [int max = 2000]) {
  if (raw is! List || raw.length > max) {
    throw const FormatException('Invalid insights list.');
  }
  return List<Object?>.from(raw);
}

double? _ratio(Object? raw, double max) {
  if (raw == null) return null;
  if (raw is! num || !raw.isFinite || raw < 0 || raw > max) {
    throw const FormatException('Invalid insights measurement.');
  }
  return raw.toDouble();
}

String _enum(Object? raw, Set<String> values) {
  if (raw is! String || !values.contains(raw)) {
    throw const FormatException('Invalid insights state.');
  }
  return raw;
}

String _day(DateTime utc) => utc
    .toUtc()
    .add(const Duration(hours: 8))
    .toIso8601String()
    .substring(0, 10);

class ExerciseInsightsQuery {
  final String organizationId;
  final DateTime start, end;
  const ExerciseInsightsQuery(this.organizationId, this.start, this.end);
  factory ExerciseInsightsQuery.recent(String org, DateTime now, int days) {
    if (days < 1 || days > 90) {
      throw const FormatException('Choose at most 90 days.');
    }
    final local = now.toUtc().add(const Duration(hours: 8));
    final start = DateTime.utc(local.year, local.month, local.day)
        .subtract(Duration(days: days - 1, hours: 8));
    return ExerciseInsightsQuery(org, start, now.toUtc());
  }
  factory ExerciseInsightsQuery.calendar(
      String org, DateTime now, DateTime first, DateTime last) {
    final from = DateTime.utc(first.year, first.month, first.day)
        .subtract(const Duration(hours: 8));
    final selectedEnd = DateTime.utc(last.year, last.month, last.day)
        .add(const Duration(days: 1))
        .subtract(const Duration(hours: 8));
    final q = ExerciseInsightsQuery(org, from,
        selectedEnd.isAfter(now.toUtc()) ? now.toUtc() : selectedEnd);
    q.validate();
    return q;
  }
  void validate() {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(organizationId) ||
        !start.isBefore(end) ||
        end.difference(start) > const Duration(days: 90) ||
        start.millisecondsSinceEpoch < 0) {
      throw const FormatException('Invalid insights range.');
    }
  }

  String get malaysiaLabel =>
      '${_day(start)} – ${_day(end.subtract(const Duration(milliseconds: 1)))}';
  Map<String, Object?> toJson() => {
        'schemaVersion': 1,
        'organizationId': organizationId,
        'startAtMillis': start.millisecondsSinceEpoch,
        'endAtMillis': end.millisecondsSinceEpoch
      };
}

class ExerciseInsightGroup {
  final String name,
      category,
      exerciseId,
      evidenceState,
      attention,
      scoreSupport;
  final int members, sessions, scoredSessions, missingScores, unscoredSessions;
  final double? score, coverage;
  final Map<String, Object?> compatibility;
  ExerciseInsightGroup._(
      this.name,
      this.category,
      this.exerciseId,
      this.evidenceState,
      this.attention,
      this.scoreSupport,
      this.members,
      this.sessions,
      this.scoredSessions,
      this.missingScores,
      this.unscoredSessions,
      this.score,
      this.coverage,
      this.compatibility);
  factory ExerciseInsightGroup.parse(Object? raw) {
    final g = _map(
        raw, {'name', 'category', 'compatibility', 'metrics', 'attention'});
    final c = _map(g['compatibility'], {
      'exerciseId',
      'metricSchemaVersion',
      'scoringVersion',
      'detectorId',
      'detectorVersion',
      'cameraView',
      'mode',
      'scoreSupport'
    });
    for (final key in [
      'exerciseId',
      'scoringVersion',
      'detectorId',
      'detectorVersion'
    ]) {
      if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(_text(c[key], 128))) {
        throw const FormatException('Invalid compatibility.');
      }
    }
    if (_int(c['metricSchemaVersion'], 6) < 1) {
      throw const FormatException('Invalid metric schema.');
    }
    _enum(c['cameraView'], {'side', 'front'});
    _enum(c['mode'],
        {'not_applicable', 'both', 'leftOnly', 'rightOnly', 'left', 'right'});
    final support = _enum(c['scoreSupport'], {'scored', 'unscored'});
    final m = _map(g['metrics'], {
      'sessions',
      'members',
      'scoredSessions',
      'missingScoreSessions',
      'unscoredSessions',
      'assessedAttempts',
      'distinctSessionDays',
      'meanEstimatedFormScore',
      'trackingCoverage',
      'evidenceState'
    });
    final sessions = _int(m['sessions']),
        members = _int(m['members'], 200),
        scored = _int(m['scoredSessions']),
        missing = _int(m['missingScoreSessions']),
        unscored = _int(m['unscoredSessions']);
    _int(m['assessedAttempts'], 20000000);
    _int(m['distinctSessionDays'], 91);
    final score = _ratio(m['meanEstimatedFormScore'], 100),
        coverage = _ratio(m['trackingCoverage'], 1);
    final state = _enum(m['evidenceState'], {
      'policy_not_configured',
      'insufficient_evidence',
      'meets_provisional_minimums',
      'no_scored_samples',
      'unscored'
    });
    final attention =
        _enum(g['attention'], {'not_assessed', 'attention', 'within_policy'});
    if (members < 1 ||
        sessions < members ||
        scored + missing + unscored != sessions ||
        (scored == 0) != (score == null) ||
        (support == 'unscored' &&
            (scored != 0 || missing != 0 || state != 'unscored')) ||
        (support == 'scored' && unscored != 0) ||
        (attention != 'not_assessed' &&
            (state != 'meets_provisional_minimums' || score == null))) {
      throw const FormatException('Inconsistent exercise evidence.');
    }
    return ExerciseInsightGroup._(
        _text(g['name']),
        _text(g['category'], 100),
        c['exerciseId']! as String,
        state,
        attention,
        support,
        members,
        sessions,
        scored,
        missing,
        unscored,
        score,
        coverage,
        Map.unmodifiable(c));
  }
  String get scoreLabel => scoreSupport == 'unscored'
      ? 'Unscored'
      : score == null
          ? 'Not measured'
          : '${score!.toStringAsFixed(1)}%';
  String get groupLabel =>
      '${compatibility['scoringVersion']} · ${compatibility['cameraView']} · ${compatibility['mode']}';
  String get evidenceLabel => const {
        'policy_not_configured': 'Sample policy not configured',
        'insufficient_evidence': 'Insufficient evidence',
        'meets_provisional_minimums': 'Meets reviewed sample minimums',
        'no_scored_samples': 'No scored samples',
        'unscored': 'Form score unsupported',
      }[evidenceState]!;
  String get attentionLabel => const {
        'not_assessed': 'Not assessed',
        'attention': 'Needs attention',
        'within_policy': 'Within reviewed threshold'
      }[attention]!;
  String get displayGroup =>
      '${compatibility['scoringVersion']} · ${compatibility['cameraView']} view · ${const {
        'not_applicable': 'Standard mode',
        'both': 'Both arms',
        'leftOnly': 'Left arm',
        'rightOnly': 'Right arm',
        'left': 'Left side',
        'right': 'Right side',
      }[compatibility['mode']]}';
}

class ContentCoverage {
  final String exerciseId, name, category, coverage;
  final int publishedTutorials;
  final bool? attentionGap;
  ContentCoverage._(this.exerciseId, this.name, this.category, this.coverage,
      this.publishedTutorials, this.attentionGap);
  String get coverageLabel => coverage == 'covered'
      ? 'Published instruction available'
      : 'No published instruction';
  String get attentionLabel => attentionGap == null
      ? 'Not assessed'
      : attentionGap!
          ? 'Needs content'
          : 'No attention-linked gap';
  factory ContentCoverage.parse(Object? raw) {
    final c = _map(raw, {
      'exerciseId',
      'name',
      'category',
      'coverage',
      'publishedTutorials',
      'attentionGap'
    });
    final count = _int(c['publishedTutorials'], 500),
        coverage =
            _enum(c['coverage'], {'covered', 'missing_published_tutorial'});
    if ((count == 0) != (coverage == 'missing_published_tutorial') ||
        (c['attentionGap'] != null && c['attentionGap'] is! bool)) {
      throw const FormatException('Invalid content coverage.');
    }
    return ContentCoverage._(_text(c['exerciseId'], 128), _text(c['name']),
        _text(c['category'], 100), coverage, count, c['attentionGap'] as bool?);
  }
}

class ExerciseInsightsSnapshot {
  final ExerciseInsightsQuery query;
  final DateTime capturedAt;
  final String mode, privacyState;
  final int configurationRevision;
  final List<ExerciseInsightGroup> groups;
  final List<ContentCoverage> content;
  ExerciseInsightsSnapshot._(this.query, this.capturedAt, this.mode,
      this.privacyState, this.configurationRevision, this.groups, this.content);
  factory ExerciseInsightsSnapshot.parse(
      Object? raw, ExerciseInsightsQuery query) {
    query.validate();
    final s = _map(raw, {
      'schemaVersion',
      'organizationId',
      'startAtMillis',
      'endAtMillis',
      'capturedAtMillis',
      'mode',
      'recommendationEligibility',
      'privacy',
      'configurationRevision',
      'groups',
      'content'
    });
    if (s['schemaVersion'] != 1 ||
        s['organizationId'] != query.organizationId ||
        s['startAtMillis'] != query.start.millisecondsSinceEpoch ||
        s['endAtMillis'] != query.end.millisecondsSinceEpoch ||
        s['recommendationEligibility'] != 'not_evaluated') {
      throw const FormatException('Exercise insights scope changed.');
    }
    final captured = _int(s['capturedAtMillis'], 8640000000000000);
    if (captured < query.end.millisecondsSinceEpoch) {
      throw const FormatException('Invalid capture time.');
    }
    final privacy = _map(s['privacy'], {'state', 'policyId'}),
        state = _enum(privacy['state'], {'applied', 'review_required'});
    if ((state == 'applied' && privacy['policyId'] is! String) ||
        (state == 'review_required' && privacy['policyId'] != null)) {
      throw const FormatException('Invalid disclosure policy.');
    }
    final groups = _list(s['groups']).map(ExerciseInsightGroup.parse).toList(),
        content = _list(s['content'], 1000).map(ContentCoverage.parse).toList();
    if (state == 'review_required' &&
        (groups.isNotEmpty || content.any((c) => c.attentionGap != null))) {
      throw const FormatException('Unreviewed aggregate disclosure.');
    }
    final keys = <String>{}, ids = <String>{};
    for (final g in groups) {
      final key = [
        'exerciseId',
        'metricSchemaVersion',
        'scoringVersion',
        'detectorId',
        'detectorVersion',
        'cameraView',
        'mode',
        'scoreSupport'
      ].map((k) => g.compatibility[k]).join('|');
      if (!keys.add(key)) {
        throw const FormatException('Duplicate compatible group.');
      }
    }
    for (final c in content) {
      if (!ids.add(c.exerciseId)) {
        throw const FormatException('Duplicate content row.');
      }
    }
    final mode =
        _enum(s['mode'], {'descriptive_only', 'approved_group_attention'});
    if (mode == 'descriptive_only' &&
        groups.any((g) => g.attention != 'not_assessed')) {
      throw const FormatException('Unapproved attention classification.');
    }
    return ExerciseInsightsSnapshot._(
        query,
        DateTime.fromMillisecondsSinceEpoch(captured, isUtc: true),
        mode,
        state,
        _int(s['configurationRevision'], 1000000),
        List.unmodifiable(groups),
        List.unmodifiable(content));
  }
  List<ContentCoverage> filteredContent(
          {String? category, String? exerciseId}) =>
      content
          .where((r) =>
              (category == null || r.category == category) &&
              (exerciseId == null || r.exerciseId == exerciseId))
          .toList();
  List<ExerciseInsightGroup> filteredGroups(
          {String? category, String? exerciseId}) =>
      groups
          .where((r) =>
              (category == null || r.category == category) &&
              (exerciseId == null || r.exerciseId == exerciseId))
          .toList();
  List<List<Object?>> _header(bool synthetic, String section) => [
        [
          'GainPath',
          section,
          synthetic
              ? 'Fictional dataset · educational review'
              : 'Authorized aggregate view'
        ],
        ['Timezone', 'Asia/Kuala_Lumpur UTC+08:00'],
        ['Malaysia dates', query.malaysiaLabel],
        ['Start inclusive UTC', query.start.toUtc().toIso8601String()],
        ['End exclusive UTC', query.end.toUtc().toIso8601String()],
        ['Captured UTC', capturedAt.toIso8601String()],
        ['Configuration revision', configurationRevision],
        [
          'Definition',
          'Provisional estimated form; compatible groups only. Not clinical risk or recommendation eligibility.'
        ],
      ];
  List<List<Object?>> _safe(List<List<Object?>> rows) => rows
      .map((r) => r
          .map((v) =>
              v is String && RegExp(r'^\s*[=+\-@]').hasMatch(v) ? "'$v" : v)
          .toList())
      .toList();
  List<List<Object?>> contentCsv(
          {String? category, String? exerciseId, required bool synthetic}) =>
      _safe([
        ..._header(synthetic, 'Published content coverage'),
        [
          'Exercise',
          'Category',
          'Published tutorials',
          'Coverage',
          'Attention-linked gap'
        ],
        ...filteredContent(category: category, exerciseId: exerciseId)
            .map((r) => [
                  r.name,
                  r.category,
                  r.publishedTutorials,
                  r.coverage,
                  r.attentionGap ?? 'Not assessed'
                ]),
      ]);
  List<List<Object?>> insightsCsv(
          {String? category, String? exerciseId, required bool synthetic}) =>
      _safe([
        ..._header(synthetic, 'Exercise insights'),
        [
          'Exercise',
          'Category',
          'Scoring group',
          'Exercise ID',
          'Metric schema',
          'Scoring version',
          'Detector ID',
          'Detector version',
          'Camera view',
          'Exercise mode',
          'Score support',
          'Estimated Form Score (%)',
          'Scored sessions',
          'Distinct Members',
          'Tracking coverage fraction (0–1)',
          'Missing scores',
          'Unscored sessions',
          'Evidence state',
          'Attention'
        ],
        ...filteredGroups(category: category, exerciseId: exerciseId)
            .map((g) => [
                  g.name,
                  g.category,
                  g.groupLabel,
                  ...[
                    'exerciseId',
                    'metricSchemaVersion',
                    'scoringVersion',
                    'detectorId',
                    'detectorVersion',
                    'cameraView',
                    'mode',
                    'scoreSupport'
                  ].map((k) => g.compatibility[k]),
                  g.score ??
                      (g.scoreSupport == 'unscored'
                          ? 'Unscored'
                          : 'Not measured'),
                  g.scoredSessions,
                  g.members,
                  g.coverage ?? 'Unknown',
                  g.missingScores,
                  g.unscoredSessions,
                  g.evidenceState,
                  g.attention
                ]),
      ]);
  List<List<Object?>> gapsCsv(
          {String? category, String? exerciseId, required bool synthetic}) =>
      _safe([
        ..._header(synthetic, 'Content gap report'),
        ['Exercise', 'Category', 'Gap basis', 'Attention-linked gap'],
        ...filteredContent(category: category, exerciseId: exerciseId)
            .where((r) => r.coverage == 'missing_published_tutorial')
            .map((r) => [
                  r.name,
                  r.category,
                  'No active published tutorial projection',
                  r.attentionGap ?? 'Not assessed'
                ]),
      ]);
}
