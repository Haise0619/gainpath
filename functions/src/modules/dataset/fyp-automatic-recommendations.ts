import {DomainError} from '../../platform/errors';
import {requiredIdentifier} from '../../platform/validation';
import {digestOf, object} from '../workouts/workout-backup-validation';
import type {InsightsRequest} from '../recommendation/exercise-insights-contracts';
import {parseRecommendationLead, type RecommendationDecisionReceipt} from '../recommendation/recommendation-queue-contracts';
import type {QueueGenerationResponse} from '../recommendation/recommendation-queue-generation';

interface AutomaticPageDependencies {
  generation(request: InsightsRequest): Promise<QueueGenerationResponse>;
  decide(request: InsightsRequest): Promise<RecommendationDecisionReceipt>;
  deliver(request: InsightsRequest): Promise<unknown>;
  listRunLeads(runId: string): Promise<readonly unknown[]>;
}

/** Runs inside the existing authenticated FYP Admin boundary. The caller may
 * advance generation pages, but cannot nominate a recipient or a target. */
export async function runFypAutomaticRecommendationPage(
  request: InsightsRequest, deps: AutomaticPageDependencies,
) {
  const input = object(request.data);
  const batch = requiredIdentifier(input.commandId, 'command');
  // Namespace automatic runs so a historic manually reviewed run cannot be
  // adopted by replaying its command and cursor through this operation.
  const commandId = digestOf({operation: 'fyp-automatic-generation', batch});
  const generated = await deps.generation({...request, data: {...input, commandId}});
  if (generated.summary.status !== 'complete') {
    return {...generated, delivery: null};
  }
  const org = generated.organizationId;
  const records = await deps.listRunLeads(generated.summary.runId);
  if (records.length > 20) {
    throw new DomainError('failed-precondition', 'Unexpected automatic recommendation batch.');
  }
  let delivered = 0, needsAttention = 0;
  for (const raw of records) {
    const lead = parseRecommendationLead(raw, org);
    if (lead.runId !== generated.summary.runId || lead.kind !== generated.summary.kind) {
      throw new DomainError('failed-precondition', 'Unexpected automatic recommendation source.');
    }
    const deliveryCommandId = digestOf({operation: 'automatic-fyp-delivery', leadId: lead.leadId, runId: lead.runId});
    try {
      let recipientId: string | null = null;
      if (lead.status === 'pending') {
        const decision = await deps.decide({...request, data: {
          schemaVersion: 1, organizationId: org, leadId: lead.leadId,
          commandId: deliveryCommandId, expectedRevision: lead.revision, action: 'send', reason: null,
        }});
        recipientId = decision.recipientRecommendationId;
      } else if (lead.status === 'sent' && lead.decision?.commandId === deliveryCommandId) {
        recipientId = lead.decision.recipientRecommendationId;
      }
      if (!recipientId) {
        needsAttention++;
        continue;
      }
      await deps.deliver({...request, data: {
        schemaVersion: 1, organizationId: org, recommendationId: recipientId,
      }});
      delivered++;
    } catch (error) {
      const code = (error as {code?: unknown})?.code;
      if (code === 'permission-denied' || code === 'unauthenticated') throw error;
      needsAttention++;
    }
  }
  return {...generated, delivery: {delivered, needsAttention}};
}
