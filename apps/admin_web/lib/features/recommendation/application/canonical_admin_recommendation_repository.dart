import 'package:cloud_functions/cloud_functions.dart';
import 'package:gainpath_data/gainpath_data.dart';

import 'recommendation_queue.dart';

typedef CanonicalAdminInvoke = Future<Object?> Function(
    String operation, Map<String, Object?> data);
String _text(Object? value, [int max = 1000]) {
  if (value is! String ||
      value.trim().isEmpty ||
      value.length > max ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
    throw const FormatException('Invalid recommendation text.');
  }
  return value;
}

Map<String, Object?> _map(Object? value) {
  if (value is! Map || value.keys.any((k) => k is! String)) {
    throw const FormatException('Invalid recommendation response.');
  }
  return Map<String, Object?>.from(value);
}

int _number(Object? value) {
  if (value is! int || value < 1) {
    throw const FormatException('Invalid recommendation version.');
  }
  return value;
}

String _id(Object? value) {
  final id = _text(value, 128);
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(id)) {
    throw const FormatException('Invalid recommendation identifier.');
  }
  return id;
}

class RecommendationAiMetadata {
  RecommendationAiMetadata._(this.method, this.workoutContext,
      this.fitnessGoals, this.factors, this.model, this.technical);
  final String method, workoutContext;
  final List<String> fitnessGoals, factors;
  final String? model;
  final Map<String, Object?> technical;

  factory RecommendationAiMetadata.parse(Object? value) {
    final raw = _map(value);
    if (!const ['gemini', 'rule_fallback'].contains(raw['method'])) {
      throw const FormatException('Invalid recommendation method.');
    }
    List<String> strings(String key) {
      final values = raw[key] ?? const [];
      if (values is! List || values.length > 20) {
        throw const FormatException('Invalid recommendation context.');
      }
      return List.unmodifiable(values.map((value) => _text(value, 500)));
    }

    final technical = <String, Object?>{};
    for (final key in [
      'candidateCount',
      'latencyMillis',
      'inputTokens',
      'outputTokens'
    ]) {
      final value = raw[key];
      if (value == null) continue;
      if (value is! num || !value.isFinite || value < 0) {
        throw const FormatException('Invalid recommendation metrics.');
      }
      technical[key] = value;
    }
    if (raw['changedOrder'] != null) {
      if (raw['changedOrder'] is! bool) {
        throw const FormatException('Invalid ranking metadata.');
      }
      technical['changedOrder'] = raw['changedOrder'];
    }
    if (raw['fallbackReason'] != null) {
      technical['fallbackReason'] = _text(raw['fallbackReason'], 500);
    }
    return RecommendationAiMetadata._(
        raw['method']! as String,
        _text(raw['workoutContext'], 1500),
        strings('fitnessGoals'),
        strings('factors'),
        raw['model'] == null ? null : _text(raw['model'], 128),
        Map.unmodifiable(technical));
  }
}

/// Accepted-workout records deliberately do not use the synthetic queue parser.
class CanonicalAdminRecommendation {
  CanonicalAdminRecommendation._(
      this.id,
      this.organizationId,
      this.memberId,
      this.revision,
      this.status,
      this.exerciseLabel,
      this.objective,
      this.title,
      this.summary,
      this.explanations,
      this.targetLabel,
      this.kind,
      this.policyVersion,
      this.evidenceFingerprint,
      this.createdAt,
      this.expiresAt,
      this.deliveredAt,
      [this.evidenceSummary,
      this.memberLabel,
      this.ai]);
  final String id,
      organizationId,
      memberId,
      status,
      exerciseLabel,
      objective,
      title,
      summary,
      targetLabel,
      kind,
      policyVersion,
      evidenceFingerprint;
  final int revision;
  final List<String> explanations;
  final DateTime createdAt, expiresAt;
  final DateTime? deliveredAt;
  final String? evidenceSummary, memberLabel;
  final RecommendationAiMetadata? ai;
  String get typeLabel => const {
        'trainer': 'Coach',
        'content': 'Tutorial',
        'routine': 'Routine'
      }[kind]!;
  String get aiMethodLabel => status == 'withdrawn'
      ? 'Withheld'
      : ai == null
          ? 'Rules'
          : ai!.method == 'gemini'
              ? 'Gemini'
              : 'Rule fallback';
  bool actionable(DateTime now) =>
      status == 'pending' && expiresAt.isAfter(now.toUtc());
  factory CanonicalAdminRecommendation.parse(Object? raw, String org) {
    final r = _map(raw);
    final redacted = r['redacted'] == true;
    final s = redacted ? <String, Object?>{} : _map(r['suggestion']);
    if (r['schemaVersion'] != 1 ||
        !const ['accepted_workout', 'workout_backup'].contains(r['mode']) ||
        r['organizationId'] != org ||
        !['pending', 'prepared', 'delivered', 'dismissed', 'withdrawn']
            .contains(r['status'])) {
      throw const FormatException('Invalid canonical recommendation scope.');
    }
    if (redacted) {
      if (r['status'] != 'withdrawn' ||
          !['trainer', 'content', 'routine'].contains(r['kind'])) {
        throw const FormatException('Invalid redacted history.');
      }
      return CanonicalAdminRecommendation._(
          _id(r['id']),
          org,
          _text(r['memberId'], 128),
          _number(r['revision']),
          'withdrawn',
          'Unavailable',
          'Unavailable',
          'Recommendation withdrawn',
          'Permission is no longer available.',
          const [],
          'Unavailable',
          r['kind'] as String,
          'Withheld',
          'Withheld',
          DateTime.fromMillisecondsSinceEpoch(_number(r['createdAtMillis']),
              isUtc: true),
          DateTime.fromMillisecondsSinceEpoch(_number(r['expiresAtMillis']),
              isUtc: true),
          r['deliveredAtMillis'] == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(
                  _number(r['deliveredAtMillis']),
                  isUtc: true));
    }
    final target = _map(s['target']);
    final kind = _text(target['kind'], 20);
    if (kind == 'routine') {
      if (target['organizationId'] != org) {
        throw const FormatException('Foreign routine destination.');
      }
      _text(target['routineId'], 128);
    } else {
      RecommendationQueueTarget.parse(target, org, kind);
    }
    final created = _number(r['createdAtMillis']),
        expires = _number(r['expiresAtMillis']);
    final delivered =
        r['deliveredAtMillis'] == null ? null : _number(r['deliveredAtMillis']);
    if (expires <= created ||
        (r['status'] == 'delivered' && delivered == null) ||
        (delivered != null && delivered < created)) {
      throw const FormatException('Invalid recommendation timing.');
    }
    if (s['explanations'] is! List || (s['explanations'] as List).length > 6) {
      throw const FormatException('Invalid recommendation explanations.');
    }
    String? evidenceSummary;
    if (s['evidenceSummary'] != null) {
      final e = _map(s['evidenceSummary']);
      final sessions = _number(e['assessedSessions']),
          days = _number(e['distinctDays']);
      if (sessions > 200 || days > sessions) {
        throw const FormatException('Invalid assessed evidence.');
      }
      final latest = DateTime.fromMillisecondsSinceEpoch(
              _number(e['latestAtMillis']),
              isUtc: true)
          .toIso8601String()
          .split('T')
          .first;
      evidenceSummary =
          '$sessions qualifying assessments across $days days. Most recent: $latest (UTC).';
    }
    _text(s['needKey']);
    return CanonicalAdminRecommendation._(
        _id(r['id']),
        org,
        _text(r['memberId'], 128),
        _number(r['revision']),
        r['status']! as String,
        _text(s['exerciseLabel'], 200),
        _text(s['objective'], 100),
        _text(s['title'], 200),
        _text(s['summary'], 1000),
        List.unmodifiable(
            (s['explanations'] as List).map((e) => _text(e, 300))),
        _text(s['targetLabel'], 200),
        kind,
        _text(s['policyVersion'], 128),
        _id(s['evidenceFingerprint']),
        DateTime.fromMillisecondsSinceEpoch(created, isUtc: true),
        DateTime.fromMillisecondsSinceEpoch(expires, isUtc: true),
        delivered == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(delivered, isUtc: true),
        evidenceSummary,
        r['memberLabel'] == null ? null : _text(r['memberLabel'], 120),
        s['ai'] == null ? null : RecommendationAiMetadata.parse(s['ai']));
  }
}

class CanonicalAdminPage {
  const CanonicalAdminPage(this.records, this.nextAfterId);
  final List<CanonicalAdminRecommendation> records;
  final String? nextAfterId;
}

class CanonicalAdminDecision {
  const CanonicalAdminDecision(this.status, this.revision);
  final String status;
  final int revision;
}

class CanonicalAdminRecommendationRepository {
  CanonicalAdminRecommendationRepository(
      {required this.organizationId,
      required bool Function() isCurrent,
      required CanonicalAdminInvoke invoke})
      : _current = isCurrent,
        _invoke = invoke;
  final String organizationId;
  final bool Function() _current;
  final CanonicalAdminInvoke _invoke;
  bool _enabled = false;
  bool _accessDenied = false;
  bool get enabled => _enabled && isCurrent;
  bool get isCurrent {
    try {
      return _current();
    } catch (_) {
      return false;
    }
  }

  void _guard() {
    if (!isCurrent) {
      throw StateError('Admin session changed.');
    }
  }

  Future<Map<String, Object?>> _call(
      String operation, Map<String, Object?> data) async {
    _guard();
    final r = _map(await _invoke(operation,
        {'schemaVersion': 1, 'organizationId': organizationId, ...data}));
    _guard();
    return r;
  }

  Future<bool> access() async {
    _enabled = false;
    final r = await _call('session.access', {});
    if (r['schemaVersion'] != 1 ||
        !const ['accepted_workout', 'workout_backup'].contains(r['mode']) ||
        r['organizationId'] != organizationId ||
        r['role'] != 'admin' ||
        r['enabled'] is! bool ||
        (r['enabled'] == true
            ? r['reason'] != null
            : r['reason'] != 'review_required')) {
      throw const FormatException('Invalid canonical access.');
    }
    _enabled = r['enabled'] == true;
    _accessDenied = !_enabled;
    return enabled;
  }

  void _ready() {
    _guard();
    if (!enabled) {
      throw StateError('Recommendations require review.');
    }
  }

  Future<CanonicalAdminPage> list({String? afterId}) async {
    _guard();
    if (_accessDenied) throw StateError('Recommendations require review.');
    if (afterId != null) _id(afterId);
    Map<String, Object?> r;
    try {
      r = await _call('admin.queue.list', {
        'afterId': afterId,
        'includeRoutine': true,
      });
    } on FirebaseFunctionsException catch (error) {
      if (error.code != 'invalid-argument') rethrow;
      r = await _call('admin.queue.list', {'afterId': afterId});
    } on Module13DemoUnavailable {
      r = await _call('admin.queue.list', {'afterId': afterId});
    }
    if (r['schemaVersion'] != 1 ||
        !const ['accepted_workout', 'workout_backup'].contains(r['mode']) ||
        r['organizationId'] != organizationId ||
        r['records'] is! List ||
        (r['records'] as List).length > 25) {
      throw const FormatException('Invalid canonical queue.');
    }
    final records = (r['records'] as List)
        .map((e) => CanonicalAdminRecommendation.parse(e, organizationId))
        .toList();
    if (records.map((e) => e.id).toSet().length != records.length) {
      throw const FormatException('Duplicate recommendation.');
    }
    final next = r['nextAfterId'] == null ? null : _id(r['nextAfterId']);
    if (next == afterId && next != null) {
      throw const FormatException('Repeated queue page.');
    }
    _enabled = true;
    return CanonicalAdminPage(List.unmodifiable(records), next);
  }

  Future<CanonicalAdminRecommendation> detail(
      CanonicalAdminRecommendation lead) async {
    _ready();
    if (lead.organizationId != organizationId) {
      throw StateError('Foreign recommendation.');
    }
    final r = CanonicalAdminRecommendation.parse(
        await _call('admin.queue.detail', {'id': lead.id}), organizationId);
    if (r.id != lead.id) {
      throw const FormatException('Recommendation identity changed.');
    }
    return r;
  }

  Future<CanonicalAdminDecision> decide(CanonicalAdminRecommendation lead,
      String action, String commandId) async {
    _ready();
    if (lead.organizationId != organizationId ||
        lead.status != 'pending' ||
        !['send', 'dismiss'].contains(action)) {
      throw StateError('Recommendation unavailable.');
    }
    final r = await _call('admin.queue.decide', {
      'id': lead.id,
      'expectedRevision': lead.revision,
      'commandId': _text(commandId, 128),
      'action': action
    });
    if (r['id'] != lead.id ||
        r['status'] != (action == 'send' ? 'prepared' : 'dismissed') ||
        _number(r['revision']) <= lead.revision) {
      throw const FormatException('Invalid recommendation decision.');
    }
    return CanonicalAdminDecision(
        r['status']! as String, r['revision']! as int);
  }

  Future<void> deliver(CanonicalAdminRecommendation lead) async {
    _ready();
    if (lead.organizationId != organizationId || lead.status != 'prepared') {
      throw StateError('Delivery unavailable.');
    }
    final r = await _call('delivery.process', {'id': lead.id});
    if (r['id'] != lead.id || r['status'] != 'delivered') {
      throw const FormatException('Delivery was not verified.');
    }
  }
}
