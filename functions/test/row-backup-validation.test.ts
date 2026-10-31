import {it, expect} from 'vitest';
import {validateBackupPayload} from '../src/modules/workouts/workout-backup-validation';
import {payload} from './workout-backup-fixture';

const row = () => ({...structuredClone(payload), exerciseId: 'single-arm-dumbbell-row-side-v1', accuracy: 0,
  poseMetrics: {...structuredClone(payload.poseMetrics), schemaVersion: 3, rowSide: 'left',
    scoringVersion: 'single-arm-row-side-v1', formScorePercent: null}});
const validate = (p: unknown) => validateBackupPayload('session', 's1', 'gainpath', 'member', p);

it.each(['left', 'right'])('accepts provisional selected-%s row backup without a form score', side => {
  const p = row(); p.poseMetrics.rowSide = side;
  expect(validate(p)).toEqual(p);
});
it.each([
  {rowSide: undefined}, {rowSide: null}, {rowSide: 'both'}, {rowSide: 'LEFT'},
  {schemaVersion: 1}, {schemaVersion: 2}, {schemaVersion: '3'},
  {scoringVersion: 'single-arm-curl-side-v1'}, {scoringVersion: 'single-arm-row-side-v2'},
  {formScorePercent: 0}, {formScorePercent: 90}, {cameraView: 'front'},
  {curlArms: {}}, {deviations: {trunkLean: {count: 1, maximumDegrees: 10}}},
  {detectorId: ''}, {detectorVersion: ''}, {consentVersion: 'unknown'},
  {trackedDurationMicros: 0}, {partialRepetitions: 10001},
])('rejects invalid row-only metadata %j', change => {
  const p = row(); Object.assign(p.poseMetrics, change);
  expect(() => validate(p)).toThrow();
});
it('rejects a row scoring version carried by legacy schema without side metadata', () => {
  const p = row(); const m: Record<string, unknown> = p.poseMetrics;
  m.schemaVersion = 1; delete m.rowSide;
  expect(() => validate(p)).toThrow();
});
it('binds row metadata to exact exercise identity and gainpath organization', () => {
  const p = row();
  expect(() => validate({...p, exerciseId: 'squat'})).toThrow();
  expect(() => validateBackupPayload('session', 's1', 'other', 'member', {...p, organizationId: 'other'})).toThrow();
  expect(() => validate({...p, accuracy: 90})).toThrow();
  expect(() => validate({...p, poseMetrics: {...payload.poseMetrics}})).toThrow();
});
