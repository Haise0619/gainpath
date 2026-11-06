import {expect,it} from 'vitest';
import {validateBackupPayload} from '../src/modules/workouts/workout-backup-validation';
import {routinePayload} from './workout-backup-fixture';
import {backupWorkout,listWorkoutBackups,type BackupStore} from '../src/modules/workouts/workout-backup';
import {MemoryStore} from './memory-store';
import {actor} from './workout-backup-fixture';
import {extractWorkoutEvidence} from '../src/modules/recommendation/workout-evidence';

export function timedBackupFixture():Record<string,any>{
 const start=1792879990000000,end=start+45000000;
 const mediaValidation={schemaVersion:1,videoUrl:'https://example.com/video.mp4',generation:'123',sourceRevision:1,contentType:'video/mp4'};
 const row={entryId:'entry1',exerciseId:'mobility',dayNumber:1,name:'Mobility',category:'Core',sets:1,durationSeconds:45,restSeconds:30,executionMode:'videoGuidedTimed',cue:'',imageUrl:'',muscleGroup:'Core',videoUrl:mediaValidation.videoUrl,description:'',coverImageUrl:'',difficulty:'Beginner',equipment:'',tutorialSteps:[],mediaRevision:1,mediaGeneration:'123',mediaValidation};
 const guided={runId:'run1',entryId:'entry1',entryIndex:0,exerciseId:'mobility',prescription:{sets:1,durationSeconds:45,restSeconds:30},mediaIdentity:JSON.stringify([row.videoUrl,1,'123']),completionProvenance:'timerElapsed',startedAt:new Date(start/1000).toISOString(),updatedAt:new Date(end/1000).toISOString(),endedAt:new Date(end/1000).toISOString(),phase:'completed',phaseBeforePause:'working',restKind:'betweenSets',completedSetActiveMicroseconds:[45000000],currentSetActiveMicroseconds:0,remainingRestMicroseconds:0};
 const routine={...routinePayload.attempt.routine,schemaVersion:2,kind:'routine_v2',exercises:[row]};
 return {...routinePayload,schemaVersion:2,finished:true,updatedAtMicros:end,planSignature:JSON.stringify(['routine','blueprint',2,['entry1','mobility','videoGuidedTimed',1,guided.prescription,1,'123',row.videoUrl]]),guidedProgress:{'0':guided},attempt:{...routinePayload.attempt,schemaVersion:2,routine,finished:true,finishedAtMicros:end,updatedAtMicros:end,entries:[{kind:'timed',index:0,status:'timerCompleted',guided}]}};
}
it('validates truthful timer result without fabricating measurements',()=>{const p=timedBackupFixture();expect(validateBackupPayload('routine','r1','gainpath','member',p)).toEqual(p);expect(p.attempt.entries[0]).not.toHaveProperty('fullRepetitions');});
it.each(['fullRepetitions','poseMetrics','formScorePercent','manualSets'])('rejects timer measurement injection %s',key=>{const p=timedBackupFixture();p.attempt.entries[0][key]=0;expect(()=>validateBackupPayload('routine','r1','gainpath','member',p)).toThrow();});
it('rejects inconsistent derived projection and early completed duration',()=>{for(const mutate of [(p:any)=>p.attempt.entries[0].guided={...p.attempt.entries[0].guided,runId:'other'},(p:any)=>{p.guidedProgress['0'].completedSetActiveMicroseconds=[44000000];}]){const p=timedBackupFixture();mutate(p);expect(()=>validateBackupPayload('routine','r1','gainpath','member',p)).toThrow();}});
it('preserves Dart microsecond timestamps when validating actual active duration',()=>{
 const p=timedBackupFixture(),g=p.guidedProgress['0'];
 g.startedAt='2026-10-24T00:00:00.000001Z';g.updatedAt='2026-10-24T00:00:00.005002Z';delete g.endedAt;
 g.completedSetActiveMicroseconds=[];g.currentSetActiveMicroseconds=5001;g.phase='paused';p.attempt.entries[0].status='timerPartial';
 expect(()=>validateBackupPayload('routine','r1','gainpath','member',p)).not.toThrow();
 g.currentSetActiveMicroseconds=5002;expect(()=>validateBackupPayload('routine','r1','gainpath','member',p)).toThrow();
});
it('rejects reusing a guided run for another entry',()=>{
 const p=timedBackupFixture(),row={...p.attempt.routine.exercises[0],entryId:'entry2'},g={...p.guidedProgress['0'],entryId:'entry2',entryIndex:1};
 p.attempt.routine.exercises.push(row);p.guidedProgress['1']=g;p.attempt.entries.push({kind:'timed',index:1,status:'timerCompleted',guided:g});
 const signature=JSON.parse(p.planSignature);signature.push(['entry2','mobility','videoGuidedTimed',1,g.prescription,1,'123',row.videoUrl]);p.planSignature=JSON.stringify(signature);
 expect(()=>validateBackupPayload('routine','r1','gainpath','member',p)).toThrow();
});
it('negotiates routine schema independently and excludes timed evidence from Module13',async()=>{
 const memory=new MemoryStore();memory.documents.set('users/member',{organizationId:'gainpath'});memory.documents.set('orgs/gainpath',{status:'active'});memory.documents.set('orgs/gainpath/members/member',{organizationId:'gainpath',userId:'member',role:'member',status:'active',branchIds:[]});
 const store:BackupStore={transact:work=>memory.transact(work),list:async()=>[...memory.documents.entries()].filter(([p])=>/^orgs\/gainpath\/members\/member\/workoutBackups\/routine-[^/]+$/.test(p)).map(([,d])=>d)};
 const command={schemaVersion:2,organizationId:'gainpath',memberId:'member',consented:true,kind:'routine',id:'r1',baseDigest:null,payload:timedBackupFixture()};
 await expect(backupWorkout(store,actor,{...command,schemaVersion:1})).rejects.toBeDefined();await backupWorkout(store,actor,command);
 const query={schemaVersion:1,organizationId:'gainpath',memberId:'member',consented:true,after:'routines',maxPoseMetricsSchemaVersion:7};
 expect((await listWorkoutBackups(store,actor,query)).records).toHaveLength(0);
 expect((await listWorkoutBackups(store,actor,{...query,schemaVersion:2,maxRoutineCheckpointSchemaVersion:2})).records).toHaveLength(1);
 const data=memory.documents.get('orgs/gainpath/members/member/workoutBackups/routine-r1')!;
 expect(()=>extractWorkoutEvidence({organizationId:'gainpath',memberId:'member'},{data},Date.now())).toThrow();
});
