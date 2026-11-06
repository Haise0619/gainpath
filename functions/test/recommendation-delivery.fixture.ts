import {queueSecurityFixture} from './recommendation-queue-fixture';
import {readRecommendationMemberState} from '../src/modules/recommendation/recommendation-queue-security';
import {createRecommendationLeadDecision} from '../src/modules/recommendation/recommendation-lead-decisions';
import type {RecommendationLead} from '../src/modules/recommendation/recommendation-queue-contracts';
import type {RecommendationDeliveryDependencies} from '../src/modules/recommendation/recommendation-member-contracts';

export async function deliveryFixture(ai = false, kind: 'trainer' | 'content' = 'trainer') {
  const f = await queueSecurityFixture(ai ? ['exerciseInsights', 'recommendationGeneration', 'recommendationDelivery', 'externalAiInference'] : undefined);
  const org = 'synthetic-org';
  const member = await f.store.transact(tx => readRecommendationMemberState(tx, {organizationId: org, memberId: 'member'}, 200000,
    f.deps.noticePolicies!, ['exerciseInsights', 'recommendationGeneration']));
  const lead: RecommendationLead = {schemaVersion: 1, mode: 'synthetic_local', leadId: 'd-lead', organizationId: org, memberId: 'member', kind,
    exerciseId: 'squat', objective: 'technique_foundations', level: 'beginner', memberLabel: 'Fictional Member', exerciseLabel: 'Squat',
    category: 'Strength', targetLabel: 'Fictional Coach', specialization: 'Foundations', branchLabel: 'Fictional Branch',
    target: kind === 'trainer' ? {kind, coachId: 'coach', branchId: 'branch', observedStartAtMillis: 300000, observedEndAtMillis: 2100000}
      : {kind, destination: {kind: 'published_routine_exercise_tutorial', organizationId: org, routineId: 'routine', exerciseIndex: 0, exerciseId: 'squat', dayNumber: 1}},
    evidence: {summary: 'Private fixture evidence.', scoredSessions: 3, estimatedFormScorePercent: 65, coverage: 0.8, sourceVersion: 'fixture-v1', configVersion: 'fixture-v1'},
    ranking: {origin: ai ? 'ai_reranked' : 'deterministic_single_candidate', reasonCodes: ['exercise_match'], explanations: ['Reviewed exercise mapping supports this learning objective.'],
      model: ai ? 'mock-model' : null, promptVersion: 'fixture-v1', algorithmVersion: 'fixture-v1', fallbackReason: null},
    sourceFingerprint: 'a'.repeat(64), memberFingerprint: member.fingerprint, runId: 'd-run', createdAtMillis: 190000,
    expiresAtMillis: 400000, status: 'pending', revision: 1, decision: null};
  f.store.documents.set(`orgs/${org}/recommendationLeads/${lead.leadId}`, lead as unknown as Record<string, unknown>);
  const prepared = await createRecommendationLeadDecision({...f.deps, validateTarget: async () => 'valid'})({...f.request,
    data: {schemaVersion: 1, organizationId: org, leadId: lead.leadId, commandId: 'd-prepare', expectedRevision: 1, action: 'send', reason: null}});
  const recommendationId = prepared.recipientRecommendationId!;
  const deps: RecommendationDeliveryDependencies = {...f.deps, localDelivery: {fixtureSetId: 'module13-d-v1'},
    resolveTarget: async (tx, current) => {
      if ('create' in tx || 'set' in tx) throw Error('Resolver must be read only');
      return {target: structuredClone(current.target), label: kind === 'trainer' ? 'Current Fictional Coach' : 'Current Squat Tutorial',
        specialization: kind === 'trainer' ? 'Foundations' : null, imageUrl: null, photoPath: null};
    }};
  const request = {...f.request, data: {schemaVersion: 1, organizationId: org, recommendationId}};
  const memberRequest = {...request, auth: {uid: 'member', token: {...f.request.auth.token, email: 'member@example.invalid'}},
    data: {...request.data, action: 'get', commandId: null as string | null, expectedRevision: null as number | null}};
  return {...f, deps, request, memberRequest, recommendationId, org, lead,
    recipientPath: `orgs/${org}/recommendationRecipients/${recommendationId}`};
}
