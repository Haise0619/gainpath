import type {DocumentData} from '../src/platform/firestore/store';
import {digestOf} from '../src/modules/workouts/workout-backup-validation';
import {payload, routinePayload} from './workout-backup-fixture';

export const now = Date.UTC(2026, 10, 1, 4);
export const query = {schemaVersion: 1, organizationId: 'gainpath',
  startAtMillis: Date.UTC(2026, 9, 1), endAtMillis: now};
export const modelVersion = 'mediapipe-full-e9a5c5cb-det-9ba9dd3d';
export const scope = {organizationId: 'gainpath', memberId: 'private-member-001'};

// Synthetic valid existing backup wire format; expected aggregates are hand-derived in tests.
export function session(id = 'private-session-001', score: number | null = 80,
  end = '2026-10-30T16:00:00.000Z'): DocumentData {
  const startedAt = new Date(Date.parse(end) - 10000).toISOString();
  return {...structuredClone(payload), sessionId: id, userId: scope.memberId,
    exerciseId: 'F3b8xIr8ynBDd3gEICKX', repetitions: 8, accuracy: score ?? 0,
    startedAt, endedAt: end, poseMetrics: {...structuredClone(payload.poseMetrics),
      partialRepetitions: 2, trackedDurationMicros: 8000000, rejectedDurationMicros: 2000000,
      formScorePercent: score, detectorVersion: modelVersion, consentedAt: startedAt}};
}
export function metrics(p: DocumentData): DocumentData {return p.poseMetrics as DocumentData;}
export function row(p = session(), cursor = 'head-001', kind: 'session' | 'routine' = 'session') {
  const id = String(kind === 'session' ? p.sessionId : p.id);
  return {id: cursor, data: {schemaVersion: 1, kind, id, key: `${kind}-${id}`,
    digest: digestOf(p), payloadJson: JSON.stringify(p),
    classification: 'provisional_member_backup', updatedAtMillis: now - 1000}};
}
export function routine(cursor = 'routine-001') {
  const p = structuredClone(routinePayload) as DocumentData;
  p.userId = scope.memberId;
  (p.attempt as DocumentData).userId = scope.memberId;
  return row(p, cursor, 'routine');
}
export function curl(id: string, mode: 'both' | 'leftOnly' | 'rightOnly') {
  const p = session(id);
  p.exerciseId = 'standing-single-arm-curl-side-v1';
  Object.assign(metrics(p), {schemaVersion: 2, scoringVersion: 'single-arm-curl-side-v1',
    curlArms: {mode, targetSets: 1, repetitionsPerArm: 8, completedSets: 0,
      left: {repetitions: mode === 'rightOnly' ? 0 : mode === 'both' ? 4 : 8,
        partialRepetitions: mode === 'rightOnly' ? 0 : mode === 'both' ? 1 : 2,
        formScorePercent: mode === 'rightOnly' ? null : 80},
      right: {repetitions: mode === 'leftOnly' ? 0 : mode === 'both' ? 4 : 8,
        partialRepetitions: mode === 'leftOnly' ? 0 : mode === 'both' ? 1 : 2,
        formScorePercent: mode === 'leftOnly' ? null : 80}}});
  return p;
}
export function consent(memberId = scope.memberId): DocumentData {
  return {schemaVersion: 1, policyVersion: 'module13-purpose-v1-proposed',
    organizationId: 'gainpath', memberId, revision: 1,
    purposes: {exerciseInsights: true, recommendationGeneration: false,
      externalAiInference: false, recommendationDelivery: false},
    grantedAtMillis: now - 86400000, revokedAtMillis: null, updatedAtMillis: now - 1000};
}
