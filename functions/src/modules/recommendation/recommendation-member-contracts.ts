import type {TransactionPort} from '../../platform/firestore/store';
import type {RecommendationLead, RecommendationKind, QueueTarget} from './recommendation-queue-contracts';
import type {LearningNeed} from './recommendation-ranking-contracts';
import type {QueueSecurityDependencies} from './recommendation-queue-security';

export interface CurrentRecommendationTarget {
  target: QueueTarget;
  label: string;
  specialization: string | null;
  imageUrl: string | null;
  photoPath: string | null;
}
export interface RecommendationDeliveryDependencies extends QueueSecurityDependencies {
  /** Explicit trusted local composition, never a request field. Default off. */
  readonly localDelivery?: {readonly fixtureSetId: 'module13-d-v1'};
  /** Pure authoritative source/eligibility resolver. No Auth/network/provider effects in a transaction. */
  readonly resolveTarget: (tx: Pick<TransactionPort, 'get' | 'getAll'>, lead: RecommendationLead) => Promise<CurrentRecommendationTarget | null>;
}
export type MemberRecommendationState = 'available' | 'not_delivered' | 'expired' | 'withdrawn' | 'dismissed' | 'unavailable';
/** Public transport: intentionally excludes Member identity, evidence metrics and source fingerprints. */
export interface MemberRecommendationDetail {
  schemaVersion: 1;
  mode: 'synthetic_local';
  organizationId: string;
  recommendationId: string;
  kind: RecommendationKind;
  revision: number;
  state: MemberRecommendationState;
  title: string;
  summary: string;
  exerciseLabel: string | null;
  objective: LearningNeed['objective'] | null;
  explanations: string[];
  target: QueueTarget | null;
  targetLabel: string | null;
  specialization: string | null;
  imageUrl: string | null;
  photoPath: string | null;
  createdAtMillis: number;
  deliveredAtMillis: number | null;
  expiresAtMillis: number;
  readAtMillis: number | null;
  acknowledgedAtMillis: number | null;
  dismissedAtMillis: number | null;
}
export interface RecommendationDeliveryReceipt {
  schemaVersion: 1;
  mode: 'synthetic_local';
  organizationId: string;
  recommendationId: string;
  notificationId: string;
  revision: number;
  deliveredAtMillis: number;
  status: 'delivered';
}
export const recommendationNotificationId = (id: string): string => `recommendation-${id}`;
