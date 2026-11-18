import {MemoryStore} from '../memory-store';
import {createAdminAiService,type AdminAiDependencies} from '../../src/modules/recommendation/admin-ai-service';
import {createCanonicalRecommendationLifecycle,type CanonicalSuggestion,type ReviewedCanonicalRuntime} from '../../src/modules/recommendation/canonical-recommendation-lifecycle';
import {digestOf} from '../../src/modules/workouts/workout-backup-validation';
import {demoWorkoutPayload,DEMO_EXERCISES} from '../../src/modules/recommendation/demo-dataset';
export const now=Date.parse('2026-11-18T00:00:00Z'),root='orgs/gainpath',member='learner';
export const admin={uid:'admin',token:{email_verified:true,auth_time:now/1000,email:'admin@example.com'}};
const policy='workout-backup-guidance-v1';
export function assistanceFixture(){
  const store=new MemoryStore(),d=store.documents;
  d.set(root,{status:'active'});
  for(const [uid,role]of [['admin','admin'],[member,'member']]as const){d.set('users/'+uid,{organizationId:'gainpath',role,email:uid+'@example.com'});d.set(root+'/members/'+uid,{organizationId:'gainpath',userId:uid,displayName:uid,role,status:'active',branchIds:['main']});}
  const yes={granted:true,revision:1,grantedAtMillis:now-100000,revokedAtMillis:null,noticePolicyId:policy,noticeVersion:'workout-backup-v1',contentVersion:'workout-backup-v1',historyStartAtMillis:0};
  d.set(root+'/recommendationConsent/'+member,{schemaVersion:2,policyVersion:'module13-purpose-v2-local',organizationId:'gainpath',memberId:member,revision:4,updatedAtMillis:now-100000,purposes:Object.fromEntries(['exerciseInsights','recommendationGeneration','recommendationDelivery','externalAiInference'].map(p=>[p,yes]))});
  d.set(root+'/profiles/'+member,{goals:['buildMuscle'],experience:'beginner'});
  const payload=demoWorkoutPayload(member,'workout',DEMO_EXERCISES.squat,null,now-1000,{});
  d.set(root+'/members/'+member+'/workoutBackups/session-workout',{schemaVersion:1,classification:'provisional_member_backup',id:'workout',key:'session-workout',kind:'session',digest:digestOf(payload),payloadJson:JSON.stringify(payload)});
  d.set(root+'/exerciseVideos/'+DEMO_EXERCISES.squat,{exerciseName:'Squat',isActive:true,difficulty:'Beginner',muscleCategory:'Legs'});
  d.set(root+'/content/routine',{title:'Foundation',kind:'routine_v2',status:'published',difficulty:'Beginner',estimatedMinutes:20,exercises:[{exerciseId:DEMO_EXERCISES.squat}]});
  const suggestions:CanonicalSuggestion[]=(['content','routine','trainer'] as const).map(kind=>({needKey:'need-'+kind,evidenceFingerprint:digestOf({kind}),policyVersion:policy,exerciseLabel:'Squat',objective:'technique_foundations',source:{kind:'synced_summary',recordKey:'session-workout'},title:'Review '+kind,summary:'Matches your beginner experience.',explanations:['Matches your beginner experience.'],
    target:kind==='routine'?{kind,organizationId:'gainpath',routineId:'routine'}:kind==='trainer'?{kind,coachId:'coach',branchId:'main',observedStartAtMillis:now+3600000,observedEndAtMillis:now+7200000}:{kind,destination:{kind:'published_routine_exercise_tutorial',organizationId:'gainpath',routineId:'routine',exerciseId:DEMO_EXERCISES.squat,exerciseIndex:0,dayNumber:1}},targetLabel:kind==='trainer'?'Verified coach':'Foundation '+kind,
    ai:{method:'rule_fallback',workoutContext:'One recent Squat workout.',fitnessGoals:['buildMuscle'],factors:['experience_match'],context:{experience:'beginner'}}}));
  const runtime:ReviewedCanonicalRuntime={reviewId:policy,enabledTuples:[],notices:[{policyId:policy,noticeVersion:'workout-backup-v1',contentVersion:'workout-backup-v1',history:{mode:'retained',earliestAtMillis:0}}],maximumAgeMillis:30*86400000,expiresAfterMillis:14*86400000,cooldownMillis:7*86400000,listAcceptedIds:async()=>[],derive:()=>null,backupSuggestions:async()=>suggestions,
    resolveTarget:async(_tx,_org,s)=>({target:s.target,label:s.targetLabel,specialization:s.target.kind==='trainer'?'Strength':null,imageUrl:null,photoPath:null}),
    listIds:async()=>[...d].filter(([p])=>p.startsWith(root+'/canonicalRecommendations/')).map(([,r])=>String(r.id))};
  let calls=0;
  const deps:AdminAiDependencies={store,runtime,clock:()=>now,readAuthIdentity:async uid=>({uid,email:uid+'@example.com',emailVerified:true,disabled:false,tokensValidAfterMillis:0}),
    aiReader:{rows:async(path)=>[...d].filter(([p])=>p.startsWith(path+'/')&&!p.slice(path.length+1).includes('/')).map(([p,data])=>({id:p.split('/').at(-1)!,data}))},
    aiProvider:async request=>{calls++;return{providerSource:'mock_or_recorded',cacheHit:false,model:'fixture',latencyMillis:8,usage:{inputTokens:50,outputTokens:40,thinkingTokens:0,totalTokens:90},text:JSON.stringify({recommendations:(request.input.candidates as any[]).map(c=>({candidateId:c.id,message:'Review this beginner guidance.',evidenceKeys:['experience_match']}))})};}};
  const service=createAdminAiService(deps);
  const call=(op:string,data:Record<string,unknown>={})=>service.execute(admin,'gainpath','admin.ai.'+op,{schemaVersion:1,organizationId:'gainpath',...data});
  return{deps,d,store,suggestions,call,calls:()=>calls};
}
