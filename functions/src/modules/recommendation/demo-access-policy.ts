import {DomainError} from '../../platform/errors';
import type {DocumentData,DocumentStore,TransactionPort} from '../../platform/firestore/store';
import {digestOf,keys,object} from '../workouts/workout-backup-validation';
import type {ReviewedConsentNoticePolicy} from './recommendation-consent-v2';
import {dateGrid,localDate,plusDate} from '../coaching/coach-availability-contracts';
import {keyOf} from '../../platform/idempotency';

export const MODULE13_DEMO_DATABASE='module13-demo';
export const MODULE13_DEMO_MANIFEST='module13Demo/current';
export const DEMO_OPERATIONS=['session.access','admin.insights','admin.configuration.get','admin.configuration.save','admin.configuration.choices','admin.queue.refresh','admin.queue.list','admin.queue.detail','admin.queue.decide','admin.queue.status','member.consent.get','member.consent.set','member.consent.notice','member.recommendation.command','member.inbox','member.coach','member.routine','member.workoutHistory','delivery.process'] as const;
export type DemoOperation=typeof DEMO_OPERATIONS[number];
export type DemoActorRole='admin'|'member'|'coach';
export interface Module13DemoManifest {
 schemaVersion:1;seedId:string;projectId:string;databaseId:'module13-demo';organizationId:'gainpath';enabled:boolean;
 adminIds:string[];memberIds:string[];coachIds:string[];recordPaths:string[];recordDigests:Record<string,string>;mutablePaths:string[];
 noticePolicies:ReviewedConsentNoticePolicy[];policyIds:string[];inference:'structured_mock_only';createdAtMillis:number;
}
const fail=()=>new DomainError('permission-denied','The controlled Module13 demo is unavailable for this account or record.');
const id=(v:unknown):v is string=>typeof v==='string'&&/^[A-Za-z0-9_-]{1,128}$/.test(v);
const documentPath=(p:unknown):p is string=>typeof p==='string'&&p.length<=600&&p.split('/').length%2===0&&p.split('/').every(id);
export function parseModule13DemoManifest(raw:unknown,binding:{projectId:string;databaseId:string}):Module13DemoManifest{
 try{
  const m=object(raw);keys(m,['schemaVersion','seedId','projectId','databaseId','organizationId','enabled','adminIds','memberIds','coachIds','recordPaths','recordDigests','mutablePaths','noticePolicies','policyIds','inference','createdAtMillis']);
  if(m.schemaVersion!==1||!id(m.seedId)||m.projectId!==binding.projectId||m.databaseId!==MODULE13_DEMO_DATABASE||binding.databaseId!==MODULE13_DEMO_DATABASE||!['gainpath-0619','demo-gainpath-module13-demo'].includes(binding.projectId)||m.organizationId!=='gainpath'||m.enabled!==true||m.inference!=='structured_mock_only'||!Number.isSafeInteger(m.createdAtMillis)||Number(m.createdAtMillis)<0)throw fail();
  const identities:string[]=[];
  for(const name of ['adminIds','memberIds','coachIds']){const a=m[name];if(!Array.isArray(a)||a.length>30||a.some(v=>!id(v)||!v.startsWith('demo-m13-')))throw fail();identities.push(...a);}
  if(new Set(identities).size!==identities.length||!(m.adminIds as unknown[]).length)throw fail();
  for(const name of ['recordPaths','mutablePaths']){const a=m[name];if(!Array.isArray(a)||a.length>2000||a.some(v=>!documentPath(v))||new Set(a).size!==a.length)throw fail();}
  const paths=m.recordPaths as string[],mutable=m.mutablePaths as string[],digests=object(m.recordDigests);
  if(paths.includes(MODULE13_DEMO_MANIFEST)||paths.some(p=>p.startsWith('module13DemoOwnership/'))||mutable.some(p=>!paths.includes(p))||Object.keys(digests).length!==paths.length||paths.some(p=>typeof digests[p]!=='string'||!/^[a-f0-9]{64}$/.test(String(digests[p]))))throw fail();
  if(!Array.isArray(m.noticePolicies)||m.noticePolicies.length>10||!Array.isArray(m.policyIds)||m.policyIds.length>30||m.policyIds.some(v=>!id(v))||Buffer.byteLength(JSON.stringify(m))>800000)throw fail();
  return structuredClone(m) as unknown as Module13DemoManifest;
 }catch{throw fail();}
}
export function authorizeModule13DemoActor(m:Module13DemoManifest,uid:string,operation:DemoOperation):DemoActorRole{
 const role=m.adminIds.includes(uid)?'admin':m.memberIds.includes(uid)?'member':m.coachIds.includes(uid)?'coach':null;
 if(!role||!DEMO_OPERATIONS.includes(operation)||operation.startsWith('admin.')&&role!=='admin'||operation.startsWith('member.')&&role!=='member'||operation==='delivery.process'&&role!=='admin')throw fail();
 return role;
}
const RUNTIME=new Set(['recommendationConfiguration','recommendationConfigurationAudits','recommendationConfigurationAudit','recommendationConfigurationReceipts','recommendationConsent','recommendationConsentAudits','recommendationConsentAudit','recommendationConsentReceipts','recommendationLeads','recommendationRuns','recommendationRefreshLocks','recommendationRefreshAudits','recommendationGenerationState','recommendationEvidenceBindings','recommendationDecisionAudits','recommendationCommandReceipts','recommendationRecipients','recommendationDeliveryReceipts','recommendationMemberCommandReceipts','notifications']);
function runtimePath(p:string):boolean{const a=p.split('/');return a[0]==='orgs'&&a[1]==='gainpath'&&RUNTIME.has(a[2])&&(a.length===4||a.length===6&&a[2]==='recommendationRuns'&&a[4]==='pages')&&a.every(id);}
export const demoOwnershipPath=(p:string)=>`module13DemoOwnership/${digestOf(p)}`;
/** All service I/O remains inside the dedicated database. The manifest is re-read
 * in every transaction. Buffered mutations allow ownership/collision checks before
 * any write, including audit paths that the leaf service did not previously read. */
export function createOwnedDemoStore(inner:DocumentStore,manifest:Module13DemoManifest):DocumentStore{
 const frozen=structuredClone(manifest),fingerprint=digestOf(frozen),base=new Set(frozen.recordPaths),mutable=new Set(frozen.mutablePaths);
 // The booking validator must observe absence of unreserved slots. Authorize
 // only exact server-derived Coach/day keys; existing unowned locks still refuse.
 const day=plusDate(localDate(frozen.createdAtMillis,'Asia/Kuala_Lumpur'),1);
 const absentLocks=new Set(frozen.coachIds.flatMap(uid=>dateGrid(day,'Asia/Kuala_Lumpur').slots.map(at=>`orgs/gainpath/slotLocks/${keyOf(uid,at)}`)));
 return{transact:<T>(work:(tx:TransactionPort)=>Promise<T>)=>inner.transact(async raw=>{
  if(digestOf(await raw.get(MODULE13_DEMO_MANIFEST))!==fingerprint)throw new DomainError('aborted','Demo access policy changed.');
  const cache=new Map<string,DocumentData|undefined>(),writes=new Map<string,{create:boolean;data:object}>();
  async function ownedRead(p:string):Promise<DocumentData|undefined>{
   if(!documentPath(p)||!base.has(p)&&!runtimePath(p)&&!absentLocks.has(p))throw fail();
   if(cache.has(p))return cache.get(p);
   const data=await raw.get(p);
   if(data){
    if(base.has(p)){if(!mutable.has(p)&&digestOf(data)!==frozen.recordDigests[p])throw new DomainError('failed-precondition','A reviewed demo source changed.');}
    else{const ownership=await raw.get(demoOwnershipPath(p));if(ownership?.schemaVersion!==1||ownership.seedId!==frozen.seedId||ownership.path!==p)throw fail();}
   }
   cache.set(p,data);return data;
  }
  const tx:TransactionPort={get:ownedRead,getAll:paths=>Promise.all(paths.map(ownedRead)),create:(p,data)=>{if(writes.has(p))throw fail();writes.set(p,{create:true,data:structuredClone(data)});},set:(p,data)=>{writes.set(p,{create:false,data:structuredClone(data)});}};
  const result=await work(tx);
  if(writes.size>60)throw new DomainError('resource-exhausted','Demo command exceeds its bounded write limit.');
  const ownerships:{path:string;missing:boolean}[]=[];
  for(const[p,w]of writes){
   if(!runtimePath(p)||base.has(p)&&!mutable.has(p))throw fail();
   const before=await ownedRead(p);if(w.create&&before)throw new DomainError('aborted','Demo record already exists.');
   const ownership=await raw.get(demoOwnershipPath(p));if(ownership&&(ownership.schemaVersion!==1||ownership.seedId!==frozen.seedId||ownership.path!==p))throw fail();
   ownerships.push({path:p,missing:!ownership});
  }
  for(const o of ownerships)if(o.missing)raw.create(demoOwnershipPath(o.path),{schemaVersion:1,seedId:frozen.seedId,path:o.path});
  for(const[p,w]of writes)if(w.create)raw.create(p,w.data);else raw.set(p,w.data);
  return result;
 })};
}
