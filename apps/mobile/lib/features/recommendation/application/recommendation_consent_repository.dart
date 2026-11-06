import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;

enum RecommendationConsentPurpose {
  exerciseInsights,
  recommendationGeneration,
  externalAiInference,
  recommendationDelivery,
}

/// Display metadata must come from the reviewed composition, never a history
/// timestamp supplied by the Member. No production notice is bundled here.
class RecommendationConsentNotice {
  const RecommendationConsentNotice(
      {required this.policyId,
      required this.noticeVersion,
      required this.contentVersion,
      required this.historyDescription});
  final String policyId;
  final String noticeVersion;
  final String contentVersion;
  final String historyDescription;
}

class RecommendationConsentUnavailable implements Exception {
  const RecommendationConsentUnavailable();
}

class RecommendationPurposeConsent {
  const RecommendationPurposeConsent._(
      {required this.granted,
      required this.revision,
      this.grantedAtMillis,
      this.revokedAtMillis,
      this.noticePolicyId,
      this.noticeVersion,
      this.contentVersion,
      this.historyStartAtMillis});
  final bool granted;
  final int revision;
  final int? grantedAtMillis;
  final int? revokedAtMillis;
  final String? noticePolicyId;
  final String? noticeVersion;
  final String? contentVersion;
  final int? historyStartAtMillis;
}

class RecommendationConsentState {
  RecommendationConsentState._(
      this.organizationId,
      this.memberId,
      this.revision,
      Map<RecommendationConsentPurpose, RecommendationPurposeConsent> purposes)
      : purposes = Map.unmodifiable(purposes);
  final String organizationId;
  final String memberId;
  final int revision;
  final Map<RecommendationConsentPurpose, RecommendationPurposeConsent>
      purposes;

  factory RecommendationConsentState._absent(SessionScope scope) =>
      RecommendationConsentState._(scope.organizationId, scope.userId, 0, {
        for (final purpose in RecommendationConsentPurpose.values)
          purpose:
              const RecommendationPurposeConsent._(granted: false, revision: 0),
      });

  factory RecommendationConsentState.parse(
      Map<String, Object?> raw, SessionScope scope) {
    _keys(raw, {
      'schemaVersion',
      'policyVersion',
      'organizationId',
      'memberId',
      'revision',
      'purposes',
      'updatedAtMillis'
    });
    if (raw['schemaVersion'] != 2 ||
        raw['policyVersion'] != 'module13-purpose-v2-local' ||
        raw['organizationId'] != scope.organizationId ||
        raw['memberId'] != scope.userId) {
      throw const FormatException('Unrecognized consent state.');
    }
    final revision = _integer(raw['revision']);
    final updated = _integer(raw['updatedAtMillis']);
    if (revision < 1 || updated > DateTime.now().millisecondsSinceEpoch) {
      throw const FormatException('Invalid persisted consent state.');
    }
    final purposes = _map(raw['purposes']);
    _keys(purposes,
        RecommendationConsentPurpose.values.map((p) => p.name).toSet());
    final parsed =
        <RecommendationConsentPurpose, RecommendationPurposeConsent>{};
    var total = 0;
    for (final purpose in RecommendationConsentPurpose.values) {
      final p = _map(purposes[purpose.name]);
      _keys(p, {
        'granted',
        'revision',
        'grantedAtMillis',
        'revokedAtMillis',
        'noticePolicyId',
        'noticeVersion',
        'contentVersion',
        'historyStartAtMillis'
      });
      if (p['granted'] is! bool) {
        throw const FormatException('Invalid consent.');
      }
      final granted = p['granted']! as bool;
      final pr = _integer(p['revision']);
      if (pr > revision) {
        throw const FormatException('Invalid purpose revision.');
      }
      int? time(String field) {
        if (p[field] == null) return null;
        final value = _integer(p[field]);
        if (value > updated) {
          throw const FormatException('Invalid purpose time.');
        }
        return value;
      }

      String? identifier(String field) =>
          p[field] == null ? null : _identifier(p[field]);
      final grantAt = time('grantedAtMillis'),
          revokeAt = time('revokedAtMillis'),
          historyAt = time('historyStartAtMillis');
      final policy = identifier('noticePolicyId'),
          notice = identifier('noticeVersion'),
          content = identifier('contentVersion');
      final grantFields = <Object?>[
        grantAt,
        historyAt,
        policy,
        notice,
        content
      ];
      final hasGrant = grantFields.any((v) => v != null);
      if (pr == 0 && (granted || hasGrant || revokeAt != null) ||
          hasGrant &&
              (grantFields.any((v) => v == null) || historyAt! > grantAt!) ||
          granted && (pr == 0 || !hasGrant || revokeAt != null) ||
          !granted && pr > 0 && revokeAt == null ||
          !granted &&
              grantAt != null &&
              (revokeAt == null || revokeAt < grantAt)) {
        throw const FormatException('Invalid purpose state.');
      }
      parsed[purpose] = RecommendationPurposeConsent._(
          granted: granted,
          revision: pr,
          grantedAtMillis: grantAt,
          revokedAtMillis: revokeAt,
          noticePolicyId: policy,
          noticeVersion: notice,
          contentVersion: content,
          historyStartAtMillis: historyAt);
      total += pr;
    }
    if (total != revision) {
      throw const FormatException('Invalid consent revision total.');
    }
    return RecommendationConsentState._(
        scope.organizationId, scope.userId, revision, parsed);
  }
}

abstract interface class RecommendationConsentRepository {
  SessionScope get scope;
  bool get isCurrent;
  Future<RecommendationConsentState> load();
  Future<void> change(
      RecommendationConsentState state, RecommendationConsentPurpose purpose,
      {required bool granted,
      required String commandId,
      RecommendationConsentNotice? notice});
}

typedef RecommendationConsentRead = Future<Map<String, Object?>?> Function(
    Map<String, Object?> request);
typedef RecommendationConsentCommand = Future<Map<String, Object?>> Function(
    Map<String, Object?> request);

/// Explicit synthetic/emulator dependency injection only. There is deliberately
/// no Firebase callable name, default transport, feature flag or production factory.
/// Auth/App Check, membership, reviewed policy, CAS and durable replay belong to
/// the trusted server. A receipt never substitutes for reloading current state.
class RpcRecommendationConsentRepository
    implements RecommendationConsentRepository {
  RpcRecommendationConsentRepository(
      {required this.scope,
      required bool Function() isCurrent,
      required RecommendationConsentRead read,
      required RecommendationConsentCommand command})
      : _current = isCurrent,
        _read = read,
        _command = command;
  @override
  final SessionScope scope;
  final bool Function() _current;
  final RecommendationConsentRead _read;
  final RecommendationConsentCommand _command;
  @override
  bool get isCurrent => _current();
  void _check() {
    if (!isCurrent) throw const RecommendationConsentUnavailable();
  }

  @override
  Future<RecommendationConsentState> load() async {
    _check();
    final raw = await _read(
        {'schemaVersion': 2, 'organizationId': scope.organizationId});
    _check();
    return raw == null
        ? RecommendationConsentState._absent(scope)
        : RecommendationConsentState.parse(raw, scope);
  }

  @override
  Future<void> change(
      RecommendationConsentState state, RecommendationConsentPurpose purpose,
      {required bool granted,
      required String commandId,
      RecommendationConsentNotice? notice}) async {
    _check();
    _identifier(commandId);
    if (state.organizationId != scope.organizationId ||
        state.memberId != scope.userId ||
        state.revision >= 9007199254740991 ||
        granted && notice == null) {
      throw const FormatException('Invalid consent command.');
    }
    final request = <String, Object?>{
      'schemaVersion': 2,
      'organizationId': scope.organizationId,
      'commandId': commandId,
      'expectedRevision': state.revision,
      'purpose': purpose.name,
      'action': granted ? 'grant' : 'revoke',
      if (granted) ...{
        'noticePolicyId': _identifier(notice!.policyId),
        'acceptedNoticeVersion': _identifier(notice.noticeVersion),
        'acceptedContentVersion': _identifier(notice.contentVersion)
      },
    };
    final receipt = await _command(Map.unmodifiable(request));
    _check();
    _keys(receipt, {
      'schemaVersion',
      'revision',
      'purpose',
      'purposeRevision',
      'granted',
      'noticeVersion',
      'contentVersion',
      'historyStartAtMillis'
    });
    if (receipt['schemaVersion'] != 2 ||
        receipt['revision'] != state.revision + 1 ||
        receipt['purpose'] != purpose.name ||
        receipt['purposeRevision'] != state.purposes[purpose]!.revision + 1 ||
        receipt['granted'] != granted) {
      throw const FormatException('Invalid consent receipt.');
    }
    for (final field in ['noticeVersion', 'contentVersion']) {
      if (receipt[field] != null) _identifier(receipt[field]);
    }
    if (granted &&
            (receipt['noticeVersion'] != notice!.noticeVersion ||
                receipt['contentVersion'] != notice.contentVersion ||
                receipt['historyStartAtMillis'] == null) ||
        !granted && receipt['historyStartAtMillis'] != null) {
      throw const FormatException('Invalid notice receipt.');
    }
    if (receipt['historyStartAtMillis'] != null) {
      _integer(receipt['historyStartAtMillis']);
    }
  }
}

Map<String, Object?> _map(Object? value) {
  if (value is! Map || value.keys.any((k) => k is! String)) {
    throw const FormatException('Invalid object.');
  }
  return Map<String, Object?>.from(value);
}

void _keys(Map<String, Object?> value, Set<String> allowed) {
  if (value.length != allowed.length ||
      value.keys.any((k) => !allowed.contains(k))) {
    throw const FormatException('Unrecognized consent fields.');
  }
}

int _integer(Object? value) {
  if (value is! int || value < 0 || value > 9007199254740991) {
    throw const FormatException('Invalid consent number.');
  }
  return value;
}

String _identifier(Object? value) {
  if (value is! String || !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(value)) {
    throw const FormatException('Invalid consent identifier.');
  }
  return value;
}
