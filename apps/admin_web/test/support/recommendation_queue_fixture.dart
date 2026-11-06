import 'package:gainpath_admin_web/features/recommendation/application/recommendation_queue.dart';

final queueNow = DateTime.utc(2026, 11, 1, 4);
Map<String, Object?> queueLead(
        {String kind = 'trainer',
        String id = 'lead-1',
        String status = 'pending'}) =>
    {
      'schemaVersion': 1,
      'mode': 'synthetic_local',
      'leadId': id,
      'organizationId': 'synthetic-org',
      'memberId': 'member-1',
      'kind': kind,
      'exerciseId': 'squat',
      'objective': 'technique_foundations',
      'level': 'beginner',
      'memberLabel': 'Sample Member',
      'exerciseLabel': 'Squat',
      'category': 'Lower Body',
      'targetLabel': kind == 'trainer' ? 'Sample Coach' : 'Squat foundations',
      'specialization': kind == 'trainer' ? 'Strength' : null,
      'branchLabel': kind == 'trainer' ? 'Sample Branch' : null,
      'target': kind == 'trainer'
          ? {
              'kind': 'trainer',
              'coachId': 'coach-1',
              'branchId': 'branch-1',
              'observedStartAtMillis':
                  queueNow.add(const Duration(days: 1)).millisecondsSinceEpoch,
              'observedEndAtMillis': queueNow
                  .add(const Duration(days: 1, minutes: 30))
                  .millisecondsSinceEpoch
            }
          : {
              'kind': 'content',
              'destination': {
                'kind': 'published_routine_exercise_tutorial',
                'organizationId': 'synthetic-org',
                'routineId': 'routine-1',
                'exerciseIndex': 0,
                'exerciseId': 'squat',
                'dayNumber': 1
              }
            },
      'evidence': <String, Object?>{
        'summary': 'Synthetic compatible squat observations for review.',
        'scoredSessions': 3,
        'estimatedFormScorePercent': 64.0,
        'coverage': 0.8,
        'sourceVersion': 'synthetic-source-v1',
        'configVersion': 'synthetic-policy-v1'
      },
      'ranking': {
        'origin': 'deterministic_fallback',
        'reasonCodes': ['exercise_match'],
        'explanations': ['Matches the supported exercise.'],
        'model': null,
        'promptVersion': 'module13-rank-v1',
        'algorithmVersion': 'baseline-v1',
        'fallbackReason': 'provider_unavailable'
      },
      'sourceFingerprint': List.filled(64, 'a').join(),
      'memberFingerprint': List.filled(64, 'b').join(),
      'runId': 'run-1',
      'createdAtMillis':
          queueNow.subtract(const Duration(hours: 2)).millisecondsSinceEpoch,
      'expiresAtMillis':
          queueNow.add(const Duration(days: 7)).millisecondsSinceEpoch,
      'status': status,
      'revision': 1,
      'decision': status == 'sent' || status == 'dismissed'
          ? {
              'actorId': 'admin-1',
              'atMillis': queueNow.millisecondsSinceEpoch,
              'commandId': 'cmd-1',
              'reason':
                  status == 'dismissed' ? 'No suitable time available.' : null,
              'recipientRecommendationId':
                  status == 'sent' ? 'recipient-1' : null
            }
          : null,
    };
Map<String, Object?> queueGeneration({String? nextCursor}) => {
      'runId': 'run-1',
      'kind': 'trainer',
      'status': nextCursor == null ? 'complete' : 'in_progress',
      'processed': 2,
      'candidateCount': 3,
      'generated': 1,
      'abstained': 1,
      'abstentionReasons': <String, Object?>{
        'insufficient_evidence': 1,
        'unsupported_evidence': 0,
        'missing_consent': 0,
        'no_eligible_candidates': 0,
        'semantic_abstention': 0
      },
      'fallbackCount': 1,
      'nextCursor': nextCursor,
      'failureCode': null,
      'algorithmVersion': 'baseline-v1',
      'model': null,
      'updatedAtMillis': queueNow.millisecondsSinceEpoch
    };
Map<String, Object?> queuePage(
        {String kind = 'trainer',
        List<Map<String, Object?>>? leads,
        String? next,
        String? generationCursor}) =>
    {
      'schemaVersion': 1,
      'mode': 'synthetic_local',
      'organizationId': 'synthetic-org',
      'kind': kind,
      'capturedAtMillis': queueNow.millisecondsSinceEpoch,
      'leads': leads ?? [queueLead(kind: kind)],
      'nextAfterLeadId': next,
      'summary': {'pending': 1, 'processed': 0, 'unavailable': 0},
      'facets': {
        'exercises': [
          {'id': 'squat', 'label': 'Squat'},
          {'id': 'pushup', 'label': 'Wall push-up'}
        ],
        'categories': ['Lower Body', 'Upper Body'],
        'specializations': ['Strength', 'Mobility']
      },
      'generation': generationCursor == null
          ? null
          : queueGeneration(nextCursor: generationCursor),
    };
RecommendationQueueQuery queueQuery() =>
    RecommendationQueueQuery.recent('synthetic-org', 'trainer', queueNow, 30);
