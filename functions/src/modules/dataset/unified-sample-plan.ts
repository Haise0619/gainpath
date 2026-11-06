import {DomainError} from '../../platform/errors';
import type {DocumentStore} from '../../platform/firestore/store';
import {fypDigest} from './fyp-integrity';
import {buildUnifiedSampleBusiness,type SamplePlanReference} from './unified-sample-business';
import {UNIFIED_ADMIN_GATE} from './unified-admin-scope';
const issuedPlans=new WeakMap<object,string>();
function freeze<T>(value:T):T {if(value&&typeof value==='object'){for(const child of Object.values(value))freeze(child);Object.freeze(value);}return value;}
export function unifiedSamplePlan(input:Parameters<typeof buildUnifiedSampleBusiness>[0]){
 const rows=buildUnifiedSampleBusiness(input),root='orgs/gainpath/cohorts/fyp-v1',records:Record<string,object>={};
 for(const row of rows)records[`${root}/unifiedSampleBusiness/${row.id}`]=row;
 records[`${root}/unifiedSampleManifests/business-v1`]={schemaVersion:1,version:'unified-admin-business-v1',sourceManifestDigest:'cbca9c7b48b70d4dae6d5cb961eb11a07529f0a1a3a64c7b6581589dd545b405',anchorAtMillis:input.anchorAtMillis,rowDigests:Object.fromEntries(rows.map(r=>[r.id,fypDigest(r)]))};
 const gate={schemaVersion:1,organizationId:'gainpath',cohortId:'fyp-v1',rootPath:root,enabled:true,version:'unified-admin-v1'};
 const owned={...records,[UNIFIED_ADMIN_GATE]:gate};
 for(const[path,data]of Object.entries(owned))records[`${root}/unifiedSampleOwnership/${fypDigest(path)}`]={schemaVersion:1,seedId:'unified-admin-business-v1',path,digest:fypDigest(data)};
 // The grant is applied last by the operator after source/package validation.
 const plan=freeze({records,gate,gatePath:UNIFIED_ADMIN_GATE,planDigest:fypDigest({records,gate}),rowCount:rows.length});issuedPlans.set(plan,plan.planDigest);return plan;
}
/** Atomic bounded create-only application. Replays accept only exact owned bytes. */
export async function applyUnifiedSamplePlan(store:DocumentStore,plan:ReturnType<typeof unifiedSamplePlan>,activate:boolean){
 if(typeof activate!=='boolean'||issuedPlans.get(plan)!==plan.planDigest||fypDigest({records:plan.records,gate:plan.gate})!==plan.planDigest||Object.keys(plan.records).length>450)throw new DomainError('failed-precondition','Reviewed sample plan changed.');
 const entries=Object.entries({...plan.records,[plan.gatePath]:plan.gate});
 return store.transact(async tx=>{const current=await Promise.all(entries.map(([path])=>tx.get(path)));let created=0;
  const positions=new Map(entries.map(([path],i)=>[path,i]));
  if(!activate&&current[positions.get(plan.gatePath)!])throw new DomainError('already-exists','An Admin grant already occupies the activation path.');
  if(activate&&entries.some(([path],i)=>path!==plan.gatePath&&!current[i]))throw new DomainError('failed-precondition','The complete exact-owned projection must be staged before activation.');
  for(let i=0;i<entries.length;i++)if(current[i]&&fypDigest(current[i])!==fypDigest(entries[i][1]))throw new DomainError('already-exists','A changed or unowned projection occupies an exact target path.');
  for(let i=0;i<entries.length;i++)if(current[i]){
    const[path,value]=entries[i];
    if(path.includes('/unifiedSampleOwnership/')){
      const target=(value as {path:string}).path,targetIndex=positions.get(target);
      // The exact disabled-stage plan reserves only its future gate proof.
      if(target!==plan.gatePath&&(targetIndex===undefined||!current[targetIndex]))throw new DomainError('already-exists','An orphan projection ownership proof requires review.');
    }else{const ownerPath='orgs/gainpath/cohorts/fyp-v1/unifiedSampleOwnership/'+fypDigest(path),ownerIndex=positions.get(ownerPath);if(ownerIndex===undefined||!current[ownerIndex])throw new DomainError('already-exists','An identical unowned record cannot be adopted.');}
  }
  for(let i=0;i<entries.length;i++)if(!current[i]&&(activate||entries[i][0]!==plan.gatePath)){tx.create(entries[i][0],entries[i][1]);created++;}
  return{created,exactRecords:entries.length-(activate?0:1),activated:activate};});
}
/** Narrow access rollback only; original cohort, accounts and records remain. */
export async function disableUnifiedAdminIntegration(store:DocumentStore){
 const ownerPath='orgs/gainpath/cohorts/fyp-v1/unifiedSampleOwnership/'+fypDigest(UNIFIED_ADMIN_GATE);
 return store.transact(async tx=>{const gate=await tx.get(UNIFIED_ADMIN_GATE),owner=await tx.get(ownerPath);
  const expected={schemaVersion:1,organizationId:'gainpath',cohortId:'fyp-v1',rootPath:'orgs/gainpath/cohorts/fyp-v1',enabled:true,version:'unified-admin-v1'};
  if(!gate||!owner||owner.schemaVersion!==1||owner.seedId!=='unified-admin-business-v1'||owner.path!==UNIFIED_ADMIN_GATE||owner.digest!==fypDigest(gate)||typeof gate.enabled!=='boolean'||fypDigest({...gate,enabled:true})!==fypDigest(expected))throw new DomainError('failed-precondition','Changed or unowned Admin grant requires review.');
  if(gate.enabled===false)return{enabled:false as const,changed:false};
  const value={...gate,enabled:false};tx.set(UNIFIED_ADMIN_GATE,value);tx.set(ownerPath,{...owner,digest:fypDigest(value)});return{enabled:false as const,changed:true};
 });
}
export type {SamplePlanReference};
