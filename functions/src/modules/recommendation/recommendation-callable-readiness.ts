import {Firestore} from 'firebase-admin/firestore';
import {DomainError} from '../../platform/errors';
import type {InsightsRequest,ExerciseInsightsQuery} from './exercise-insights-contracts';
import type {RecommendationConfiguration} from './recommendation-configuration';
import {recommendationCommandError} from './recommendation-configuration';
import type {RecommendationConsentV2,RecommendationConsentReceipt,RecommendationPurpose} from './recommendation-consent-v2';
import type {RecommendationQueueQuery,RecommendationQueuePage,RecommendationLead,RecommendationDecisionReceipt,QueueGenerationSummary} from './recommendation-queue-contracts';
import type {MemberRecommendationDetail,RecommendationDeliveryReceipt} from './recommendation-member-contracts';
import type {projectExerciseInsights} from './exercise-insights-presentation';

export const RECOMMENDATION_CALLABLE_OPERATIONS=['admin.insights','admin.configuration.get','admin.configuration.save','admin.queue.refresh','admin.queue.list','admin.queue.detail','admin.queue.decide','admin.queue.status','member.consent.get','member.consent.set','member.recommendation.command','delivery.process'] as const;
export type RecommendationCallableOperation=typeof RECOMMENDATION_CALLABLE_OPERATIONS[number];
type Scope={schemaVersion:1;organizationId:string};
type V2Scope={schemaVersion:2;organizationId:string};
type Generation={schemaVersion:1;mode:'synthetic_local';organizationId:string;summary:QueueGenerationSummary};
export interface RecommendationCallableRequests{
 'admin.insights':ExerciseInsightsQuery;
 'admin.configuration.get':Scope;
 'admin.configuration.save':Scope&{commandId:string;expectedRevision:number;policyIds:string[]};
 'admin.queue.refresh':Scope&{kind:'trainer'|'content';commandId:string;continuation:string|null};
 'admin.queue.list':RecommendationQueueQuery;
 'admin.queue.detail':Scope&{leadId:string};
 'admin.queue.decide':Scope&{leadId:string;commandId:string;expectedRevision:number;action:'send'|'dismiss';reason:string|null};
 'admin.queue.status':Scope&{runId:string};
 'member.consent.get':V2Scope;
 'member.consent.set':V2Scope&{commandId:string;expectedRevision:number;purpose:RecommendationPurpose}&({action:'revoke'}|{action:'grant';noticePolicyId:string;acceptedNoticeVersion:string;acceptedContentVersion:string});
 'member.recommendation.command':Scope&{recommendationId:string;action:'get'|'resolve'|'read'|'acknowledge'|'dismiss';commandId:string|null;expectedRevision:number|null};
 'delivery.process':Scope&{recommendationId:string};
}
export interface RecommendationCallableResponses{
 'admin.insights':ReturnType<typeof projectExerciseInsights>;
 'admin.configuration.get':RecommendationConfiguration;
 'admin.configuration.save':RecommendationConfiguration;
 'admin.queue.refresh':Generation;
 'admin.queue.list':RecommendationQueuePage;
 'admin.queue.detail':{schemaVersion:1;mode:'synthetic_local';organizationId:string;lead:RecommendationLead};
 'admin.queue.decide':RecommendationDecisionReceipt;
 'admin.queue.status':Generation;
 'member.consent.get':RecommendationConsentV2|null;
 'member.consent.set':RecommendationConsentReceipt;
 'member.recommendation.command':MemberRecommendationDetail;
 'delivery.process':RecommendationDeliveryReceipt;
}
export type RecommendationCallableHandlers={readonly[K in RecommendationCallableOperation]:(request:InsightsRequest)=>Promise<RecommendationCallableResponses[K]>};
/** Readiness metadata only. No onCall/export registration occurs in this module. */
export const RECOMMENDATION_CALLABLE_RELEASE=Object.freeze({schemaVersion:1,enforceAppCheck:true,productionRegistered:false,requestBytes:16384,responseBytes:262144,requiredGates:['capture_scope','purpose_notice','evidence_policy','catalog_curation','disclosure','retention','release_uat'] as const});
const bindings=new WeakMap<object,Firestore>();
export interface RecommendationEmulatorCapability{readonly __localCapability?:never}
function checkBinding(db:Firestore):void{
 const s=(db as unknown as {_settings:Record<string,unknown>})._settings;
 if(!(db instanceof Firestore)||process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:18115'||process.env.GCLOUD_PROJECT!=='demo-gainpath-module13-e'||process.env.GOOGLE_CLOUD_PROJECT!=='demo-gainpath-module13-e'||(db as unknown as {projectId:unknown}).projectId!=='demo-gainpath-module13-e'||s.servicePath!=='127.0.0.1'||s.port!==18115||s.ssl!==false)throw new DomainError('failed-precondition','Explicit isolated recommendation emulator is required.');
}
/** A request flag, copied object or serializable fixture ID cannot mint this authority. */
export function mintRecommendationEmulatorCapability(db:Firestore):RecommendationEmulatorCapability{
 checkBinding(db);const capability=Object.freeze({});bindings.set(capability,db);return capability;
}
/** Validates test transport metadata only. It never invokes a source or handler.
 * The test-only fixed composition must construct every store/reader from the same
 * SDK instance. Production wrappers cannot turn this into an execution grant. */
export function validateRecommendationEmulatorRequest(capability:RecommendationEmulatorCapability,operation:RecommendationCallableOperation,request:InsightsRequest):void{
 try{
  const db=bindings.get(capability);if(!db)throw new DomainError('failed-precondition','Invalid local capability.');checkBinding(db);
  if(!RECOMMENDATION_CALLABLE_OPERATIONS.includes(operation)||!request.app?.appId||!request.auth)throw new DomainError('unauthenticated','Verified sign-in and App Check are required.');
  const size=Buffer.byteLength(JSON.stringify(request.data),'utf8');
  if(size>RECOMMENDATION_CALLABLE_RELEASE.requestBytes||!request.data||typeof request.data!=='object'||Array.isArray(request.data))throw new DomainError('invalid-argument','Invalid bounded recommendation request.');
  const data=request.data as Record<string,unknown>;
  if(data.organizationId!=='synthetic-org'||['mode','fixtureSetId','enabled','localFixture','localDelivery','capability'].some(k=>Object.hasOwn(data,k)))throw new DomainError('invalid-argument','Invalid recommendation scope or activation field.');
 }catch(error){throw recommendationCommandError(error);}
}
/** Permanent release barrier in this checkpoint. An injected handler, real local
 * capability, client flag or environment change cannot execute a production source.
 * Future activation requires a separately reviewed implementation/registration. */
export function createRecommendationCallableFacade(_unapprovedComposition?:unknown){
 return async<K extends RecommendationCallableOperation>(_operation:K,_request:InsightsRequest):Promise<RecommendationCallableResponses[K]>=>{
  throw new DomainError('failed-precondition','Production recommendation APIs are not registered.');
 };
}