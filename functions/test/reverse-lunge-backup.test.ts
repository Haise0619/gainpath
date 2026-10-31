import {it, expect} from 'vitest';
import {validateBackupPayload} from '../src/modules/workouts/workout-backup-validation';
import {payload} from './workout-backup-fixture';
const lunge = () => ({...structuredClone(payload), exerciseId: 'bodyweight-reverse-lunge-side-v1', accuracy: 0,
  poseMetrics: {...structuredClone(payload.poseMetrics), schemaVersion: 5,
    scoringVersion: 'reverse-lunge-side-v1', cameraView: 'side', lungeSide: 'left', formScorePercent: null}});
const validate = (p: unknown) => validateBackupPayload('session', 's1', 'gainpath', 'member', p);
it.each(['left', 'right'])('backs up schema-five %s front planted leg without score', side => {
  const p = lunge(); p.poseMetrics.lungeSide = side; expect(validate(p)).toEqual(p);
});
it.each([{schemaVersion:1},{schemaVersion:2},{schemaVersion:3},{schemaVersion:4},{schemaVersion:6},{schemaVersion:'5'},
  {scoringVersion:'bodyweight-squat-side-v1'},{cameraView:'front'},{formScorePercent:0},
  {lungeSide:'both'},{lungeSide:null},{rowSide:'left'},{curlArms:{}},{trackedDurationMicros:0},
  {loadVerified:true},{deviations:{trunkLean:{count:1,maximumDegrees:10}}},
])('rejects invalid reverse lunge metrics %j', change => {
  const p=lunge(); Object.assign(p.poseMetrics,change); expect(()=>validate(p)).toThrow();
});
it('binds lunge backup to exact exercise and org and rejects forged acceptance and rewards', () => {
  const p=lunge();
  expect(()=>validate({...p,exerciseId:'squat'})).toThrow();
  expect(()=>validate({...p,accuracy:1})).toThrow();
  expect(()=>validateBackupPayload('session','s1','other','member',{...p,organizationId:'other'})).toThrow();
  expect(()=>validate({...p,poseMetrics:structuredClone(payload.poseMetrics)})).toThrow();
  for(const extra of [{acceptedWorkout:true},{acceptedAt:'2026-10-28T01:01:00Z'},{rewardPoints:100}]) expect(()=>validate({...p,...extra})).toThrow();
});
