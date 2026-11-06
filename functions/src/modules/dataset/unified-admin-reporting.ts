import {DomainError} from '../../platform/errors';
import type {OperationalReport} from '../analytics/admin-reporting';
import {emptyWorkoutTotals,WORKOUT_REPORT_LIMITS,type WorkoutReport} from '../analytics/admin-workout-reporting';
import type {aggregateUnifiedSampleBusiness} from './unified-sample-business';
const fail=()=>new DomainError('failed-precondition','Unified report sources disagree. No partial totals were returned.');
function compatible(a:{organizationId:string;startAtMillis:number;endAtMillis:number},b:typeof a){if(a.organizationId!=='gainpath'||b.organizationId!==a.organizationId||a.startAtMillis!==b.startAtMillis||a.endAtMillis!==b.endAtMillis)throw fail();}
export function mergeUnifiedOperationalReports(existing:OperationalReport,fyp:OperationalReport,sampleBusiness:ReturnType<typeof aggregateUnifiedSampleBusiness>){
 compatible(existing,fyp);
 const currentAccounts={members:existing.currentAccounts.members+fyp.currentAccounts.members,coaches:existing.currentAccounts.coaches+fyp.currentAccounts.coaches};
 const illustrativeRevenueMinor=existing.receipts.confirmedMinor+sampleBusiness.simulatedRevenueMinor;
 if(!Object.values(currentAccounts).every(Number.isSafeInteger)||!Number.isSafeInteger(illustrativeRevenueMinor))throw fail();
 return{...existing,currentAccounts,sourceCounts:{...existing.sourceCounts,members:existing.sourceCounts.members+fyp.sourceCounts.members},sourceReadStartedAtMillis:Math.min(existing.sourceReadStartedAtMillis,fyp.sourceReadStartedAtMillis),capturedAtMillis:Math.max(existing.capturedAtMillis,fyp.capturedAtMillis),unified:{schemaVersion:1 as const,sourceBreakdown:{existing:existing.currentAccounts,fyp:fyp.currentAccounts},sampleBusiness,illustrativeRevenueMinor,financialDefinition:'Existing confirmed provider Sandbox receipts remain unchanged. FYP simulation and illustrative sum are not settled income, profit, balances or entitlements.'}};
}
export function mergeUnifiedWorkoutReports(existing:WorkoutReport,fyp:WorkoutReport){
 compatible(existing,fyp);if(existing.classification!=='provisional_member_backup'||fyp.classification!=='fictional_synthetic_observation'||fyp.fictional!==true)throw fail();
 const sumTotals=(a:ReturnType<typeof emptyWorkoutTotals>,b:typeof a)=>Object.fromEntries(Object.keys(emptyWorkoutTotals()).map(k=>[k,a[k as keyof typeof a]+b[k as keyof typeof a]])) as typeof a;
 const daily=new Map<string,WorkoutReport['daily'][number]>(),exercises=new Map<string,WorkoutReport['exercises'][number]>(),forms=new Map<string,WorkoutReport['forms'][number]>();
 for(const report of [existing,fyp]){
  for(const row of report.daily)daily.set(row.date,{date:row.date,...sumTotals(daily.get(row.date)??emptyWorkoutTotals(),row)});
  for(const row of report.exercises){const before=exercises.get(row.exerciseId);exercises.set(row.exerciseId,before?{...before,sessions:before.sessions+row.sessions,fullReps:before.fullReps+row.fullReps,partialReps:before.partialReps+row.partialReps,trackedMicros:before.trackedMicros+row.trackedMicros,manualSets:before.manualSets+row.manualSets}:structuredClone(row));}
  for(const row of report.forms){const key=JSON.stringify([row.exerciseId,row.scoringVersion,row.detectorId,row.detectorVersion,row.cameraView,row.armMode]),before=forms.get(key);
   if(!before){forms.set(key,structuredClone(row));continue;}
   before.scoredSessions+=row.scoredSessions;before.scoreSum+=row.scoreSum;
   const days=new Map(before.daily.map(d=>[d.date,d]));for(const d of row.daily){const old=days.get(d.date);days.set(d.date,old?{date:d.date,scoredSessions:old.scoredSessions+d.scoredSessions,scoreSum:old.scoreSum+d.scoreSum}:{...d});}before.daily=[...days.values()].sort((a,b)=>a.date.localeCompare(b.date));
  }
 }
 const coverage=Object.fromEntries(Object.keys(existing.coverage).map(k=>[k,existing.coverage[k as keyof typeof existing.coverage]+fyp.coverage[k as keyof typeof fyp.coverage]])) as WorkoutReport['coverage'];
 const totals=sumTotals(existing.totals,fyp.totals);if(!Object.values({...coverage,...totals}).every(n=>Number.isSafeInteger(n)&&n>=0))throw fail();
 if(coverage.membersScanned>WORKOUT_REPORT_LIMITS.members||coverage.activeMembers>WORKOUT_REPORT_LIMITS.eligibleMembers||coverage.backupRecords>WORKOUT_REPORT_LIMITS.backups||coverage.bytesRead>WORKOUT_REPORT_LIMITS.bytes)throw new DomainError('resource-exhausted','Combined workout sources exceed the original bounded report limits. No partial totals were returned.');
 return{...existing,classification:'mixed_descriptive_sources' as const,containsFictional:true as const,coverage,totals,sourceReadStartedAtMillis:Math.min(existing.sourceReadStartedAtMillis,fyp.sourceReadStartedAtMillis),capturedAtMillis:Math.max(existing.capturedAtMillis,fyp.capturedAtMillis),daily:[...daily.values()].sort((a,b)=>a.date.localeCompare(b.date)),exercises:[...exercises.values()].sort((a,b)=>a.exerciseId.localeCompare(b.exerciseId)),forms:[...forms.entries()].sort(([a],[b])=>a.localeCompare(b)).map(([,v])=>v),sourceBreakdown:{existing:{classification:existing.classification,sessions:existing.totals.sessions,activeMembers:existing.coverage.activeMembers},fyp:{classification:fyp.classification,sessions:fyp.totals.sessions,activeMembers:fyp.coverage.activeMembers}},definition:'Combined descriptive observations include fictional synthetic data; scores retain exact scoring/mode compatibility. Not verified physical-camera performance.'};
}
