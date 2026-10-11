import { existsSync, readFileSync } from 'node:fs';
import Ajv from 'ajv';
import { expect, it } from 'vitest';
import type { SubmitWorkoutSessionV2, AcknowledgeWorkoutConsentV1,
  WorkoutConsentAcknowledgementV1, WorkoutAcceptanceV2 } from '../src/modules/workouts/contracts';

const read = (path: string) => JSON.parse(readFileSync(`../contracts/${path}`, 'utf8'));
const ajv = new Ajv({ allErrors: true });
// Missing contract is a failing acceptance assertion, before schema authoring.
const validator = (path: string) => existsSync(`../contracts/${path}`)
  ? ajv.compile(read(path)) : (_value: unknown) => false;
const validate = validator('v2/submit-workout-session.request.schema.json');
const v1 = read('fixtures/submit-workout-session.v1.json');
const real: SubmitWorkoutSessionV2 = { ...v1, schemaVersion: 2, organizationId: 'gainpath',
  exerciseId: 'F3b8xIr8ynBDd3gEICKX',
  publishedRoutineId: 'routine_PTe4DxLS3WZ2DsfpGTOy',
  provenance: 'real_camera', cameraView: 'side', detectorId: 'contract-test-detector',
  scoringVersion: 'bodyweight-squat-side-v1', consentVersion: 'pose-local-summary-v1',
  consentAcknowledgementId: 'consent-ack-1' };

it('defines a bounded v2 summary while preserving v1 compatibility', () => {
  expect(validate(real)).toBe(true);
  expect(ajv.compile(read('v1/submit-workout-session.request.schema.json'))(v1)).toBe(true);
  expect(validate(v1)).toBe(false);
});

it('defines bounded consent revocation without client-controlled server time', () => {
  const request = { schemaVersion: 1, requestId: 'revoke-1', organizationId: 'gainpath',
    memberId: 'member-1', consentVersion: 'pose-local-summary-v1', acknowledgementId: 'ack-1' };
  const checkRequest = validator('v1/revoke-workout-consent.request.schema.json');
  const checkResponse = validator('v1/revoke-workout-consent.response.schema.json');
  expect(checkRequest(request)).toBe(true);
  expect(checkRequest({ ...request, revokedAtMillis: 1 })).toBe(false);
  expect(checkRequest({ ...request, acknowledgementId: '../other' })).toBe(false);
  expect(checkRequest({ ...request, consentVersion: 'old' })).toBe(false);
  expect(checkResponse({ ...request, revokedAtMillis: 1790907000001 })).toBe(true);
  expect(checkResponse({ ...request, revokedAtMillis: -1 })).toBe(false);
});
it.each(['simulated', 'recorded_fixture', 'legacy_unknown'])('rejects %s provenance', provenance => {
  expect(validate({ ...real, provenance })).toBe(false);
});
it.each(['publishedRoutineId', 'cameraView', 'detectorId', 'consentAcknowledgementId'])
  ('requires %s', field => {
    const candidate: Record<string, unknown> = { ...real };
    delete candidate[field];
    expect(validate(candidate)).toBe(false);
  });
it.each([{ rawFrames: [] }, { landmarks: [] }, { video: 'data' }, { cameraView: 'front' },
  { consentAcknowledgementId: '' }, { detectorId: 'native/path' }, { formScorePercent: 101 }])
  ('rejects unbounded or malformed payload: %j', change => {
    expect(validate({ ...real, ...change })).toBe(false);
  });
it('allows insufficient-evidence scores to remain null', () => {
  expect(validate({ ...real, formScorePercent: null })).toBe(true);
});
it('defines explicit consent acknowledgement without client acceptance metadata', () => {
  const validateConsent = validator('v1/acknowledge-workout-consent.request.schema.json');
  const consent: AcknowledgeWorkoutConsentV1 = { schemaVersion: 1, requestId: 'consent-request-1', organizationId: 'gainpath',
    memberId: 'member-1', consentVersion: 'pose-local-summary-v1', consented: true };
  expect(validateConsent(consent)).toBe(true);
  expect(validateConsent({ ...consent, consented: false })).toBe(false);
  expect(validateConsent({ ...consent, acknowledgedAtMillis: 1 })).toBe(false);
  expect(validateConsent({ ...consent, consentVersion: 'old-consent' })).toBe(false);
});

it('validates shared fixture and server-controlled consent/acceptance receipts', () => {
  expect(validate(read('fixtures/submit-workout-session.v2.json'))).toBe(true);
  const consent: WorkoutConsentAcknowledgementV1 = {
    schemaVersion: 1, requestId: 'consent-request-1', organizationId: 'gainpath',
    memberId: 'member-1', consentVersion: 'pose-local-summary-v1',
    acknowledgementId: 'consent-ack-1', acknowledgedAtMillis: 1790906000000,
  };
  const acceptance: WorkoutAcceptanceV2 = { schemaVersion: 2, requestId: 'upload-1',
    sessionId: 'session-1', status: 'accepted', acceptedAtMillis: 1790907000001 };
  const validateReceipt = validator('v1/acknowledge-workout-consent.response.schema.json');
  const validateAcceptance = validator('v2/submit-workout-session.response.schema.json');
  expect(validateReceipt(consent)).toBe(true);
  expect(validateReceipt({ ...consent, acknowledgedAtMillis: -1 })).toBe(false);
  expect(validateAcceptance(acceptance)).toBe(true);
  expect(validateAcceptance({ ...acceptance, status: 'pending' })).toBe(false);
});
