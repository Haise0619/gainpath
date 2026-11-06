import 'package:gainpath_admin_web/features/recommendation/application/exercise_insights.dart';

final insightsNow = DateTime.utc(2026, 11, 1, 4);
final insightsQuery =
    ExerciseInsightsQuery('gainpath', DateTime.utc(2026, 10, 1), insightsNow);
Map<String, Object?> insightsFixture() => {
      'schemaVersion': 1,
      'organizationId': 'gainpath',
      'startAtMillis': insightsQuery.start.millisecondsSinceEpoch,
      'endAtMillis': insightsQuery.end.millisecondsSinceEpoch,
      'capturedAtMillis': insightsNow.millisecondsSinceEpoch,
      'mode': 'descriptive_only',
      'recommendationEligibility': 'not_evaluated',
      'privacy': {'state': 'applied', 'policyId': 'synthetic-cohort-three'},
      'configurationRevision': 0,
      'groups': [
        {
          'name': 'Squat',
          'category': 'Lower Body',
          'compatibility': {
            'exerciseId': 'F3b8xIr8ynBDd3gEICKX',
            'metricSchemaVersion': 1,
            'scoringVersion': 'bodyweight-squat-side-v1',
            'detectorId': 'blazepose-tflite',
            'detectorVersion': 'mediapipe-full-e9a5c5cb-det-9ba9dd3d',
            'cameraView': 'side',
            'mode': 'not_applicable',
            'scoreSupport': 'scored'
          },
          'metrics': <String, Object?>{
            'sessions': 6,
            'members': 3,
            'scoredSessions': 6,
            'missingScoreSessions': 0,
            'unscoredSessions': 0,
            'assessedAttempts': 60,
            'distinctSessionDays': 2,
            'meanEstimatedFormScore': 65,
            'trackingCoverage': 0.8,
            'evidenceState': 'policy_not_configured'
          },
          'attention': 'not_assessed'
        },
      ],
      'content': [
        {
          'exerciseId': 'F3b8xIr8ynBDd3gEICKX',
          'name': 'Squat',
          'category': 'Lower Body',
          'publishedTutorials': 1,
          'coverage': 'covered',
          'attentionGap': null
        },
        {
          'exerciseId': 'wall-push-up-side-v1',
          'name': 'Wall push-up',
          'category': 'Upper Body',
          'publishedTutorials': 0,
          'coverage': 'missing_published_tutorial',
          'attentionGap': null
        },
      ],
    };
