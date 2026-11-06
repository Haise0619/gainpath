import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/recommendation/application/recommendation_consent_repository.dart';

final consentScope = SessionScope(userId: 'member1', organizationId: 'gym1');
const consentNotice = RecommendationConsentNotice(
  policyId: 'synthetic-only-policy',
  noticeVersion: 'synthetic-notice-1',
  contentVersion: 'synthetic-content-1',
  historyDescription:
      'Only compatible sessions captured from this grant onward.',
);

Map<String, Object?> consentWire({int revision = 0, bool granted = false}) => {
      'schemaVersion': 2,
      'policyVersion': 'module13-purpose-v2-local',
      'organizationId': 'gym1',
      'memberId': 'member1',
      'revision': revision,
      'updatedAtMillis': 2000,
      'purposes': {
        for (final purpose in RecommendationConsentPurpose.values)
          purpose.name: {
            'granted':
                purpose == RecommendationConsentPurpose.exerciseInsights &&
                    granted,
            'revision': purpose == RecommendationConsentPurpose.exerciseInsights
                ? revision
                : 0,
            'grantedAtMillis':
                purpose == RecommendationConsentPurpose.exerciseInsights &&
                        granted
                    ? 1000
                    : null,
            'revokedAtMillis':
                purpose == RecommendationConsentPurpose.exerciseInsights &&
                        revision > 0 &&
                        !granted
                    ? 2000
                    : null,
            'noticePolicyId':
                purpose == RecommendationConsentPurpose.exerciseInsights &&
                        granted
                    ? 'synthetic-only-policy'
                    : null,
            'noticeVersion':
                purpose == RecommendationConsentPurpose.exerciseInsights &&
                        granted
                    ? 'synthetic-notice-1'
                    : null,
            'contentVersion':
                purpose == RecommendationConsentPurpose.exerciseInsights &&
                        granted
                    ? 'synthetic-content-1'
                    : null,
            'historyStartAtMillis':
                purpose == RecommendationConsentPurpose.exerciseInsights &&
                        granted
                    ? 1000
                    : null,
          },
      },
    };

Map<String, Object?> consentReceipt(Map<String, Object?> request) => {
      'schemaVersion': 2,
      'revision': (request['expectedRevision']! as int) + 1,
      'purpose': request['purpose'],
      'purposeRevision': 1,
      'granted': request['action'] == 'grant',
      'noticeVersion':
          request['action'] == 'grant' ? 'synthetic-notice-1' : null,
      'contentVersion':
          request['action'] == 'grant' ? 'synthetic-content-1' : null,
      'historyStartAtMillis': request['action'] == 'grant' ? 1000 : null,
    };
