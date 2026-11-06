import {FieldPath,type Firestore} from 'firebase-admin/firestore';
import type {Auth} from 'firebase-admin/auth';
import {DomainError} from '../../platform/errors';
import {FirestoreStore} from '../../platform/firestore/firestore-store';
import type {DocumentData,DocumentStore} from '../../platform/firestore/store';
import {object,keys} from '../workouts/workout-backup-validation';
import {requiredIdentifier} from '../../platform/validation';
import {adminReport,type ReportCollection,type OperationalReport} from '../analytics/admin-reporting';
import {adminWorkoutReport,type WorkoutReport} from '../analytics/admin-workout-reporting';
import {workoutPrograms} from '../content/workout-programs';
import type {InsightsRequest} from '../recommendation/exercise-insights-contracts';
import type {ReviewedConsentNoticePolicy} from '../recommendation/recommendation-consent-v2';
import {recommendationCommandError} from '../recommendation/recommendation-configuration';
import {createFypDatasetBackend,assertFypAdminReadOperation} from './fyp-backend';
import type {FypRuntimeReleaseGrant} from './fyp-runtime-release';
import {createFypEvidenceReader,type FypEvidenceSource} from './fyp-evidence-reader';
import {createUnifiedAdminReader,mergeUnifiedAdminPage,UNIFIED_ROOT,type UnifiedDirectoryKind,type UnifiedDirectoryQuery} from './unified-admin-reader';
import {readUnifiedSampleBusiness} from './unified-business-reader';
import {mergeUnifiedOperationalReports,mergeUnifiedWorkoutReports} from './unified-admin-reporting';
const fields:Record<string,string[]>={
 'admin.unified.directory':['kind','afterId','limit','query','status','source'],
 'admin.unified.member':['memberId'], 'admin.unified.coach':['coachId'],
 'admin.unified.programs':[], 'admin.unified.report':['startAtMillis','endAtMillis'],
 'admin.unified.workouts':['startAtMillis','endAtMillis'], 'admin.unified.business':['startAtMillis','endAtMillis'],
 'admin.unified.cohort':['operation','input'],
};
const deny=()=>new DomainError('permission-denied','Current unified Admin read access is required.');
export function parseUnifiedAdminEnvelope(raw:unknown){const q=object(raw);keys(q,['schemaVersion','operation','data']);
 if(q.schemaVersion!==1||typeof q.operation!=='string'||!Object.hasOwn(fields,q.operation)||Buffer.byteLength(JSON.stringify(q))>16384)throw deny();
 const data=object(q.data);keys(data,['schemaVersion','organizationId',...fields[q.operation]],['schemaVersion','organizationId']);
 if(![1,2].includes(data.schemaVersion as number)||data.organizationId!=='gainpath'||!['admin.unified.report','admin.unified.programs'].includes(String(q.operation))&&data.schemaVersion!==1)throw deny();
 if(q.operation==='admin.unified.directory'&&!['members','coaches','coachProfiles','content','routineBlueprints','branches','exerciseVideos'].includes(String(data.kind)))throw deny();
 if(q.operation==='admin.unified.cohort')assertFypAdminReadOperation(String(data.operation));return{operation:q.operation,data};
}
/** One fixed transport; no new role, direct client Rules access or production recommendation processing. */
export function createUnifiedAdminBackend(options:{db:Firestore;auth:Pick<Auth,'getUser'>;clock?:()=>number;release?:FypRuntimeReleaseGrant}){
 const {db,auth}=options,clock=options.clock??Date.now,cohort=createFypDatasetBackend({...options,canonicalAdminRead:true}),base=new FirestoreStore(db);
 const canonical:DocumentStore={transact:work=>base.transact(tx=>work({get:p=>tx.get(p),getAll:tx.getAll?(p)=>tx.getAll!(p):undefined,create:()=>{throw deny();},set:()=>{throw deny();}}))};
 const page=async(path:string,after:string|undefined,limit:number)=>{let query=db.collection(path).orderBy(FieldPath.documentId()).limit(limit);if(after)query=query.startAfter(after);return(await query.get()).docs.map(d=>({id:d.id,data:d.data()}));};
 const freshIdentity=async(uid:string)=>{try{const u=await auth.getUser(uid);return{exists:true,disabled:u.disabled,emailVerified:u.emailVerified};}catch(e){if((e as {code?:string}).code==='auth/user-not-found')return{exists:false,disabled:false,emailVerified:false};throw e;}};
 async function command(request:InsightsRequest):Promise<unknown>{try{
  const e=parseUnifiedAdminEnvelope(request.data),c=await cohort.adminReadContext(request),d=e.data,reader=createUnifiedAdminReader(db);
  const call=async(operation:string,data:DocumentData)=>cohort.command({...request,data:{schemaVersion:1,operation,data}});
  const input={schemaVersion:d.schemaVersion,organizationId:'gainpath',startAtMillis:d.startAtMillis,endAtMillis:d.endAtMillis};
  const window={startAtMillis:Number(d.startAtMillis),endAtMillis:Number(d.endAtMillis)};
  let result:unknown;
  if(e.operation==='admin.unified.cohort')result=await call(String(d.operation),object(d.input));
  else if(e.operation==='admin.unified.directory')result=await reader.list(Object.fromEntries(fields[e.operation].filter(k=>d[k]!==undefined).map(k=>[k,d[k]])) as unknown as UnifiedDirectoryQuery);
  else if(e.operation==='admin.unified.coach'){
   const id=requiredIdentifier(d.coachId,'coachId'),publication=await reader.coachSource(id),root=publication.source==='fyp'?UNIFIED_ROOT:'orgs/gainpath';
   const read=async(path:string)=>publication.source==='fyp'?reader.owned(path):(await db.doc(path).get()).data();
   const [member,certification]=await Promise.all([read(`${root}/members/${id}`),read(`${root}/coachProfiles/${id}/certificationState/current`)]);
   const sample=publication.source==='fyp'?await readUnifiedSampleBusiness(c.store,{startAtMillis:0,endAtMillis:clock()},clock()):null;
   const appointments=sample?.rows.filter(r=>r.kind==='appointment'&&r.coachId===id)??[];
   result={schemaVersion:1,organizationId:'gainpath',coachId:id,source:publication.source,sourcePath:publication.sourcePath,readOnly:publication.source==='fyp',fictionalCredentialMetadata:publication.source==='fyp',draft:publication.draft,publication:publication.publication,branchIds:member?.branchIds??[],targetMembershipEligible:member?.role==='coach'&&member.status==='active',certificationVerified:certification?.certificationVerified===true,approvedCertificationCount:certification?.approvedCount??0,operationalSummary:appointments.map(r=>r.kind==='appointment'?`Fictional ${r.status} appointment · ${new Date(r.startAtMillis+8*3600000).toISOString().slice(0,16).replace('T',' ')} MYT · ${r.memberId} · no actual reservation or settlement`:'')};
  }else if(e.operation==='admin.unified.member'){
   const id=requiredIdentifier(d.memberId,'memberId'),row=await reader.sourceOf('members',id);if(row.record.role!=='member')throw deny();
   const member=mergeUnifiedAdminPage([row],{kind:'members'}).items[0],extra:{label:string;value:string}[]=[];
   if(row.source==='fyp'){
    const [profile,goal]=await Promise.all([reader.owned(`${UNIFIED_ROOT}/profiles/${id}`),reader.owned(`${UNIFIED_ROOT}/profiles/${id}/goals/fyp-training-frequency`)]);
    extra.push({label:'Data source',value:'Persistent FYP fictional record · read-only'},{label:'Login activity',value:'Not inferred from account existence'});
    if(profile)for(const key of ['gender','ageBracket','heightCm','weightKg','experience','activity','goals']){const v=profile[key];if(v!==undefined&&v!==null)extra.push({label:key,value:Array.isArray(v)?v.map(String).join(', '):String(v)});}
    if(goal)extra.push({label:'Recorded fitness goal',value:`${goal.targetValue} ${goal.unit} / ${goal.evaluationPeriod} (${goal.status})`});
    const source=await c.store.transact(tx=>tx.get('module13DemoSource/current'));if(!source||source.schemaVersion!==1||!Array.isArray(source.noticePolicies))throw deny();
    const evidence=createFypEvidenceReader({db,scope:c.scope,store:c.store,fypCapability:c.fypCapability,source:source as unknown as FypEvidenceSource,noticePolicies:source.noticePolicies as ReviewedConsentNoticePolicy[],clock,readAuthIdentity:c.readAuthIdentity});
    const summaries=await adminWorkoutReport(c.store,request.auth,{schemaVersion:1,organizationId:'gainpath',startAtMillis:0,endAtMillis:clock()},{members:async after=>after?[]:[{id,data:row.record}],backups:async(uid,after,limit)=>(await evidence.rows(uid)).filter(r=>!after||r.id>after).slice(0,limit)},clock,c.fypCapability);
    extra.push({label:'Recorded workout observations',value:`${summaries.totals.sessions} synthetic sessions; ${summaries.totals.fullReps} full / ${summaries.totals.partialReps} partial recorded reps`},{label:'Evidence limitation',value:'Fictional observations; no real camera workout, accepted workout or rewards claim'});
    const sample=await readUnifiedSampleBusiness(c.store,{startAtMillis:0,endAtMillis:clock()},clock());
    for(const r of sample.rows.filter(r=>r.kind!=='plan'&&r.memberId===id)){
     if(r.kind==='subscription')extra.push({label:'Sample subscription',value:`${r.planId} · ${r.status} · simulation only; no entitlement`});
     if(r.kind==='program_relationship')extra.push({label:'Program relationship',value:`${r.programId} · illustrative assignment, not an actual enrollment`});
     if(r.kind==='appointment')extra.push({label:'Sample appointment',value:`${r.coachId} · ${r.status} · ${new Date(r.startAtMillis+8*3600000).toISOString().slice(0,16).replace('T',' ')} MYT · simulation only`});
    }
    const recipients=await db.collection(`${UNIFIED_ROOT}/recommendationRecipients`).where('memberId','==',id).limit(21).get();if(recipients.size>20)throw deny();
    for(const recipient of recipients.docs){const r=await reader.owned(recipient.ref.path,recipient.data());extra.push({label:'Recommendation delivery',value:`${r?.kind??'Unknown'} · ${r?.status??r?.state??'Recorded'} · revision ${r?.revision??'unknown'}`});}
    const notices=await db.collection(`${UNIFIED_ROOT}/notifications`).where('recipientId','==',id).limit(21).get();if(notices.size>20)throw deny();for(const notice of notices.docs)await reader.owned(notice.ref.path,notice.data());extra.push({label:'Notification history',value:`${notices.size} recorded in-app notifications; no email/SMS inference`});
   }
   result={schemaVersion:1,organizationId:'gainpath',...member,readOnly:row.source==='fyp',extra};
  }else if(e.operation==='admin.unified.programs'){
   const q={schemaVersion:d.schemaVersion,organizationId:'gainpath',action:'adminList'},canonicalPrograms=await workoutPrograms(canonical,request.auth,q,{clock,freshAuth:async()=>{await cohort.adminReadContext(request);}}),fypPrograms=await call('module/workoutProgramCommand',q) as {programs:{id:string}[];drafts:{program:{id:string};revision:number}[]};
   const existingIds=new Set((canonicalPrograms.programs as {id:string}[]).map(x=>x.id));if(fypPrograms.programs.some(x=>existingIds.has(x.id)))throw deny();
   let routines=(await Promise.all([reader.rows('content','existing'),reader.rows('content','fyp')])).flat().filter(r=>r.record.status==='published'&&(r.record.kind==='routine'||d.schemaVersion===2&&r.record.kind==='routine_v2'));
   if(d.schemaVersion===2){const newer=new Set(routines.filter(r=>r.record.kind==='routine_v2').map(r=>r.source+':'+String(r.record.sourceBlueprintId)));routines=routines.filter(r=>r.record.kind==='routine_v2'||!newer.has(r.source+':'+String(r.record.sourceBlueprintId)));}
   result={schemaVersion:1,organizationId:'gainpath',programs:[...canonicalPrograms.programs,...fypPrograms.programs],drafts:[...canonicalPrograms.drafts,...fypPrograms.drafts],fypProgramIds:fypPrograms.programs.map(x=>x.id),routines:routines.map(r=>({id:r.id,source:r.source,record:r.record}))};
  }else if(e.operation==='admin.unified.business'){
   const sample=await readUnifiedSampleBusiness(c.store,window,clock());result={schemaVersion:1,organizationId:'gainpath',...window,...sample};
  }else if(e.operation==='admin.unified.report'||e.operation==='admin.unified.workouts'){
   // Identity overlap invalidates the merge rather than silently counting it twice.
   const [existingMembers,fypMembers]=await Promise.all([reader.rows('members','existing'),reader.rows('members','fyp')]);const ids=new Set(existingMembers.map(r=>r.id));if(fypMembers.some(r=>ids.has(r.id)))throw deny();
   if(e.operation==='admin.unified.report'){
    const [existing,fyp,sample]=await Promise.all([adminReport(canonical,request.auth,input,{identity:freshIdentity,page:(kind:ReportCollection,after,limit)=>page(`orgs/gainpath/${kind}`,after,limit)},clock),call('module/adminReportingCommand',input) as Promise<OperationalReport>,readUnifiedSampleBusiness(c.store,window,clock())]);
    const merged=mergeUnifiedOperationalReports(existing,fyp,sample.summary),growth=new Map<string,{date:string;existing:number;fyp:number;total:number}>();
    for(const r of [...existingMembers,...fypMembers]){const at=r.record.createdAtMillis;if(r.record.role!=='member'||!Number.isSafeInteger(at)||Number(at)<window.startAtMillis||Number(at)>=window.endAtMillis||Number(at)>clock())continue;const date=new Date(Number(at)+8*3600000).toISOString().slice(0,10),bucket=growth.get(date)??{date,existing:0,fyp:0,total:0};bucket[r.source]++;bucket.total++;growth.set(date,bucket);}
    const programQuery={schemaVersion:1,organizationId:'gainpath',action:'adminList'};
    const [canonicalPrograms,fypPrograms,existingContent,fypContent]=await Promise.all([workoutPrograms(canonical,request.auth,programQuery,{clock,freshAuth:async()=>{await cohort.adminReadContext(request);}}),call('module/workoutProgramCommand',programQuery) as Promise<{programs:unknown[]}>,reader.rows('content','existing'),reader.rows('content','fyp')]);
    const publishedRoutines=(rows:typeof existingContent)=>rows.filter(r=>r.record.kind==='routine'&&r.record.status==='published'&&r.record.archived!==true).length;
    result={...merged,unified:{...merged.unified,catalogCounts:{existingPrograms:canonicalPrograms.programs.length,fypPrograms:fypPrograms.programs.length,existingTutorials:publishedRoutines(existingContent),fypTutorials:publishedRoutines(fypContent)},directoryTotals:{existingMembers:existingMembers.filter(r=>r.record.role==='member').length,fypMembers:fypMembers.filter(r=>r.record.role==='member').length,existingCoaches:existingMembers.filter(r=>r.record.role==='coach').length,fypCoaches:fypMembers.filter(r=>r.record.role==='coach').length},recordCreationTrend:[...growth.values()].sort((a,b)=>a.date.localeCompare(b.date)),definition:'Current eligible account census combines sources; directory totals include inactive administrative records. Record-creation trend includes fictional provisioning, not login activity. Existing financial/booking metrics retain their original source definitions.'}};
   }else{
    const [existing,fyp]=await Promise.all([adminWorkoutReport(canonical,request.auth,input,{members:(after,limit)=>page('orgs/gainpath/members',after,limit),backups:(uid,after,limit)=>page(`orgs/gainpath/members/${uid}/workoutBackups`,after,limit)},clock),call('module/adminWorkoutReportingCommand',input) as Promise<WorkoutReport>]);result=mergeUnifiedWorkoutReports(existing,fyp);
   }
  }else throw deny();
  return await c.finalize(result);
 }catch(e){throw recommendationCommandError(e);}}
 return{command};
}
