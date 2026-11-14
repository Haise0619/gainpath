import 'dart:async';
import 'package:gainpath_admin_web/features/recommendation/application/canonical_admin_recommendation_repository.dart';
import 'recommendation_queue_fixture.dart';

Map<String, Object?> canonicalAdminRecord({String status = 'pending'}) => {
      'schemaVersion': 1,
      'mode': 'accepted_workout',
      'organizationId': 'synthetic-org',
      'id': 'a'.padLeft(64, 'a'),
      'memberId': 'member-1',
      'revision': 1,
      'status': status,
      'suggestion': {
        'needKey': 'movement-control',
        'evidenceFingerprint': 'b'.padLeft(64, 'b'),
        'policyVersion': 'reviewed-v1',
        'exerciseLabel': 'Squat',
        'evidenceSummary': {
          'assessedSessions': 3,
          'distinctDays': 3,
          'latestAtMillis':
              queueNow.subtract(const Duration(days: 1)).millisecondsSinceEpoch
        },
        'objective': 'movement_control',
        'title': 'Improve squat control',
        'summary': 'Practice controlled movement with this tutorial.',
        'explanations': [
          'Recent compatible sessions support technique practice.'
        ],
        'target': queueLead(kind: 'content')['target'],
        'targetLabel': 'Squat technique tutorial'
      },
      'createdAtMillis':
          queueNow.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
      'expiresAtMillis':
          queueNow.add(const Duration(days: 7)).millisecondsSinceEpoch,
      'deliveredAtMillis':
          status == 'delivered' ? queueNow.millisecondsSinceEpoch : null,
      'consentFingerprint': 'c'.padLeft(64, 'c'),
      'readAtMillis': null,
      'acknowledgedAtMillis': null,
      'dismissedAtMillis': null,
    };

class CanonicalAdminHarness {
  bool current = true,
      enabled = true,
      failDetail = false,
      failDecision = false,
      autoDeliver = false;
  Completer<Object?>? pendingDetail;
  Map<String, Object?> record = canonicalAdminRecord();
  final requests = <Map<String, Object?>>[];
  late final repository = CanonicalAdminRecommendationRepository(
      organizationId: 'synthetic-org',
      isCurrent: () => current,
      invoke: invoke);
  Future<Object?> invoke(String operation, Map<String, Object?> data) async {
    requests.add({'operation': operation, ...data});
    switch (operation) {
      case 'session.access':
        return {
          'schemaVersion': 1,
          'mode': 'accepted_workout',
          'organizationId': 'synthetic-org',
          'role': 'admin',
          'enabled': enabled,
          'reason': enabled ? null : 'review_required'
        };
      case 'admin.queue.list':
        if (!enabled) throw StateError('Recommendations unavailable.');
        return {
          'schemaVersion': 1,
          'mode': 'accepted_workout',
          'organizationId': 'synthetic-org',
          'records': [record],
          'nextAfterId': null
        };
      case 'admin.queue.detail':
        if (pendingDetail != null) return pendingDetail!.future;
        if (failDetail) throw StateError('Private revoked consent');
        return record;
      case 'admin.queue.decide':
        if (failDecision) throw StateError('Private server failure');
        final status = data['action'] == 'send' ? 'prepared' : 'dismissed';
        final revision = (record['revision']! as int) + 1;
        record = {
          ...record,
          'status': autoDeliver && status == 'prepared' ? 'delivered' : status,
          'revision': autoDeliver ? revision + 1 : revision,
          'deliveredAtMillis':
              autoDeliver ? queueNow.millisecondsSinceEpoch : null
        };
        return {'id': record['id'], 'revision': revision, 'status': status};
      case 'delivery.process':
        record = {
          ...record,
          'status': 'delivered',
          'revision': (record['revision']! as int) + 1,
          'deliveredAtMillis': queueNow.millisecondsSinceEpoch
        };
        return {'id': record['id'], 'status': 'delivered'};
    }
    throw StateError('Unsupported operation.');
  }
}
