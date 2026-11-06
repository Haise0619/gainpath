/** Explicit test-only D composition. C's source, B engine and evidence remain unchanged. */
import {FieldPath, type Firestore} from 'firebase-admin/firestore';
import {DomainError} from '../src/platform/errors';
import type {DocumentStore} from '../src/platform/firestore/store';
import type {QueuePageReader} from '../src/modules/recommendation/recommendation-queue-reader';
import type {NotificationReader} from '../src/modules/coaching/module9-member-service';
import {createCurrentRecommendationTargetResolver} from '../src/modules/recommendation/recommendation-target-resolver';
import {createModule13CFixture, module13CFixtureDocuments, MODULE13_C_NOW, MODULE13_C_MEMBER} from './module13-c-integration.fixture';

export const MODULE13_D_PROJECT='demo-gainpath-module13-d';
export const MODULE13_D_HOST='127.0.0.1:18113';
export const MODULE13_D_ROOT='orgs/synthetic-org';
export const module13DFixtureDocuments=module13CFixtureDocuments;
/** Host elapsed time only: fixture calendar stays Nov1, with authoritative availability Nov2. */
export function module13DLogicalClock(){const started=Date.now();return()=>MODULE13_C_NOW+1000+Date.now()-started;}
export function guardModule13D(firestore?:Firestore):void{
  const fail=()=>{throw new DomainError('failed-precondition','Dedicated D loopback demo emulator required.');};
  if(process.env.FIRESTORE_EMULATOR_HOST!==MODULE13_D_HOST||process.env.GCLOUD_PROJECT!==MODULE13_D_PROJECT||process.env.GOOGLE_CLOUD_PROJECT!==MODULE13_D_PROJECT)fail();
  if(firestore){
    const binding=firestore as unknown as {projectId?:unknown;_settings?:{servicePath?:unknown;port?:unknown;ssl?:unknown}};
    if(binding.projectId!==MODULE13_D_PROJECT||binding._settings?.servicePath!=='127.0.0.1'||binding._settings?.port!==18113||binding._settings?.ssl!==false)fail();
  }
}
export async function createModule13DFixture(options:{store:DocumentStore;clock?:()=>number;grantConsent?:boolean}){
  const f=await createModule13CFixture({...options,clock:options.clock??module13DLogicalClock()});
  return {...f,deps:{...f.deps,localDelivery:{fixtureSetId:'module13-d-v1' as const},
    resolveTarget:createCurrentRecommendationTargetResolver({revalidateEligibility:f.validateTarget})}};
}
export function createModule13DQueueReader(firestore:Firestore):QueuePageReader{
  return{readLeads:async(org,after,limit)=>{
    guardModule13D(firestore);
    if(org!=='synthetic-org')throw new DomainError('permission-denied','Fixture organization required.');
    if((after!==null&&!/^[a-f0-9]{64}$/.test(after))||!Number.isSafeInteger(limit)||limit<1||limit>101)throw new DomainError('invalid-argument','Invalid bounded page.');
    let query=firestore.collection(`${MODULE13_D_ROOT}/recommendationLeads`).orderBy(FieldPath.documentId()).limit(limit);
    if(after)query=query.startAfter(after);
    return(await query.get()).docs.map(d=>({id:d.id,data:d.data()}));
  }};
}
export function createModule13DInboxReader(firestore:Firestore):NotificationReader{
  return{list:async(org,uid,after)=>{
    guardModule13D(firestore);
    if(org!=='synthetic-org'||uid!==MODULE13_C_MEMBER)throw new DomainError('permission-denied','Fixture Member required.');
    let query=firestore.collection(`${MODULE13_D_ROOT}/notifications`).where('recipientId','==',uid).orderBy('createdAtMillis','desc').orderBy(FieldPath.documentId(),'desc').limit(31);
    if(after){
      const cursor=await firestore.doc(`${MODULE13_D_ROOT}/notifications/${after}`).get();
      if(!cursor.exists||cursor.data()?.recipientId!==uid)throw new DomainError('permission-denied','Invalid owned cursor.');
      query=query.startAfter(cursor);
    }
    return(await query.get()).docs.map(d=>({id:d.id,data:d.data()}));
  }};
}
