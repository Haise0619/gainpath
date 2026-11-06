import {getApp} from 'firebase-admin/app';
import {getAuth,type Auth} from 'firebase-admin/auth';
import {getFirestore,type Firestore} from 'firebase-admin/firestore';
import {onCall,HttpsError,type CallableRequest} from 'firebase-functions/v2/https';
import {DomainError} from '../../platform/errors';
import {requireActiveMembership} from '../../platform/auth-context';
import {FirestoreStore} from '../../platform/firestore/firestore-store';
import {keys,object} from '../workouts/workout-backup-validation';
import {module9MemberCommand} from '../coaching/module9-member-service';
import type {FreshAuthIdentity,InsightsRequest} from './exercise-insights-contracts';
import {authorizeRecommendationSession,createRecommendationConfigurationCommand,recommendationCommandError} from './recommendation-configuration';
import {createRecommendationConsentV2Command} from './recommendation-consent-v2';
import {createRecommendationQueueGeneration} from './recommendation-queue-generation';
import {createRecommendationQueueList} from './recommendation-queue-reader';
import {createRecommendationLeadDecision} from './recommendation-lead-decisions';
import {createRecommendationDelivery} from './recommendation-delivery';
import {createMemberRecommendationService,requireRecommendationMember} from './recommendation-member-service';
import {createRecommendationReadServices} from './recommendation-read-services';
import {createRecommendationNoticeProjector} from './module9-recommendation-projection';
import {requireQueueAdmin} from './recommendation-queue-security';
import {mintDemoRuntimeCapability} from './demo-runtime-capability';
import {createModule13DemoDataAdapters} from './demo-firestore-adapters';
import {DEMO_OPERATIONS,MODULE13_DEMO_DATABASE,MODULE13_DEMO_MANIFEST,parseModule13DemoManifest,authorizeModule13DemoActor,createOwnedDemoStore,type DemoOperation} from './demo-access-policy';

export const MODULE13_DEMO_CALLABLE_OPTIONS=Object.freeze({region:'asia-southeast1',enforceAppCheck:true,timeoutSeconds:540,maxInstances:1,concurrency:4} as const);
export const MODULE13_DEMO_DEPLOYMENT_ALLOWLIST=['module13DemoAdminCommand','module13DemoMemberCommand','module13DemoDeliveryCommand'] as const;
export type DemoCallableGroup='admin'|'member'|'delivery';
export function parseModule13DemoEnvelope(raw:unknown,group:DemoCallableGroup):{operation:DemoOperation;data:unknown}{
 const e=object(raw);keys(e,['schemaVersion','operation','data']);
 if(e.schemaVersion!==1||!DEMO_OPERATIONS.includes(e.operation as DemoOperation)||Buffer.byteLength(JSON.stringify(e))>16384)throw new DomainError('invalid-argument','Invalid bounded demo command.');
 const operation=e.operation as DemoOperation;
 if(operation!=='session.access'&&(group==='admin'?!operation.startsWith('admin.'):group==='member'?!operation.startsWith('member.'):operation!=='delivery.process')||group==='delivery'&&operation==='session.access')throw new DomainError('permission-denied','This operation is unavailable on this demo endpoint.');
 const data=object(e.data);if(data.organizationId!=='gainpath'||['demoMode','fixtureSetId','localFixture','localDelivery','enabled','capability','projectId','databaseId'].some(k=>Object.hasOwn(data,k)))throw new DomainError('invalid-argument','Invalid demo request scope.');
 return{operation,data};
}
/** This composition never reads the default database. Its unregistered caller can
 * be exercised against emulators; live reachability requires the exact approved
 * three-export entrypoint plus an enabled server-owned named-database manifest. */
export function createModule13DemoBackend(options:{db:Firestore;auth:Pick<Auth,'getUser'>;clock?:()=>number}){
 const{db,auth}=options,clock=options.clock??Date.now,capability=mintDemoRuntimeCapability(db),base=new FirestoreStore(db);
 const binding={projectId:(db as unknown as {projectId:string}).projectId,databaseId:db.databaseId};
 return async(group:DemoCallableGroup,incoming:InsightsRequest):Promise<unknown>=>{
  try{
   const envelope=parseModule13DemoEnvelope(incoming.data,group);
   if(!incoming.auth||!incoming.app?.appId)throw new DomainError('unauthenticated','Verified Firebase Auth and App Check are required.');
   const manifest=parseModule13DemoManifest((await db.doc(MODULE13_DEMO_MANIFEST).get()).data(),binding);
   const role=authorizeModule13DemoActor(manifest,incoming.auth.uid,envelope.operation),store=createOwnedDemoStore(base,manifest);
   const readAuthIdentity=async(uid:string):Promise<FreshAuthIdentity>=>{
    if(![...manifest.adminIds,...manifest.memberIds,...manifest.coachIds].includes(uid))throw new DomainError('permission-denied','Approved demo identity required.');
    const u=await auth.getUser(uid),validAfter=u.tokensValidAfterTime?Date.parse(u.tokensValidAfterTime):0;
    return{uid:u.uid,email:u.email??'',emailVerified:u.emailVerified,disabled:u.disabled,tokensValidAfterMillis:validAfter};
   };
   const deps={store,clock,readAuthIdentity,demoCapability:capability,noticePolicies:manifest.noticePolicies};
   const request:InsightsRequest={...incoming,data:envelope.data},actor=await authorizeRecommendationSession(request,deps);
   await store.transact(async tx=>{
    if(role==='admin')await requireQueueAdmin(tx,actor,'gainpath');else if(role==='member')await requireRecommendationMember(tx,actor,'gainpath');else{const u=await tx.get(`users/${actor.uid}`),m=await tx.get(`orgs/gainpath/members/${actor.uid}`);if(u?.organizationId!=='gainpath'||m?.role!=='coach'||requireActiveMembership(m).role!=='coach')throw new DomainError('permission-denied','Current demo Coach identity required.');}
   });
   if(envelope.operation==='session.access')return{schemaVersion:1,projectId:binding.projectId,databaseId:binding.databaseId,organizationId:'gainpath',seedId:manifest.seedId,role,demoData:true,enabled:true};
   const adapters=await createModule13DemoDataAdapters({db,manifest,store,deps,readAuthIdentity,clock}),deliveryDeps={...deps,resolveTarget:adapters.resolveTarget},reads=createRecommendationReadServices({...deliveryDeps,validateTarget:adapters.validateTarget});
   let result:unknown;
   switch(envelope.operation){
    case'admin.insights':result=await adapters.insights(request);break;
    case'admin.configuration.get':result=await reads.configuration(request);break;
    case'admin.configuration.save':result=await createRecommendationConfigurationCommand({...deps,reviewedPolicies:adapters.reviewedPolicies})(request);break;
    case'admin.configuration.choices':{
     const config=await reads.configuration(request);result={schemaVersion:1,organizationId:'gainpath',revision:config.revision,selectedPolicyIds:config.policies.map(p=>p.policyId),availablePolicies:adapters.reviewedPolicies.map(p=>({policyId:p.policyId,title:`Demo educational ${p.compatibility.exerciseId} (${p.compatibility.mode})`,definition:'Synthetic educational evidence policy restricted to the approved fictional demo identities; not a production or clinical threshold.'}))};break;
    }
    case'admin.queue.refresh':result=await createRecommendationQueueGeneration({...deps,source:adapters.queueSource})(request);break;
    case'admin.queue.list':result=await createRecommendationQueueList({...deps,reader:adapters.queueReader})(request);break;
    case'admin.queue.detail':result=await reads.lead(request);break;
    case'admin.queue.decide':result=await createRecommendationLeadDecision({...deps,validateTarget:adapters.validateTarget})(request);break;
    case'admin.queue.status':result=await reads.status(request);break;
    case'member.consent.get':result=await reads.consent(request);break;
    case'member.consent.set':result=await createRecommendationConsentV2Command(deps)(request);break;
    case'member.consent.notice':{
     const q=object(request.data);keys(q,['schemaVersion','organizationId']);if(q.schemaVersion!==1)throw new DomainError('invalid-argument','Invalid notice request.');const n=manifest.noticePolicies[0];if(!n)throw new DomainError('failed-precondition','No reviewed demo notice is available.');
     result={schemaVersion:1,organizationId:'gainpath',policyId:n.policyId,noticeVersion:n.noticeVersion,contentVersion:n.contentVersion,historyDescription:'Only fictional workout records explicitly owned by this controlled demonstration may be used. These grants do not authorize real Member history processing.',demoData:true};break;
    }
    case'member.recommendation.command':result=await createMemberRecommendationService(deliveryDeps)(request);break;
    case'delivery.process':result=await createRecommendationDelivery(deliveryDeps)(request);break;
    case'member.inbox':{
     const q=object(request.data);keys(q,['schemaVersion','organizationId','afterId'],['schemaVersion','organizationId']);if(q.schemaVersion!==1)throw new DomainError('invalid-argument','Invalid inbox request.');
     result=await module9MemberCommand(store,actor,{...q,action:'inbox'},clock,{...adapters.inboxReader,projectRecommendation:await createRecommendationNoticeProjector(deliveryDeps,request)});break;
    }
    case'member.coach':case'member.routine':{
     const q=object(request.data),isCoach=envelope.operation==='member.coach',field=isCoach?'coachId':'routineId';keys(q,['schemaVersion','organizationId',field]);if(q.schemaVersion!==1||typeof q[field]!=='string'||!(isCoach?manifest.coachIds:adapters.source.publicationIds).includes(String(q[field])))throw new DomainError('permission-denied','Reviewed demo destination required.');
     const p=`orgs/gainpath/${isCoach?'coaches':'content'}/${q[field]}`;
     result=await store.transact(async tx=>{await requireRecommendationMember(tx,actor,'gainpath');const d=await tx.get(p);if(!d||d.status!=='published'||d.archived===true||d.isActive===false)throw new DomainError('failed-precondition','Current demo destination is unavailable.');return d;});break;
    }
    case'member.workoutHistory':result=await adapters.workoutHistory(request);break;
   }
   if(Buffer.byteLength(JSON.stringify(result??null))>262144)throw new DomainError('resource-exhausted','Demo response exceeds its bounded size.');
   await authorizeRecommendationSession(request,deps);await store.transact(async()=>undefined);
   return result;
  }catch(error){throw recommendationCommandError(error);}
 };
}
function callable(group:DemoCallableGroup){return onCall(MODULE13_DEMO_CALLABLE_OPTIONS,async(request:CallableRequest<unknown>)=>{
 try{
  const app=getApp(),db=getFirestore(app,MODULE13_DEMO_DATABASE),auth=getAuth(app);
  return await createModule13DemoBackend({db,auth})(group,{app:request.app?{appId:request.app.appId}:undefined,auth:request.auth?{uid:request.auth.uid,token:request.auth.token}:undefined,data:request.data});
 }catch(error){const safe=recommendationCommandError(error);throw new HttpsError(safe.code,safe.message);}
});}
export const module13DemoAdminCommand=callable('admin');
export const module13DemoMemberCommand=callable('member');
export const module13DemoDeliveryCommand=callable('delivery');
