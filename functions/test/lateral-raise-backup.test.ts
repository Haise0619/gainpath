import {it, expect} from 'vitest';
import {validateBackupPayload} from '../src/modules/workouts/workout-backup-validation';
import {payload} from './workout-backup-fixture';
const lateral = () => ({...structuredClone(payload), exerciseId: 'standing-lateral-raise-front-v1', accuracy: 0,
  poseMetrics: {...structuredClone(payload.poseMetrics), schemaVersion: 6,
    scoringVersion: 'standing-lateral-raise-front-v1', cameraView: 'front', formScorePercent: null}});
const validate = (p: unknown) => validateBackupPayload('session', 's1', 'gainpath', 'member', p);
it('backs up schema-six bilateral lateral raise without score', () => {
  const p = lateral(); expect(validate(p)).toEqual(p);
});
it.each([{schemaVersion:1},{schemaVersion:2},{schemaVersion:3},{schemaVersion:4},{schemaVersion:5},{schemaVersion:7},{schemaVersion:'6'},
  {scoringVersion:'bodyweight-squat-side-v1'},{cameraView:'side'},{formScorePercent:0},
  {lungeSide:'left'},{standingVerified:true},{rowSide:'left'},{curlArms:{}},{trackedDurationMicros:0},
  {loadVerified:true},{deviations:{trunkLean:{count:1,maximumDegrees:10}}},
])('rejects invalid lateral raise metrics %j', change => {
  const p=lateral(); Object.assign(p.poseMetrics,change); expect(()=>validate(p)).toThrow();
});
it('binds lateral backup to exact exercise and org and rejects forged acceptance and rewards', () => {
  const p=lateral();
  expect(()=>validate({...p,exerciseId:'squat'})).toThrow();
  expect(()=>validate({...p,accuracy:1})).toThrow();
  expect(()=>validateBackupPayload('session','s1','other','member',{...p,organizationId:'other'})).toThrow();
  expect(()=>validate({...p,poseMetrics:structuredClone(payload.poseMetrics)})).toThrow();
  for(const extra of [{acceptedWorkout:true},{acceptedAt:'2026-10-28T01:01:00Z'},{rewardPoints:100}]) expect(()=>validate({...p,...extra})).toThrow();
});
