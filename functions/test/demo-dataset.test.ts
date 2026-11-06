import {describe,it,expect} from 'vitest';
import {buildModule13DemoDataset,validateModule13DemoDataset} from '../src/modules/recommendation/demo-dataset';
import {MemoryStore} from './memory-store';
import {evaluateTrainerCandidates} from '../src/modules/recommendation/trainer-candidate-eligibility';
import {evaluateContentCandidates} from '../src/modules/recommendation/content-candidate-eligibility';
import {extractWorkoutEvidence} from '../src/modules/recommendation/workout-evidence';
import {createOwnedDemoStore} from '../src/modules/recommendation/demo-access-policy';
import {publishRoutine} from '../src/modules/content/publish-routine';

const nowMillis=Date.parse('2026-11-03T00:00:00Z');
describe('complete Module13 demo source dataset',()=>{
 it('contains complete catalog records and real publishable source blueprints for every destination',async()=>{
  const d=await buildModule13DemoDataset({nowMillis}),store=new MemoryStore();for(const[p,v]of Object.entries(d.documents))store.documents.set(p,structuredClone(v));
  for(const id of d.publicationIds){const published=d.documents[`orgs/gainpath/content/${id}`],blueprintId=published.sourceBlueprintId as string;expect(d.documents[`orgs/gainpath/routineBlueprints/${blueprintId}`]).toBeDefined();await expect(publishRoutine(store,{uid:d.adminId,token:{email_verified:true}},{schemaVersion:1,organizationId:'gainpath',blueprintId,requestId:`validate-${id}`},()=>nowMillis)).resolves.toMatchObject({status:'published'});}
  for(const entry of d.contentSource.catalog)expect(entry.data).toMatchObject({schemaVersion:1,videoUrl:'',isActive:true});
  expect(d.manifest.mutablePaths.some(p=>p.includes('/recommendationConsentAudit/')||p.includes('/recommendationConsentReceipts/'))).toBe(false);
 });
 it('builds reproducible eight-Coach eighteen-Member twelve-tutorial source data without outcomes',async()=>{
  const a=await buildModule13DemoDataset({nowMillis}),b=await buildModule13DemoDataset({nowMillis});
  expect(a).toEqual(b);expect(a.coachIds).toHaveLength(8);expect(a.memberIds).toHaveLength(18);expect(a.authUsers).toHaveLength(27);expect(a.publicationIds).toHaveLength(12);
  expect(a.authUsers.every(u=>!('password'in u)&&u.email.endsWith('@gainpath-demo.invalid'))).toBe(true);
  expect(Object.keys(a.documents).some(p=>/recommendationLeads|recommendationRecipients|recommendationDeliveryReceipts|\/notifications\//.test(p))).toBe(false);
  expect(validateModule13DemoDataset(a)).toMatchObject({valid:true,coaches:8,members:18,publishedTutorials:12});
 });
 it('passes existing credentials, roster, capacity and published tutorial eligibility with several common Coaches',async()=>{
  const d=await buildModule13DemoDataset({nowMillis}),store=new MemoryStore();for(const[p,v]of Object.entries(d.documents))store.documents.set(p,structuredClone(v));
  const m=d.memberScenarios[0];
  const trainers=await evaluateTrainerCandidates({schemaVersion:1,organizationId:'gainpath',memberId:m.memberId,exerciseId:m.exerciseId,learningObjective:'technique_foundations',level:'beginner',localDate:d.bookingDate,durationMinutes:60},{repository:{transact:w=>store.transact(w),listCoachIds:async()=>d.coachIds},trustedExpertise:d.expertise,clock:()=>nowMillis,readIdentity:async uid=>({exists:d.authUsers.some(u=>u.uid===uid),emailVerified:true,disabled:false})});
  expect(trainers.candidates.length).toBeGreaterThanOrEqual(3);expect(trainers.rejected).toContainEqual(expect.objectContaining({candidateId:d.coachIds[7],reason:'coach_unavailable'}));expect(trainers.candidates.every(c=>c.availableOptions.length>0)).toBe(true);
  const contents=evaluateContentCandidates({organizationId:'gainpath',exerciseId:m.exerciseId,objective:'technique_foundations',level:'beginner'},d.contentSource);expect(contents.candidates.length).toBeGreaterThanOrEqual(3);
 });
 it('uses existing valid backup wire contracts and isolated intentional invalid cases',async()=>{
  const d=await buildModule13DemoDataset({nowMillis});for(const record of d.workoutRecords){if(record.expectedValidation==='valid')expect(()=>extractWorkoutEvidence({organizationId:'gainpath',memberId:record.memberId},{id:record.rowId,data:d.documents[record.backupPath]},nowMillis)).not.toThrow();}
  expect(d.negativeFixtures.some(n=>n.scenario==='invalid_digest')).toBe(true);expect(d.negativeFixtures.some(n=>n.scenario==='conflicting_immutable_digest')).toBe(true);
 });
 it('retains independent default-off and grant/revoke history variations',async()=>{
  const d=await buildModule13DemoDataset({nowMillis});
  const off=d.memberScenarios.find(m=>m.scenario==='all_purposes_off')!;expect(d.documents[`orgs/gainpath/recommendationConsent/${off.memberId}`]).toBeUndefined();
  const revoked=d.memberScenarios.find(m=>m.scenario==='generation_revoked')!,state=d.documents[`orgs/gainpath/recommendationConsent/${revoked.memberId}`] as any;expect(state.purposes.recommendationGeneration.granted).toBe(false);expect(state.purposes.exerciseInsights.granted).toBe(true);
  expect(d.consentCommands.length).toBeGreaterThan(40);expect(Object.keys(d.documents).some(p=>p.includes('/recommendationConsentAudit/'))).toBe(true);
 });
 it('rejects a dangling credential, invalid digest or ownership manifest before seeding',async()=>{
  const d=await buildModule13DemoDataset({nowMillis});const changed=structuredClone(d);delete changed.documents[`orgs/gainpath/coachProfiles/${d.coachIds[0]}/certificationState/current`];expect(()=>validateModule13DemoDataset(changed)).toThrow();
 });
 it('authorizes genuinely absent reservation locks without permitting unowned records',async()=>{
  const d=await buildModule13DemoDataset({nowMillis}),inner=new MemoryStore();for(const[p,v]of Object.entries(d.documents))inner.documents.set(p,structuredClone(v));const store=createOwnedDemoStore(inner,d.manifest);
  const m=d.memberScenarios[0];const result=await evaluateTrainerCandidates({schemaVersion:1,organizationId:'gainpath',memberId:m.memberId,exerciseId:m.exerciseId,learningObjective:m.objective,level:m.level,localDate:d.bookingDate,durationMinutes:60},{repository:{transact:w=>store.transact(w),listCoachIds:async()=>d.coachIds},trustedExpertise:d.expertise,clock:()=>nowMillis,readIdentity:async uid=>({exists:d.authUsers.some(u=>u.uid===uid),disabled:false,emailVerified:true})});
  expect(result.candidates.length).toBeGreaterThanOrEqual(3);
 });
});
