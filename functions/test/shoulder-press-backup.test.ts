import {it,expect} from 'vitest';
import {validateBackupPayload} from '../src/modules/workouts/workout-backup-validation';
import {payload} from './workout-backup-fixture';
const press=()=>({...structuredClone(payload),exerciseId:'dumbbell-shoulder-press-front-v1',accuracy:0,
  poseMetrics:{...structuredClone(payload.poseMetrics),schemaVersion:4,
    scoringVersion:'dumbbell-shoulder-press-front-v1',cameraView:'front',formScorePercent:null}});
const validate=(p:unknown)=>validateBackupPayload('session','s1','gainpath','member',p);
it('backs up schema-four shoulder press as unscored provisional evidence',()=>{
  expect(validate(press())).toEqual(press());
});
it.each([{schemaVersion:1},{schemaVersion:2},{schemaVersion:3},{schemaVersion:'4'},
  {scoringVersion:'wall-push-up-side-v1'},{cameraView:'side'},{formScorePercent:0},
  {rowSide:'left'},{curlArms:{}},{trackedDurationMicros:0},
  {deviations:{trunkLean:{count:1,maximumDegrees:10}}},
])('rejects invalid press metrics %j',change=>{
  const p=press();Object.assign(p.poseMetrics,change);expect(()=>validate(p)).toThrow();
});
it('binds press backup to exact identity, organization and null scoring',()=>{
  const p=press();
  expect(()=>validate({...p,exerciseId:'squat'})).toThrow();
  expect(()=>validate({...p,accuracy:1})).toThrow();
  expect(()=>validateBackupPayload('session','s1','other','member',{...p,organizationId:'other'})).toThrow();
  expect(()=>validate({...p,poseMetrics:structuredClone(payload.poseMetrics)})).toThrow();
});
