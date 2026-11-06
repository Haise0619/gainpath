import 'recommendation_queue.dart';

class RecommendationQueueUnavailable implements Exception {
  const RecommendationQueueUnavailable();
}

typedef RecommendationQueueRpc = Future<Map<String, Object?>> Function(
    String method, Map<String, Object?> request);

/// Presentation contract only. The protected server operation owns delivery.
abstract interface class RecommendationDeliveryPresentation {
  bool get sendsToFictionalInbox;
}
abstract interface class RecommendationReadOnlyPresentation {bool get readOnly;}

abstract interface class RecommendationQueueRepository {
  String get organizationId;
  bool get enabled;
  bool get isCurrent;
  bool get fixtureOnly;
  Future<RecommendationQueuePage> list(RecommendationQueueQuery query);
  Future<RecommendationLead> detail(RecommendationLead lead);
  Future<QueueGenerationSummary> refresh(String kind, String commandId,
      {String? continuation});
  Future<RecommendationDecisionReceipt> decide(
      RecommendationLead lead, String action, String commandId,
      {String? reason});
}

/// Deliberately injected transport for the synthetic local checkpoint. No
/// Firebase registration, production fallback, provider or fixtures are supplied.
class RpcRecommendationQueueRepository
    implements RecommendationQueueRepository, RecommendationDeliveryPresentation,RecommendationReadOnlyPresentation {
  RpcRecommendationQueueRepository(
      {required this.organizationId,
      this.sendsToFictionalInbox = false,
      this.readOnly=false,
      required bool Function() isCurrent,
      required RecommendationQueueRpc invoke})
      : _current = isCurrent,
        _invoke = invoke;
  @override
  final String organizationId;
  @override
  final bool sendsToFictionalInbox;
  @override
  final bool readOnly;
  final bool Function() _current;
  final RecommendationQueueRpc _invoke;
  @override
  bool get isCurrent => _current();
  @override
  bool get enabled => true;
  @override
  bool get fixtureOnly => true;
  void _guard() {
    if (!isCurrent) throw const RecommendationQueueUnavailable();
  }

  Future<Map<String, Object?>> _call(
      String method, Map<String, Object?> body) async {
    _guard();
    final result = await _invoke(method, body);
    _guard();
    return result;
  }

  @override
  Future<RecommendationQueuePage> list(RecommendationQueueQuery query) async {
    _guard();
    if (query.organizationId != organizationId) {
      throw const RecommendationQueueUnavailable();
    }
    return RecommendationQueuePage.parse(
        await _call('list', query.toJson()), query);
  }

  @override
  Future<RecommendationLead> detail(RecommendationLead lead) async {
    _guard();
    if (lead.organizationId != organizationId ||
        !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(lead.id)) {
      throw const RecommendationQueueUnavailable();
    }
    final result = await _call('detail', {
      'schemaVersion': 1,
      'organizationId': organizationId,
      'leadId': lead.id,
    });
    if (result.length != 4 ||
        !result.keys
            .toSet()
            .containsAll(['schemaVersion', 'mode', 'organizationId', 'lead']) ||
        result['schemaVersion'] != 1 ||
        result['mode'] != 'synthetic_local' ||
        result['organizationId'] != organizationId) {
      throw const FormatException('Invalid detail response.');
    }
    final fresh = RecommendationLead.parse(result['lead'], organizationId);
    if (fresh.id != lead.id || fresh.kind != lead.kind) {
      throw const FormatException('Detail identity mismatch.');
    }
    return fresh;
  }

  @override
  Future<QueueGenerationSummary> refresh(String kind, String commandId,
      {String? continuation}) async {
    if(readOnly)throw const RecommendationQueueUnavailable();
    if (!['trainer', 'content'].contains(kind) || commandId.trim().isEmpty) {
      throw const RecommendationQueueUnavailable();
    }
    final result = await _call('refresh', {
      'schemaVersion': 1,
      'organizationId': organizationId,
      'kind': kind,
      'commandId': commandId,
      'continuation': continuation
    });
    if (result.length != 4 ||
        !result.keys.toSet().containsAll(
            ['schemaVersion', 'mode', 'organizationId', 'summary']) ||
        result['schemaVersion'] != 1 ||
        result['mode'] != 'synthetic_local' ||
        result['organizationId'] != organizationId) {
      throw const FormatException('Invalid refresh response.');
    }
    return QueueGenerationSummary.parse(result['summary'], kind);
  }

  @override
  Future<RecommendationDecisionReceipt> decide(
      RecommendationLead lead, String action, String commandId,
      {String? reason}) async {
    if(readOnly)throw const RecommendationQueueUnavailable();
    _guard();
    final cleaned = reason?.trim();
    if (lead.organizationId != organizationId ||
        lead.status != 'pending' ||
        !['send', 'dismiss'].contains(action) ||
        commandId.trim().isEmpty ||
        (action == 'dismiss' &&
            (cleaned == null || cleaned.length < 8 || cleaned.length > 300)) ||
        (action == 'send' && reason != null)) {
      throw const RecommendationQueueUnavailable();
    }
    final result = await _call('decide', {
      'schemaVersion': 1,
      'organizationId': organizationId,
      'leadId': lead.id,
      'expectedRevision': lead.revision,
      'commandId': commandId,
      'action': action,
      'reason': action == 'dismiss' ? cleaned : null
    });
    final receipt =
        RecommendationDecisionReceipt.parse(result, organizationId, lead.id);
    if ((action == 'send' && receipt.outcome == 'dismissed') ||
        (action == 'dismiss' && receipt.outcome == 'prepared')) {
      throw const FormatException('Decision action mismatch.');
    }
    if (receipt.revision <= lead.revision) {
      throw const FormatException('Outdated decision receipt.');
    }
    return receipt;
  }
}

class UnavailableRecommendationQueueRepository
    implements RecommendationQueueRepository {
  const UnavailableRecommendationQueueRepository();
  @override
  String get organizationId => 'unavailable';
  @override
  bool get enabled => false;
  @override
  bool get isCurrent => true;
  @override
  bool get fixtureOnly => false;
  @override
  Future<RecommendationQueuePage> list(RecommendationQueueQuery query) async =>
      throw const RecommendationQueueUnavailable();
  @override
  Future<RecommendationLead> detail(RecommendationLead lead) async =>
      throw const RecommendationQueueUnavailable();
  @override
  Future<QueueGenerationSummary> refresh(String kind, String commandId,
          {String? continuation}) async =>
      throw const RecommendationQueueUnavailable();
  @override
  Future<RecommendationDecisionReceipt> decide(
          RecommendationLead lead, String action, String commandId,
          {String? reason}) async =>
      throw const RecommendationQueueUnavailable();
}
