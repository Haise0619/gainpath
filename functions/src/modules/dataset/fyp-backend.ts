/** Local default-database composition. Not exported by the production entrypoint. */
import {Firestore,FieldPath} from 'firebase-admin/firestore';
import type {Auth} from 'firebase-admin/auth';
import {DomainError} from '../../platform/errors';
import {FirestoreStore} from '../../platform/firestore/firestore-store';
import type {DocumentData} from '../../platform/firestore/store';
import {digestOf,keys,object} from '../workouts/workout-backup-validation';
import {resolveFypScope,resolveFypAdminReadScope,createFypScopedStore,mintFypRuntimeCapability,FYP_SCOPE_ROOT,type FypIdentity} from './fyp-scope';
import type {FreshAuthIdentity,InsightsRequest} from '../recommendation/exercise-insights-contracts';
import {createFypEvidenceReader} from './fyp-evidence-reader';
import {fypModuleRead} from './fyp-module-services';
import {assertFypRuntimeRelease,revalidateFypRuntimeRelease,type FypRuntimeReleaseGrant} from './fyp-runtime-release';
import {adminWorkoutReport} from '../analytics/admin-workout-reporting';
import {createModule13DemoDataAdapters} from '../recommendation/demo-firestore-adapters';
import {createRecommendationConfigurationCommand,recommendationCommandError} from '../recommendation/recommendation-configuration';
import {createRecommendationConsentV2Command,type ReviewedConsentNoticePolicy} from '../recommendation/recommendation-consent-v2';
import {createRecommendationQueueGeneration} from '../recommendation/recommendation-queue-generation';
import {createRecommendationQueueList} from '../recommendation/recommendation-queue-reader';
import {createRecommendationLeadDecision} from '../recommendation/recommendation-lead-decisions';
import {createRecommendationDelivery} from '../recommendation/recommendation-delivery';
import {createMemberRecommendationService} from '../recommendation/recommendation-member-service';
import {createRecommendationReadServices} from '../recommendation/recommendation-read-services';
import {createRecommendationNoticeProjector} from '../recommendation/module9-recommendation-projection';
import {module9MemberCommand} from '../coaching/module9-member-service';
const modules=['getCoachRatingsCommand','getMemberBookingOptionsCommand','getCoachAvailabilityCommand','getCoachRosterCommand','getBookingListCommand','module9MemberCommandCallable','adminReportingCommand','adminWorkoutReportingCommand','adminCheckInReportingCommand','workoutProgramCommand','getCoachCertificationsCommand','getCoachPublishedPhotoCommand'];
const operations=new Set(['admin.insights','admin.configuration.get','admin.configuration.save','admin.configuration.choices','admin.queue.refresh','admin.queue.list','admin.queue.detail','admin.queue.decide','admin.queue.status','member.history','member.workoutHistory','member.consent.get','member.consent.set','member.consent.notice','member.recommendation.command','member.inbox','member.coach','member.routine','delivery.process',...modules.map(n=>`module/${n}`)]);
export function parseFypEnvelope(raw:unknown):{operation:string;data:DocumentData}{
  const q=object(raw);keys(q,['schemaVersion','operation','data']);
  if(q.schemaVersion!==1||!operations.has(String(q.operation))||Buffer.byteLength(JSON.stringify(q))>16384)throw new DomainError('invalid-argument','Unsupported bounded dataset command.');
  const data=object(q.data);
  if(['cohortId','datasetId','demoMode','role','projectId','databaseId','rootPath','capability','enabled'].some(k=>Object.hasOwn(data,k))||data.organizationId!==undefined&&data.organizationId!=='gainpath')throw new DomainError('invalid-argument','A command cannot select its data scope.');
  return{operation:String(q.operation),data};
}
function guard(db:Firestore,release?:FypRuntimeReleaseGrant){
  if(release){assertFypRuntimeRelease(release,db);return;}
  const s=(db as Firestore&{_settings?:{servicePath?:unknown;port?:unknown;ssl?:unknown}})._settings;
  if(!(db instanceof Firestore)||(db as unknown as {projectId:string}).projectId!=='demo-gainpath-fyp'||db.databaseId!=='(default)'||process.env.GCLOUD_PROJECT!=='demo-gainpath-fyp'||process.env.GOOGLE_CLOUD_PROJECT!=='demo-gainpath-fyp'||process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:18231'||process.env.FIREBASE_AUTH_EMULATOR_HOST!=='127.0.0.1:19131'||s?.servicePath!=='127.0.0.1'||s.port!==18231||s.ssl!==false)throw new DomainError('failed-precondition','Dedicated default-database FYP emulator composition required.');
}
const deny=()=>new DomainError('permission-denied','This operation is unavailable for your current dataset role.');
const adminReads=new Set(['admin.insights','admin.configuration.get','admin.configuration.choices','admin.queue.list','admin.queue.detail','admin.queue.status','module/adminReportingCommand','module/adminWorkoutReportingCommand','module/adminCheckInReportingCommand','module/workoutProgramCommand','module/getCoachAvailabilityCommand','module/getCoachRosterCommand','module/getCoachRatingsCommand','module/getCoachCertificationsCommand','module/getCoachPublishedPhotoCommand','module/getBookingListCommand']);
export function assertFypAdminReadOperation(operation:string):void {if(!adminReads.has(operation))throw deny();}
function logical(path:string){
  if(path===FYP_SCOPE_ROOT)return'orgs/gainpath';
  if(!path.startsWith(FYP_SCOPE_ROOT+'/'))throw deny();
  const suffix=path.slice(FYP_SCOPE_ROOT.length+1);
  return suffix.startsWith('users/')||suffix.startsWith('module13DemoSource/')?suffix:`orgs/gainpath/${suffix}`;
}
export function createFypDatasetBackend(options:{db:Firestore;auth:Pick<Auth,'getUser'>;clock?:()=>number;release?:FypRuntimeReleaseGrant;canonicalAdminRead?:true}){
  const{db,auth,release}=options;guard(db,release);const clock=options.clock??Date.now,base=new FirestoreStore(db);
  const identity=async(uid:string):Promise<FypIdentity>=>{
    const u=await auth.getUser(uid),validAfter=u.tokensValidAfterTime?Date.parse(u.tokensValidAfterTime):0;
    if(!options.canonicalAdminRead&&(u.customClaims?.fypAuthCreatedAtMillis!==Date.parse(u.metadata.creationTime)||Object.keys(u.customClaims).some(k=>k!=='fypAuthCreatedAtMillis')))throw deny();
    return{uid:u.uid,email:u.email??'',emailVerified:u.emailVerified,disabled:u.disabled,creationTimeMillis:Date.parse(u.metadata.creationTime),tokensValidAfterMillis:validAfter};
  };
  async function context(incoming:InsightsRequest){
    guard(db,release);if(release)assertFypRuntimeRelease(release,db,options.canonicalAdminRead?undefined:incoming.auth?.uid);
    const sessionRequest={...incoming,data:{schemaVersion:1}},resolve=options.canonicalAdminRead?resolveFypAdminReadScope:resolveFypScope,scope=await resolve(sessionRequest,{store:base,identity,clock});
    const store=createFypScopedStore(base,scope),fypCapability=mintFypRuntimeCapability(scope);
    const seed=await store.transact(tx=>tx.get(`orgs/gainpath/seedRuns/${scope.seedId}`));
    if(!seed||seed.schemaVersion!==1||seed.seedId!==scope.seedId||seed.status!=='complete'||typeof seed.planDigest!=='string')throw new DomainError('failed-precondition','The dataset has not completed verified provisioning.');
    if(release)assertFypRuntimeRelease(release,db,options.canonicalAdminRead?undefined:scope.uid,seed.planDigest);
    const readAuthIdentity=async(uid:string):Promise<FreshAuthIdentity&{creationTimeMillis:number}>=>{
      if(options.canonicalAdminRead&&uid===scope.uid)return identity(uid);
      const a=(await db.doc(`datasetAssignments/${uid}`).get()).data();
      if(!a||a.schemaVersion!==1||a.datasetId!==scope.datasetId||a.seedId!==scope.seedId||a.organizationId!==scope.organizationId||a.enabled!==true)throw deny();
      const current=await identity(uid);if(current.creationTimeMillis!==a.authCreatedAtMillis)throw deny();
      if(options.canonicalAdminRead){const u=await auth.getUser(uid);if(u.customClaims?.fypAuthCreatedAtMillis!==current.creationTimeMillis||Object.keys(u.customClaims).some(k=>k!=='fypAuthCreatedAtMillis'))throw deny();}
      if(uid===scope.uid&&(current.disabled||!current.emailVerified||current.email!==incoming.auth?.token.email||incoming.auth.token.fypAuthCreatedAtMillis!==current.creationTimeMillis||Number(incoming.auth.token.auth_time)*1000<current.tokensValidAfterMillis))throw deny();
      return current;
    };
    const finalize=async<T>(value:T):Promise<T>=>{
      if(release)await revalidateFypRuntimeRelease(release,db);
      const fresh=await resolve(sessionRequest,{store:base,identity,clock});
      if(fresh.assignmentFingerprint!==scope.assignmentFingerprint||fresh.membershipFingerprint!==scope.membershipFingerprint)throw new DomainError('aborted','Your dataset session changed.');
      const latest=await store.transact(tx=>tx.get(`orgs/gainpath/seedRuns/${scope.seedId}`));if(latest?.status!=='complete'||latest.planDigest!==seed.planDigest)throw new DomainError('aborted','Dataset provisioning changed.');
      if(Buffer.byteLength(JSON.stringify(value??null))>262144)throw new DomainError('resource-exhausted','Dataset response exceeds its bounded size.');return value;
    };
    return{scope,store,fypCapability,readAuthIdentity,finalize};
  }
  return{
    adminReadContext:async(incoming:InsightsRequest)=>{if(!options.canonicalAdminRead)throw deny();return context(incoming);},
    session:async(incoming:InsightsRequest)=>{
      if(options.canonicalAdminRead)throw deny();
      try{const q=object(incoming.data);keys(q,['schemaVersion']);if(q.schemaVersion!==1)throw deny();const c=await context(incoming);
        const[user,member]=await c.store.transact(async tx=>Promise.all([tx.get(`users/${c.scope.uid}`),tx.get(`orgs/gainpath/members/${c.scope.uid}`)]));
        return await c.finalize({schemaVersion:1,organizationId:c.scope.organizationId,datasetId:c.scope.datasetId,seedId:c.scope.seedId,role:c.scope.role,branchIds:c.scope.branchIds,revision:c.scope.revision,rootPath:c.scope.rootPath,fictional:true,user,member});
      }catch(e){throw recommendationCommandError(e);}
    },
    command:async(incoming:InsightsRequest):Promise<unknown>=>{
      try{
        const e=parseFypEnvelope(incoming.data);if(options.canonicalAdminRead)assertFypAdminReadOperation(e.operation);
        const c=await context(incoming),{scope,store,fypCapability,readAuthIdentity,finalize}=c;
        if((e.operation.startsWith('admin.')||e.operation==='delivery.process')&&scope.role!=='admin'||e.operation.startsWith('member.')&&scope.role!=='member')throw deny();
        const request:InsightsRequest={...incoming,data:{...e.data,organizationId:scope.organizationId}};
        const genericDeps={db,scope,store,clock,readAuthIdentity,fypCapability};
        if(e.operation.startsWith('module/')&&!['module/adminWorkoutReportingCommand','module/module9MemberCommandCallable'].includes(e.operation))return await finalize(await fypModuleRead(e.operation,request,genericDeps));
        const {source,run}=await store.transact(async tx=>({source:await tx.get('module13DemoSource/current'),run:await tx.get(`orgs/gainpath/seedRuns/${scope.seedId}`)}));
        if(!source||source.schemaVersion!==1||source.seedId!==scope.seedId||source.rootPath!==scope.rootPath||!run||run.status!=='complete'||run.seedId!==scope.seedId||!Array.isArray(run.sourcePaths)||run.sourcePaths.length>1000||!Array.isArray(source.members)||source.members.length>20||!Array.isArray(source.noticePolicies))throw new DomainError('failed-precondition','The current dataset source requires review.');
        const noticePolicies=source.noticePolicies as unknown as ReviewedConsentNoticePolicy[];
        const deps={store,clock,readAuthIdentity,fypCapability,noticePolicies};
        const evidence=createFypEvidenceReader({...genericDeps,source:source as unknown as Parameters<typeof createFypEvidenceReader>[0]['source'],noticePolicies});
        if(e.operation==='member.history'||e.operation==='member.workoutHistory')return await finalize(await evidence.history(request));
        if(e.operation==='module/adminWorkoutReportingCommand'){
          if(scope.role!=='admin')throw deny();
          const result=await adminWorkoutReport(store,incoming.auth,request.data,{members:async(after,limit)=>{
            let q=db.collection(`${scope.rootPath}/members`).orderBy(FieldPath.documentId()).limit(limit);if(after)q=q.startAfter(after);
            return(await q.get()).docs.map(d=>({id:d.id,data:d.data()}));
          },backups:async(uid,after,limit)=>(await evidence.rows(uid)).filter(r=>!after||r.id>after).slice(0,limit)},clock,fypCapability);
          return await finalize(result);
        }
        const memberIds=(source.members as {memberId:string}[]).map(m=>m.memberId),coachIds=source.coachIds as string[];
        const adapters=await createModule13DemoDataAdapters({db,queryRoot:scope.rootPath,manifest:{seedId:scope.seedId,memberIds,coachIds,recordPaths:(run.sourcePaths as string[]).map(logical),noticePolicies},store,deps,readAuthIdentity,clock,observations:evidence});
        const deliveryDeps={...deps,resolveTarget:adapters.resolveTarget},reads=createRecommendationReadServices({...deliveryDeps,validateTarget:adapters.validateTarget});
        let result:unknown;
        switch(e.operation){
          case'admin.insights':result=await adapters.insights(request);break;
          case'admin.configuration.get':result=await reads.configuration(request);break;
          case'admin.configuration.save':result=await createRecommendationConfigurationCommand({...deps,reviewedPolicies:adapters.reviewedPolicies})(request);break;
          case'admin.configuration.choices':{const config=await reads.configuration(request);result={schemaVersion:1,organizationId:'gainpath',revision:config.revision,selectedPolicyIds:config.policies.map(p=>p.policyId),availablePolicies:adapters.reviewedPolicies.map(p=>({policyId:p.policyId,title:`Fictional educational ${p.compatibility.exerciseId} (${p.compatibility.mode})`,definition:'Fictional-cohort educational evidence only; provisional and not a clinical risk threshold.'}))};break;}
          case'admin.queue.refresh':result=await createRecommendationQueueGeneration({...deps,source:adapters.queueSource})(request);break;
          case'admin.queue.list':result=await createRecommendationQueueList({...deps,reader:adapters.queueReader})(request);break;
          case'admin.queue.detail':result=await reads.lead(request);break;
          case'admin.queue.status':result=await reads.status(request);break;
          case'admin.queue.decide':{
            const receipt=await createRecommendationLeadDecision({...deps,validateTarget:adapters.validateTarget})(request);
            if(receipt.outcome==='prepared'&&receipt.recipientRecommendationId)await createRecommendationDelivery(deliveryDeps)({...request,data:{schemaVersion:1,organizationId:scope.organizationId,recommendationId:receipt.recipientRecommendationId}});
            result=receipt;break;
          }
          case'delivery.process':result=await createRecommendationDelivery(deliveryDeps)(request);break;
          case'member.consent.get':result=await reads.consent(request);break;
          case'member.consent.set':result=await createRecommendationConsentV2Command(deps)(request);break;
          case'member.consent.notice':{const q=object(request.data);keys(q,['schemaVersion','organizationId']);if(q.schemaVersion!==1||!noticePolicies[0])throw deny();const n=noticePolicies[0];result={schemaVersion:1,organizationId:scope.organizationId,policyId:n.policyId,noticeVersion:n.noticeVersion,contentVersion:n.contentVersion,historyDescription:'Only manifest-owned fictional synthetic observations in this FYP cohort are processed. Real Member histories are excluded.',demoData:true};break;}
          case'member.recommendation.command':result=await createMemberRecommendationService(deliveryDeps)(request);break;
          case'module/module9MemberCommandCallable':result=await fypModuleRead(e.operation,request,{...genericDeps,projectRecommendation:await createRecommendationNoticeProjector(deliveryDeps,request)});break;
          case'member.inbox':{const q=object(request.data);keys(q,['schemaVersion','organizationId','afterId'],['schemaVersion','organizationId']);result=await module9MemberCommand(store,incoming.auth,{...q,action:'inbox'},clock,{...adapters.inboxReader,projectRecommendation:await createRecommendationNoticeProjector(deliveryDeps,request)});break;}
          case'member.coach':case'member.routine':{const q=object(request.data),coach=e.operation==='member.coach',field=coach?'coachId':'routineId';keys(q,['schemaVersion','organizationId',field]);if(q.schemaVersion!==1||typeof q[field]!=='string'||!(coach?coachIds:source.publicationIds as string[]).includes(String(q[field])))throw deny();result=await store.transact(tx=>tx.get(`orgs/gainpath/${coach?'coaches':'content'}/${q[field]}`));if(!result||(result as DocumentData).status!=='published')throw deny();break;}
          default:throw deny();
        }
        return await finalize(result);
      }catch(e){throw recommendationCommandError(e);}
    },
  };
}
