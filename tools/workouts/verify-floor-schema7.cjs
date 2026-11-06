// Executes only the prepared packages' pure modules against in-memory stores.
// No Firebase SDK initialization, network, credentials or user-data access.
const fs = require('node:fs'), path = require('node:path'), assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../..');
const out = path.join(root, 'build/floor-push-up-voice-20261105/backend-release');
const now = Date.UTC(2026, 9, 26, 6);
const floor = score => ({sessionId:'s1',userId:'member',organizationId:'gainpath',exerciseId:'standard-floor-push-up-side-v1',repetitions:2,accuracy:score??0,startedAt:'2026-10-25T01:00:00.000Z',endedAt:'2026-10-25T01:00:10.000Z',summarySchemaVersion:3,provenance:'realCamera',poseMetrics:{schemaVersion:7,partialRepetitions:0,trackedDurationMicros:8000000,rejectedDurationMicros:0,formScorePercent:score,scoringVersion:'standard-floor-push-up-side-v1',detectorId:'blazepose-tflite',detectorVersion:'v1',cameraView:'side',consentVersion:'pose-local-summary-v1',consentedAt:'2026-10-25T01:00:00.000Z',publishedRoutineId:'routine',deviations:{},floorPushUp:{side:'left',sourceVersion:'floor-push-up-2d-crosscheck-v1',components:score===null?null:{rangeOfMotion:90,bodyAlignment:90,movementControl:90,armExtension:90},issueCounts:{}}}});
function memory() {
  const documents = new Map([
    ['users/member',{organizationId:'gainpath',role:'member'}],
    ['users/admin',{organizationId:'gainpath',role:'admin'}],
    ['orgs/gainpath',{status:'active'}],
    ['orgs/gainpath/members/member',{organizationId:'gainpath',role:'member',status:'active',branchIds:[]}],
    ['orgs/gainpath/members/admin',{organizationId:'gainpath',role:'admin',status:'active',branchIds:[]}],
  ]);
  return {documents, transact: work => work({get: async p => documents.get(p),
    set: () => {throw Error('Unexpected write');}, create: () => {throw Error('Unexpected write');}})};
}
(async () => {
 const checks = [];
 for (const name of ['workoutBackupCommand','adminWorkoutReportingCommand']) {
   const v = require(path.join(out, name, 'lib/modules/workouts/workout-backup-validation.js'));
   for (const score of [90,null]) for (const side of ['left','right']) {
     const p = floor(score); p.poseMetrics.floorPushUp.side=side;
     assert.deepEqual(v.validateBackupPayload('session','s1','gainpath','member',p),p);
     checks.push(name+':scored/unscored:'+score+':'+side);
   }
   for (const change of [p=>p.provenance='recordedFixture',p=>p.exerciseId='wall-push-up-side-v1',
     p=>p.poseMetrics.floorPushUp.sourceVersion='wall-push-up-side-v1',
     p=>p.poseMetrics.floorPushUp.issueCounts.elbowFlare=1]) {
     const p=floor(90);change(p);
     assert.throws(()=>v.validateBackupPayload('session','s1','gainpath','member',p));
     checks.push(name+':spoof rejected');
   }
 }
 const name='workoutBackupCommand', base=path.join(out,name,'lib/modules/workouts');
 const v=require(path.join(base,'workout-backup-validation.js'));
 const backup=require(path.join(base,'workout-backup.js'));
 const p=floor(null), record={schemaVersion:1,kind:'session',id:'s1',key:'session-s1',
   payloadJson:JSON.stringify(p),digest:v.digestOf(p),classification:'provisional_member_backup',updatedAtMillis:now-1};
 const store={...memory(),list:async()=>[record]};
 const auth={uid:'member',token:{email_verified:true,auth_time:100}};
 const query={schemaVersion:1,organizationId:'gainpath',memberId:'member',consented:true,after:null};
 for(const maximum of [2,3,4,5,6,7]){
   const r=await backup.listWorkoutBackups(store,auth,{...query,maxPoseMetricsSchemaVersion:maximum});
   assert.equal(r.records.length,maximum===7?1:0);assert.equal(r.nextCursor,'routines');
   checks.push('old/new client negotiation '+maximum);
 }
 for(const bad of [{...query,consented:false},{...query,memberId:'foreign'}]) {
   await assert.rejects(backup.listWorkoutBackups(store,auth,bad));checks.push('consent/ownership denied');
 }
 const reportRoot=path.join(out,'adminWorkoutReportingCommand/lib');
 const rv=require(path.join(reportRoot,'modules/workouts/workout-backup-validation.js'));
 const report=require(path.join(reportRoot,'modules/analytics/admin-workout-reporting.js'));
 const wall=floor(90);wall.sessionId='wall';wall.exerciseId='wall-push-up-side-v1';
 wall.poseMetrics.schemaVersion=1;wall.poseMetrics.scoringVersion='wall-push-up-side-v1';delete wall.poseMetrics.floorPushUp;
 const row=x=>({id:'session-'+x.sessionId,data:{...record,id:x.sessionId,key:'session-'+x.sessionId,
   payloadJson:JSON.stringify(x),digest:rv.digestOf(x)}});
 const records=[row(p),row(wall)], mem=memory(), before=JSON.stringify([...mem.documents]);
 const result=await report.adminWorkoutReport(mem,{uid:'admin',token:{email_verified:true,auth_time:100}},
   {schemaVersion:1,organizationId:'gainpath',startAtMillis:now-3*86400000,endAtMillis:now},
   {members:async after=>after?[]:[{id:'member',data:{organizationId:'gainpath',role:'member',status:'active'}}],
    backups:async(_uid,after)=>records.filter(r=>!after||r.id>after)},()=>now);
 assert.equal(result.totals.sessions,2);assert.equal(result.totals.fullReps,4);
 assert.equal(result.forms.length,1);assert.equal(result.forms[0].exerciseId,'wall-push-up-side-v1');
 assert.equal(result.classification,'provisional_member_backup');
 assert.equal(JSON.stringify([...mem.documents]),before);
 checks.push('Module12 mixed wall/floor descriptive totals and missing floor score preserved; read only');
 const scored=floor(90), scoredRecords=[row(scored),row(wall)];
 const grouped=await report.adminWorkoutReport(mem,{uid:'admin',token:{email_verified:true,auth_time:100}},
   {schemaVersion:1,organizationId:'gainpath',startAtMillis:now-3*86400000,endAtMillis:now},
   {members:async after=>after?[]:[{id:'member',data:{organizationId:'gainpath',role:'member',status:'active'}}],
    backups:async(_uid,after)=>scoredRecords.filter(r=>!after||r.id>after)},()=>now);
 assert.equal(grouped.forms.length,2);checks.push('Module12 floor and wall score groups separate');
 const resultFile={passed:true,checks:checks.length,results:checks,liveDataTouched:false,deployed:false};
 fs.writeFileSync(path.join(out,'package-tests.json'),JSON.stringify(resultFile,null,2)+'\n');
 console.log(JSON.stringify(resultFile));
})().catch(e=>{console.error(e);process.exitCode=1;});
