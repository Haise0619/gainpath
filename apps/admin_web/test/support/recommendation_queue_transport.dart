import 'dart:async';
import 'package:gainpath_admin_web/features/recommendation/application/recommendation_queue_repository.dart';
import 'recommendation_queue_fixture.dart';

class QueueTransportHarness {
  bool current = true,
      failList = false,
      failDecision = false,
      failRefresh = false,
      failDetail = false;
  String detailKind = 'trainer';
  Map<String, Object?>? freshDetail;
  Map<String, int>? abstentionReasons;
  DateTime? expiresAt;
  String? generationStatus;
  String status = 'pending';
  String? nextPage;
  Completer<Map<String, Object?>>? pending, refreshPending, detailPending;
  final requests = <Map<String, Object?>>[];
  late final repository = RpcRecommendationQueueRepository(
      organizationId: 'synthetic-org',
      isCurrent: () => current,
      invoke: invoke);
  Future<Map<String, Object?>> invoke(
      String method, Map<String, Object?> request) async {
    requests.add({'method': method, ...request});
    if (method == 'list') {
      detailKind = request['kind']! as String;
      if (pending != null) return pending!.future;
      if (failList) throw StateError('private provider body must stay hidden');
      final raw = queuePage(
          kind: request['kind'] as String,
          leads: request['status'] == 'all' || request['status'] == status
              ? [
                  queueLead(
                      kind: request['kind'] as String,
                      status: status,
                      id: request['afterLeadId'] == null ? 'lead-1' : 'lead-2')
                ]
              : [],
          next: request['afterLeadId'] == null ? nextPage : null);
      raw['summary'] = {
        'pending': status == 'pending' ? 1 : 0,
        'processed': status == 'pending' ? 0 : 1,
        'unavailable': 0
      };
      if (request['exerciseId'] == 'pushup' ||
          request['category'] == 'Upper Body' ||
          request['specialization'] == 'Mobility') {
        raw['leads'] = <Map<String, Object?>>[];
      }
      if (expiresAt != null) {
        for (final lead in raw['leads'] as List) {
          (lead as Map)['expiresAtMillis'] = expiresAt!.millisecondsSinceEpoch;
        }
      }
      if (generationStatus != null) {
        raw['generation'] = queueGeneration()..['status'] = generationStatus;
        if (abstentionReasons != null) {
          (raw['generation'] as Map)['abstentionReasons'] = abstentionReasons;
        }
      }
      return raw;
    }
    if (method == 'detail') {
      if (detailPending != null) return detailPending!.future;
      if (failDetail) throw StateError('private revoked consent reason');
      return {
        'schemaVersion': 1,
        'mode': 'synthetic_local',
        'organizationId': 'synthetic-org',
        'lead': freshDetail ??
            queueLead(
                kind: detailKind,
                id: request['leadId']! as String,
                status: status),
      };
    }
    if (method == 'refresh' && failRefresh) {
      throw StateError('Synthetic refresh outcome unknown');
    }
    if (method == 'refresh' && refreshPending != null) {
      return refreshPending!.future;
    }
    if (method == 'refresh') {
      return {
        'schemaVersion': 1,
        'mode': 'synthetic_local',
        'organizationId': 'synthetic-org',
        'summary': queueGeneration(
            nextCursor: request['continuation'] == null ? 'continue-1' : null)
      };
    }
    if (failDecision) throw StateError('private decision details');
    status = request['action'] == 'send' ? 'sent' : 'dismissed';
    return {
      'schemaVersion': 1,
      'organizationId': 'synthetic-org',
      'leadId': request['leadId'],
      'revision': 2,
      'status': status,
      'outcome': status == 'sent' ? 'prepared' : 'dismissed',
      'recipientRecommendationId': status == 'sent' ? 'recipient-1' : null,
      'deliveryStatus': status == 'sent' ? 'prepared_local' : 'not_prepared'
    };
  }
}
