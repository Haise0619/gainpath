import {InputValidationError} from '../../platform/validation';
import {keys, object} from './workout-backup-validation';

export const FLOOR_PUSH_UP_ID = 'standard-floor-push-up-side-v1';
/** Descriptive backup only; never a measurement attestation or policy grant. */
export function validateFloorPushUpMetrics(m: Record<string, unknown>): void {
  const fail = () => {throw new InputValidationError('Invalid provisional floor push-up metrics.');};
  if (m.schemaVersion !== 7 || m.scoringVersion !== FLOOR_PUSH_UP_ID || m.cameraView !== 'side' ||
      m.consentVersion !== 'pose-local-summary-v1' || Object.keys(object(m.deviations)).length !== 0 ||
      !/^[A-Za-z0-9_-]{1,128}$/.test(String(m.detectorId)) ||
      !/^[A-Za-z0-9_-]{1,128}$/.test(String(m.detectorVersion))) fail();
  const f = object(m.floorPushUp);
  keys(f, ['side', 'sourceVersion', 'components', 'issueCounts']);
  if ((f.side !== null && f.side !== 'left' && f.side !== 'right') ||
      f.sourceVersion !== 'floor-push-up-2d-crosscheck-v1') fail();
  const issues = object(f.issueCounts);
  keys(issues, ['insufficientDescent', 'hipSagging', 'hipPiking', 'incompleteExtension',
    'unstableTracking', 'interrupted', 'movementTooFast'], []);
  if (Object.values(issues).some(v => !Number.isSafeInteger(v) || Number(v) < 1 || Number(v) > 10000)) fail();
  if (f.components === null) {if (m.formScorePercent !== null) fail();}
  else {
    const c = object(f.components);
    keys(c, ['rangeOfMotion', 'bodyAlignment', 'movementControl', 'armExtension']);
    if (f.side === null || Object.values(c).some(v => typeof v !== 'number' || !Number.isFinite(v) || v < 0 || v > 100)) fail();
    const score = Number(c.rangeOfMotion) * .4 + Number(c.bodyAlignment) * .35 +
      Number(c.movementControl) * .15 + Number(c.armExtension) * .1;
    if (typeof m.formScorePercent !== 'number' || Math.abs(score - m.formScorePercent) > .000001) fail();
  }
  const tracked = Number(m.trackedDurationMicros), rejected = Number(m.rejectedDurationMicros);
  if (Number(m.partialRepetitions) > 10000 || tracked + rejected > 86400000000 ||
      (tracked === 0 && (m.partialRepetitions !== 0 || m.formScorePercent !== null))) fail();
}

export function validateFloorPushUpIdentity(p: Record<string, unknown>, org: string): void {
  const m = object(p.poseMetrics);
  if (p.exerciseId !== FLOOR_PUSH_UP_ID && m.scoringVersion !== FLOOR_PUSH_UP_ID && m.schemaVersion !== 7) return;
  const f = object(m.floorPushUp), attempts = Number(p.repetitions) + Number(m.partialRepetitions);
  if (org !== 'gainpath' || p.exerciseId !== FLOOR_PUSH_UP_ID || m.scoringVersion !== FLOOR_PUSH_UP_ID ||
      m.schemaVersion !== 7 || attempts > 10000 ||
      p.accuracy !== (m.formScorePercent === null ? 0 : Math.round(Number(m.formScorePercent))) ||
      Object.values(object(f.issueCounts)).some(v => Number(v) > attempts)) {
    throw new InputValidationError('Invalid provisional floor push-up identity.');
  }
}
