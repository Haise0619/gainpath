import {FieldPath,type Firestore} from 'firebase-admin/firestore';
import {DomainError} from '../../platform/errors';
import type {QueuePageReader} from './recommendation-queue-reader';

const disabled=()=>new DomainError('failed-precondition','Local synthetic recommendation reader is disabled.');
const leadId=(v:unknown):v is string=>typeof v==='string'&&/^[a-f0-9]{64}$/.test(v);
/** Explicit local SDK adapter. No default app, bootstrap or production fallback. */
export function createFirestoreRecommendationQueueReader(options:{firestore:Firestore;localReview?:{mode:'synthetic_emulator_only'}}):QueuePageReader{
  const {firestore}=options,enabled=options.localReview?.mode==='synthetic_emulator_only';
  return{readLeads:async(organizationId,afterLeadId,limit)=>{
    if(!enabled||process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:18111')throw disabled();
    try{
      const binding=firestore as unknown as {projectId?:unknown;_settings?:{servicePath?:unknown;port?:unknown;ssl?:unknown}};
      if(binding.projectId!=='demo-gainpath-module13-c'||binding._settings?.servicePath!=='127.0.0.1'||binding._settings?.port!==18111||binding._settings?.ssl!==false)throw disabled();
    }catch{throw disabled();}
    if(organizationId!=='synthetic-org')throw new DomainError('permission-denied','Synthetic queue scope does not match.');
    if((afterLeadId!==null&&!leadId(afterLeadId))||!Number.isSafeInteger(limit)||limit<1||limit>101)throw new DomainError('invalid-argument','Invalid bounded queue page.');
    try{
      let query=firestore.collection('orgs/synthetic-org/recommendationLeads').orderBy(FieldPath.documentId(),'asc').limit(limit);
      if(afterLeadId!==null)query=query.startAfter(afterLeadId);
      const snapshot=await query.get();let previous=afterLeadId;
      return snapshot.docs.map(doc=>{
        if(!leadId(doc.id)||(previous!==null&&doc.id<=previous))throw Error('Invalid source page');
        previous=doc.id;return{id:doc.id,data:doc.data()};
      });
    }catch{throw new DomainError('unavailable','Recommendation queue is temporarily unavailable.');}
  }};
}
