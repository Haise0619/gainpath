import type {DocumentData,TransactionPort} from '../../platform/firestore/store';
import type {Firestore} from 'firebase-admin/firestore';
import {DomainError} from '../../platform/errors';
import {digestOf,object,keys} from '../workouts/workout-backup-validation';
import {requiredIdentifier} from '../../platform/validation';
import type {RecommendationCommandDependencies} from './recommendation-configuration';
import {requireQueueAdmin,readRecommendationMemberState} from './recommendation-queue-security';
import {evaluateRecommendationConsentV2} from './recommendation-consent-v2';
import type {InsightsAuth} from './exercise-insights-contracts';
import {createCanonicalRecommendationLifecycle,type ReviewedCanonicalRuntime,type CanonicalSuggestion} from './canonical-recommendation-lifecycle';
import {recommendationPreferences} from './recommendation-personalization';
import {resolveExerciseExecution} from '../content/exercise-execution';
import {activityBackup,aggregateActivity,isTestData,validatePlannerOutput,validateOutreachOutput,type PlannerExercise,type PlannerRoutine,type AdminAiProvider} from './admin-ai-assistance';

type Row={id:string;data:DocumentData};
function homeBranch(user: DocumentData | undefined, org: string): string | undefined {
  const id = user?.homeBranchId ?? user?.primaryBranchId;
  return user?.organizationId === org && typeof id === 'string' && /^[\w-]{1,128}$/.test(id)
    ? id : undefined;
}
export interface AdminAiReader {rows(path:string,max:number):Promise<Row[]>}
export function firestoreAdminAiReader(db:Firestore):AdminAiReader{return{async rows(path,max){
  const snapshot=await db.collection(path).limit(max+1).get();
  if(snapshot.size>max)throw new DomainError('resource-exhausted','Analysis limit reached. Narrow the available data before retrying.');
  return snapshot.docs.map(d=>({id:d.id,data:d.data()}));
}};}
export interface AdminAiDependencies extends RecommendationCommandDependencies {runtime:ReviewedCanonicalRuntime;aiReader:AdminAiReader;aiProvider?:AdminAiProvider}
function unavailable(message:string):never {throw new DomainError('failed-precondition',message);}
const metrics=(r:Awaited<ReturnType<AdminAiProvider>>)=>({model:r.model,latencyMillis:r.latencyMillis,...r.usage,providerSource:r.providerSource,cacheHit:r.cacheHit});
export function createAdminAiService(deps:AdminAiDependencies){
  const now=()=> (deps.clock??Date.now)();
  async function authorize(auth:InsightsAuth,org:string){await deps.store.transact(tx=>requireQueueAdmin(tx,auth,org));}
  async function permission(tx:TransactionPort,org:string,member:string,external:boolean,delivery=true){
    const purposes=external?(delivery?['exerciseInsights','recommendationGeneration','recommendationDelivery','externalAiInference'] as const:['exerciseInsights','externalAiInference'] as const):['exerciseInsights'] as const;
    const state=await readRecommendationMemberState(tx,{organizationId:org,memberId:member},now(),deps.runtime.notices,
      purposes);
    if(!state.eligible)unavailable('Member permissions do not allow this analysis.');
    const consent=await tx.get(`orgs/${org}/recommendationConsent/${member}`);
    return{fingerprint:digestOf(consent),boundary:Math.max(...purposes.map(p=>{
      const d=evaluateRecommendationConsentV2(consent,{organizationId:org,memberId:member},now(),deps.runtime.notices,p as 'exerciseInsights');return d.allowed?d.historyStartAtMillis??0:now();
    }))};
  }
  async function activity(org:string,member:string,days:number,boundary:number){
    const raw=await deps.aiReader.rows(`orgs/${org}/members/${member}/workoutBackups`,200);
    const valid=raw.flatMap(row=>{const v=activityBackup(org,member,row.id,row.data);return v&&typeof v.data.startedAtMillis==='number'&&v.data.startedAtMillis>=boundary?[v]:[];});
    const stats=aggregateActivity(valid,now(),days);
    const latest=valid.filter(r=>r.data.kind==='session'&&Number(r.data.endedAtMillis)>=now()-days*86400000)
      .sort((a,b)=>Number(b.data.endedAtMillis)-Number(a.data.endedAtMillis))[0]?.id;
    return{...stats,latestKey:latest??null};
  }
  async function memberAnalysis(auth:InsightsAuth,org:string,member:string,days:number,external=false){
    await authorize(auth,org);requiredIdentifier(member,'member');
    if(external){const identity=await deps.readAuthIdentity(member);if(identity.disabled||!identity.emailVerified)unavailable('The member account is unavailable for AI analysis.');}
    const privacy=await deps.store.transact(async tx=>{await requireQueueAdmin(tx,auth,org);return permission(tx,org,member,external);});
    const profile=await deps.store.transact(async tx=>{await requireQueueAdmin(tx,auth,org);return await tx.get(`orgs/${org}/profiles/${member}`)??{};});
    const prefs=recommendationPreferences(profile);
    const stats=await activity(org,member,days,privacy.boundary);
    const catalog=await catalogs(org);
    const label=(id:string)=>catalog.exercises.find(e=>e.id===id)?.name??id;
    const history=await deps.aiReader.rows(`orgs/${org}/canonicalRecommendations`,300);
    const existing=history.filter(r=>r.data.memberId===member).map(r=>({id:r.id,status:r.data.status,title:(r.data.suggestion as any)?.targetLabel??'Recommendation'}));
    const {current, homeBranchName}=await deps.store.transact(async tx=>{
      await requireQueueAdmin(tx,auth,org);
      const p=await permission(tx,org,member,external);
      if(p.fingerprint!==privacy.fingerprint)unavailable('Member permissions changed.');
      const current=await tx.get(`orgs/${org}/members/${member}`);
      const id=homeBranch(await tx.get(`users/${member}`),org);
      const location=id ? await tx.get(`orgs/${org}/branches/${id}`) : undefined;
      const homeBranchName=location?.displayName??location?.name;
      return {current,homeBranchName:typeof homeBranchName==='string' ? homeBranchName : null};
    });
    return{memberId:member,name:String(current?.displayName??member),goals:prefs.goals,experience:prefs.experience??null,
      workouts:stats.workouts,completedRoutines:stats.completedRoutines,lastWorkout:stats.lastWorkout,
      exercises:Object.entries(stats.exercises).sort((a,b)=>b[1]-a[1]).map(([id,count])=>({id,name:label(id),count})),
      routines:Object.entries(stats.routines).map(([id,count])=>({id,name:catalog.routines.find(r=>r.id===id)?.name??id,count})),
      muscleGroups:Object.entries(stats.exercises).reduce<Record<string,number>>((a,[id,count])=>{const group=catalog.exercises.find(e=>e.id===id)?.muscleGroup;if(group)a[group]=(a[group]??0)+count;return a;},{}),
      existing,privacy,latestKey:stats.latestKey,days,homeBranchName,activityNote:isTestData(current??{},member)?'TEST activity is excluded from real workout statistics. Fitness Profile recommendations remain available.':null};
  }
  async function catalogs(org:string){
    const [exerciseRows,content,programs]=await Promise.all(['exerciseVideos','content','workoutProgramDrafts'].map(c=>deps.aiReader.rows(`orgs/${org}/${c}`,250)));
    const exercises:PlannerExercise[]=exerciseRows.filter(r=>r.data.isActive===true&&r.data.archived!==true).map(({id,data:d})=>({id,name:String(d.exerciseName??d.name??d.title??id),
      difficulty:String(d.difficulty??''),category:String(d.category??d.muscleCategory??''),muscleGroup:String(d.muscleGroup??d.muscleCategory??''),equipment:String(d.equipment??''),
      executionMode:resolveExerciseExecution(org,id,d),revision:Number(d.editRevision??0),aliases:Array.isArray(d.aliases)?d.aliases.filter((v):v is string=>typeof v==='string'):[]}));
    const routines:PlannerRoutine[]=content.filter(r=>r.data.status==='published'&&r.data.archived!==true&&Array.isArray(r.data.exercises)).map(({id,data:d})=>({id,name:String(d.title??id),difficulty:String(d.difficulty??''),durationMinutes:Number(d.estimatedMinutes??0),exerciseIds:(d.exercises as any[]).map(e=>String(e.exerciseId))}));
    return{exercises,routines,programs:programs.map(r=>({id:r.id,name:String((r.data.program as any)?.title??r.data.title??r.id)}))};
  }
  async function top(auth:InsightsAuth,org:string,days:number,limit=10,external=false,branchId?:string){
    await authorize(auth,org);const rows=await deps.aiReader.rows(`orgs/${org}/members`,250),members=[];
    for(const row of rows){
      if(row.data.role!=='member'||row.data.status!=='active'||isTestData(row.data,row.id))continue;
      const eligible=await deps.store.transact(async tx=>{await requireQueueAdmin(tx,auth,org);const user=await tx.get(`users/${row.id}`);if(isTestData(user??{},row.id)||await tx.get(`datasetAssignments/${row.id}`))return null;
        if(branchId&&homeBranch(user,org)!==branchId)return null;
        try{const p=await permission(tx,org,row.id,external,false);return{p,profile:await tx.get(`orgs/${org}/profiles/${row.id}`)};}catch(e){if(e instanceof DomainError&&e.code==='failed-precondition')return null;throw e;}});
      if(!eligible)continue;
      const stats=await activity(org,row.id,days,eligible.p.boundary);if(!stats.workouts)continue;
      members.push({memberId:row.id,name:String(row.data.displayName??row.id),goals:recommendationPreferences(eligible.profile).goals,workouts:stats.workouts,completedRoutines:stats.completedRoutines,lastWorkout:stats.lastWorkout,
        ...(limit>10?{activity:{exercises:stats.exercises,routines:stats.routines}}:{})});
    }
    await authorize(auth,org);return{members:members.sort((a,b)=>b.workouts-a.workouts||(b.lastWorkout??0)-(a.lastWorkout??0)||a.memberId.localeCompare(b.memberId)).slice(0,limit),days,excludesTestData:true};
  }
  return{async execute(auth:InsightsAuth,org:string,operation:string,q:Record<string,unknown>):Promise<unknown>{
    const day=()=>{if(q.days!==7&&q.days!==30)throw new DomainError('invalid-argument','Choose 7 or 30 days.');return Number(q.days);};
    if(operation==='admin.ai.member.search'){
      keys(q,['schemaVersion','organizationId','query','branchId'],['schemaVersion','organizationId','query']);await authorize(auth,org);
      const branchId=q.branchId===undefined?undefined:requiredIdentifier(q.branchId,'branchId');
      if(typeof q.query!=='string'||q.query.trim().length<2||q.query.length>80)throw new DomainError('invalid-argument','Enter 2–80 characters to search members.');
      const query=q.query.trim().toLowerCase(),rows=await deps.aiReader.rows(`orgs/${org}/members`,250),matches=[];
      for(const row of rows){
        if(row.data.role!=='member'||row.data.status!=='active')continue;
        const current=await deps.store.transact(async tx=>{await requireQueueAdmin(tx,auth,org);return{user:await tx.get('users/'+row.id),assignment:await tx.get('datasetAssignments/'+row.id)};});
        if(branchId&&homeBranch(current.user,org)!==branchId)continue;
        if(![row.id,row.data.displayName,row.data.email,current.user?.email].some(v=>typeof v==='string'&&v.toLowerCase().includes(query)))continue;
        let canAnalyze=false;
        if(!current.assignment||deps.runtime.scopedDataset){try{await deps.store.transact(tx=>permission(tx,org,row.id,false));canAnalyze=true;}catch(e){if(!(e instanceof DomainError))throw e;}}
        matches.push({memberId:row.id,name:String(row.data.displayName??row.id),isTest:isTestData(row.data,row.id)||isTestData(current.user??{},row.id),canAnalyze,
          ...(canAnalyze?{}:{reason:'Current analysis permission or data scope is unavailable.'})});
      }
      await authorize(auth,org);return{members:matches.sort((a,b)=>a.name.localeCompare(b.name)||a.memberId.localeCompare(b.memberId)).slice(0,25),hasMore:matches.length>25};
    }
    if(operation==='admin.ai.members'){
      keys(q,['schemaVersion','organizationId','days','branchId'],['schemaVersion','organizationId','days']);
      const branchId=q.branchId===undefined?undefined:requiredIdentifier(q.branchId,'branchId');
      const result=await top(auth,org,day(),10,false,branchId);
      const branches=(await deps.aiReader.rows(`orgs/${org}/branches`,250)).flatMap(({id,data})=>{
        const name=data.displayName??data.name;
        return typeof name==='string'&&name.trim()?[{id,name}]:[];
      });
      await authorize(auth,org);
      return {...result,branches};
    }
    if(operation==='admin.ai.member'){keys(q,['schemaVersion','organizationId','memberId','days']);const {privacy,latestKey,...analysis}=await memberAnalysis(auth,org,requiredIdentifier(q.memberId,'member'),day());return analysis;}
    await authorize(auth,org);
    if(operation==='admin.ai.planner'){
      keys(q,['schemaVersion','organizationId','type','days','instructions','requestId']);
      if(!['exercise','routine','program'].includes(String(q.type))||typeof q.instructions!=='string'||q.instructions.length>600)throw new DomainError('invalid-argument','Invalid planner options.');
      requiredIdentifier(q.requestId,'request');const days=day(),catalog=await catalogs(org);
      if(!catalog.exercises.length)unavailable('Add active catalog exercises before generating suggestions.');
      if(q.type==='program'&&!catalog.routines.length)unavailable('Publish a routine before planning a Program.');
      const cohort=await top(auth,org,days,250,true);
      const evidence:Record<string,string>={catalog_count:`${catalog.exercises.length} active catalog exercises.`,routine_count:`${catalog.routines.length} published routines.`,activity_scope:`${cohort.members.length} consenting active members over ${days} days; synthetic/test data excluded.`};
      const byGroup:Record<string,number>={};for(const e of catalog.exercises)if(e.muscleGroup)byGroup[e.muscleGroup]=(byGroup[e.muscleGroup]??0)+1;
      for(const [index,[group,count]]of Object.entries(byGroup).entries())evidence['muscle_'+index]=`${group}: ${count} active catalog exercises.`;
      const exerciseUsage:Record<string,number>={},routineUsage:Record<string,number>={},goalCounts:Record<string,number>={};
      for(const member of cohort.members){for(const [id,count]of Object.entries(member.activity?.exercises??{}))exerciseUsage[id]=(exerciseUsage[id]??0)+count;for(const [id,count]of Object.entries(member.activity?.routines??{}))routineUsage[id]=(routineUsage[id]??0)+count;for(const g of member.goals)goalCounts[g]=(goalCounts[g]??0)+1;}
      for(const [i,[id,count]]of Object.entries(exerciseUsage).entries())evidence['usage_'+i]=`${catalog.exercises.find(e=>e.id===id)?.name??id}: ${count} completed workout summaries in the consenting active-member sample.`;
      const invoke=deps.aiProvider??unavailable('Gemini is not configured for Admin assistance.');
      // Keep the prompt bounded; complete catalog names and aliases participate in local duplicate validation.
      const equipmentRows=await deps.aiReader.rows(`orgs/${org}/gymEquipment`,250);
      const equipmentAvailability=equipmentRows.filter(r=>r.data.isActive===true).map(r=>String(r.data.name??r.data.equipmentName??r.data.title??'')).filter(Boolean);
      const coverage={muscleGroups:byGroup,categories:{} as Record<string,number>,difficulties:{} as Record<string,number>};
      for(const e of catalog.exercises){coverage.categories[e.category]=(coverage.categories[e.category]??0)+1;coverage.difficulties[e.difficulty]=(coverage.difficulties[e.difficulty]??0)+1;}
      for(const [i,[category,count]]of Object.entries(coverage.categories).entries())evidence['category_'+i]=category+': '+count+' active exercises.';
      for(const level of ['Beginner','Intermediate','Advanced'])evidence['difficulty_'+level]=level+': '+(coverage.difficulties[level]??0)+' active exercises.';
      evidence.equipment_inventory=equipmentAvailability.length?('Active gym equipment: '+equipmentAvailability.join(', ')): 'No active gym equipment inventory entries found; physical availability is unverified.';
      // Complete catalog is mandatory for novelty; reject oversized input instead of silently truncating.
      const inputCatalog={exercises:catalog.exercises,routines:q.type==='exercise'?[]:catalog.routines,programs:q.type==='program'?catalog.programs:[]};
      const input={type:q.type,days,instructions:q.instructions,catalog:inputCatalog,coverage,equipmentAvailability,exerciseUsage,routineUsage,goalCounts,evidence};
      if(Buffer.byteLength(JSON.stringify(input))>11000)unavailable('The catalog summary is too large for this analysis. Shorten additional instructions or narrow the content.');
      const inference=await invoke({task:'planner',input});
      let raw:unknown;try{raw=JSON.parse(inference.text);}catch{unavailable('AI returned invalid JSON. Try Generate again.');}
      const result=validatePlannerOutput(raw,String(q.type),catalog.exercises,catalog.routines,evidence,catalog.programs.map(p=>p.name));
      await authorize(auth,org);return{...result,ai:metrics(inference),grounding:{enabled:false,reason:'The existing adapter has no Search Grounding tools. No paid search configuration was enabled.'},scope:`${catalog.exercises.length} active exercises, ${catalog.routines.length} published routines; ${cohort.members.length} consenting active members over ${days} days. Complete comparison catalog: ${inputCatalog.exercises.length} exercises and ${inputCatalog.routines.length} routines.`};
    }
    if(operation==='admin.ai.outreach.generate'){
      keys(q,['schemaVersion','organizationId','memberId','days','requestId']);const member=requiredIdentifier(q.memberId,'member'),requestId=requiredIdentifier(q.requestId,'request');
      const analysis=await memberAnalysis(auth,org,member,day(),true);
      const previewId=digestOf({org,member,actor:auth.uid,requestId}),previewPath=`orgs/${org}/adminAiPreviews/${previewId}`;
      const old=await deps.store.transact(tx=>tx.get(previewPath));if(old&&Number(old.expiresAtMillis)>now()&&old.actorId===auth.uid&&old.consentFingerprint===analysis.privacy.fingerprint)return old.result;
      const key=analysis.latestKey??'fitness-profile';
      const candidates=await deps.store.transact(async tx=>{await requireQueueAdmin(tx,auth,org);await permission(tx,org,member,true);return deps.runtime.backupSuggestions?.(tx,org,member,key,now(),Math.max(analysis.privacy.boundary,now()-analysis.days*86400000),true)??[];});
      // An explicit Admin outreach is independent of automatic recommendation fatigue.
      const eligible:readonly CanonicalSuggestion[]=candidates;
      const candidateCounts={tutorial:eligible.filter(s=>s.target.kind==='content').length,routine:eligible.filter(s=>s.target.kind==='routine').length,coach:eligible.filter(s=>s.target.kind==='trainer').length};
      const availabilityNotes=[...(!candidateCounts.tutorial?['No eligible tutorial matches the available training context.']:[]),...(!candidateCounts.routine?['No eligible published routine is currently available for this context.']:[]),...(!candidateCounts.coach?['No coach currently passes all matching, verification, branch and booking-availability checks.']:[])];
      const empty=(reason:string,ai?:Record<string,unknown>)=>({previewId:null,recommendations:[],candidateCounts,availabilityNotes,message:reason+' Review published content, member permissions and profile; training-based suggestions need a valid synced workout.',...(ai?{ai}:{})});
      console.info('module13_outreach_candidates',{requestTag:previewId,...candidateCounts});
      if(!eligible.length)return empty('No eligible recommendation candidates were found.');
      const offered=eligible.slice(0,18).map((s,i)=>({id:'C'+(i+1),kind:s.target.kind,title:s.targetLabel,factors:s.ai?.factors??[],context:s.ai?.context??{}}));
      const invoke=deps.aiProvider??unavailable('Gemini is not configured for Admin assistance.');
      console.info('module13_outreach_inference_started',{requestTag:previewId,candidateCount:offered.length});
      let inference:Awaited<ReturnType<AdminAiProvider>>;
      try{inference=await invoke({task:'outreach',input:{features:{...offered[0]?.context,goals:analysis.goals,workouts:analysis.workouts,days:analysis.days,completedRoutines:analysis.completedRoutines,
        exercises:analysis.exercises.map(e=>({name:e.name,count:e.count})),muscleGroups:analysis.muscleGroups},candidates:offered}});}catch(e){console.warn('module13_outreach_inference_failed',{requestTag:previewId,reason:e&&typeof e==='object'&&'reason' in e?String(e.reason):'provider_error'});throw e;}
      console.info('module13_outreach_inference_completed',{requestTag:previewId,...metrics(inference)});
      let raw:unknown;try{raw=JSON.parse(inference.text);}catch{console.warn('module13_outreach_validation',{requestTag:previewId,accepted:0,rejected:{invalid_json:1}});unavailable('AI returned invalid JSON (invalid_json). Member analysis is retained.');}
      const chosen=validateOutreachOutput(raw,offered,diagnostic=>console.info('module13_outreach_validation',{requestTag:previewId,...diagnostic})),suggestions=chosen.map(c=>{const i=offered.findIndex(o=>o.id===c.candidateId),s=eligible[i];return{...s,summary:c.message,source:{kind:'admin_outreach' as const,recordKey:key},outreach:{sentBy:auth.uid,previewId,analysisDays:analysis.days,baselineFingerprint:digestOf(s)},
        ai:{...s.ai!,method:'gemini' as const,...metrics(inference),candidateCount:offered.filter(o=>o.kind===s.target.kind).length}};});
      if(!suggestions.length)return empty('Gemini selected no suitable candidates. No recommendation was sent.',metrics(inference));
      return await deps.store.transact(async tx=>{await requireQueueAdmin(tx,auth,org);const p=await permission(tx,org,member,true);if(p.fingerprint!==analysis.privacy.fingerprint)unavailable('Member permissions changed.');
        const rendered=[],retained:typeof suggestions=[];
        for(const s of suggestions){const target=await deps.runtime.resolveTarget(tx,org,s,now(),member,true);if(!target){console.info('module13_outreach_target_rejected',{requestTag:previewId,reason:'target_unavailable'});continue;}
          rendered.push({index:retained.length,kind:s.target.kind,title:s.targetLabel,message:s.summary,why:s.explanations,context:s.ai?.workoutContext,target});retained.push(s);}
        if(!rendered.length)return empty('The selected targets are no longer available. No recommendation was sent.',metrics(inference));
        const result={previewId,recommendations:rendered,ai:metrics(inference),candidateCounts,availabilityNotes};
        tx.set(previewPath,{actorId:auth.uid,memberId:member,consentFingerprint:p.fingerprint,createdAtMillis:now(),expiresAtMillis:now()+30*60000,suggestions:retained,result});return result;
      });
    }
    if(operation==='admin.ai.outreach.send'){
      keys(q,['schemaVersion','organizationId','previewId','selections']);
      if(typeof q.previewId!=='string'||!/^[a-f0-9]{64}$/.test(q.previewId)||!Array.isArray(q.selections)||!q.selections.length||q.selections.length>3)throw new DomainError('invalid-argument','Select up to three recommendations.');
      const selected=q.selections.map(v=>{const s=object(v);keys(s,['index','message']);if(!Number.isSafeInteger(s.index)||Number(s.index)<0||Number(s.index)>2||typeof s.message!=='string'||!s.message.trim()||s.message.length>400)throw new DomainError('invalid-argument','Invalid recommendation message.');return{index:Number(s.index),message:s.message.trim()};});
      if(new Set(selected.map(s=>s.index)).size!==selected.length)throw new DomainError('invalid-argument','Duplicate selection.');
      const preview=await deps.store.transact(async tx=>{await requireQueueAdmin(tx,auth,org);const p=await tx.get(`orgs/${org}/adminAiPreviews/${q.previewId}`);if(!p||p.actorId!==auth.uid||Number(p.expiresAtMillis)<=now())unavailable('Preview expired. Generate again.');await permission(tx,org,String(p.memberId),true);return p;});
      const ids=await createCanonicalRecommendationLifecycle(deps).outreach(auth,org,String(preview.memberId),String(q.previewId),String(preview.consentFingerprint),selected.map(s=>{const source=(preview.suggestions as CanonicalSuggestion[])[s.index];if(!source)unavailable('Invalid preview selection.');return{...source,summary:s.message};}));
      return{ids,status:'delivered'};
    }
    throw new DomainError('invalid-argument','Unsupported AI operation.');
  }};
}
