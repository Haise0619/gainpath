import {DomainError} from '../../platform/errors';
import {requiredIdentifier} from '../../platform/validation';
import {keys,object} from '../workouts/workout-backup-validation';
import {authorizeRecommendationSession,recommendationCommandError,type RecommendationCommandDependencies} from './recommendation-configuration';
import {requireQueueAdmin} from './recommendation-queue-security';
import type {InsightsRequest} from './exercise-insights-contracts';
import {createCanonicalRecommendationLifecycle,type ReviewedCanonicalRuntime} from './canonical-recommendation-lifecycle';

export function createCanonicalRecommendationAdmin(deps: RecommendationCommandDependencies & {runtime?: ReviewedCanonicalRuntime}) {
  return async(incoming: InsightsRequest): Promise<unknown> => {
    try {
      const e=object(incoming.data); keys(e,['schemaVersion','operation','data']); const q=object(e.data);
      if(e.schemaVersion!==1||Buffer.byteLength(JSON.stringify(e))>16384||!['session.access','admin.queue.list','admin.queue.detail','admin.queue.decide','delivery.process'].includes(String(e.operation))) throw new DomainError('invalid-argument','Invalid canonical command.');
      const org=requiredIdentifier(q.organizationId,'organization'), request={...incoming,data:q};
      const auth=await authorizeRecommendationSession(request,deps);
      await deps.store.transact(async tx=>{if(await tx.get(`datasetAssignments/${auth.uid}`))throw new DomainError('permission-denied','Canonical Admin required.');await requireQueueAdmin(tx,auth,org);});
      if(e.operation==='session.access') {keys(q,['schemaVersion','organizationId']);if(q.schemaVersion!==1)throw new DomainError('invalid-argument','Invalid version.');
        return{schemaVersion:1,mode:'accepted_workout',organizationId:org,role:'admin',enabled:!!deps.runtime,reason:deps.runtime?null:'review_required'};}
      if(!deps.runtime) throw new DomainError('failed-precondition','Canonical source and target policies require review.');
      const lifecycle=createCanonicalRecommendationLifecycle({...deps,runtime:deps.runtime});
      if(e.operation==='admin.queue.list') {
        keys(q,['schemaVersion','organizationId','afterId']);
        if(q.schemaVersion!==1||q.afterId!==null&&(typeof q.afterId!=='string'||!/^[a-f0-9]{64}$/.test(q.afterId)))throw new DomainError('invalid-argument','Invalid query.');
        const ids=await lifecycle.ids(auth,org,q.afterId as string|null,true),records:unknown[]=[];
        for(const id of ids)try{records.push(await lifecycle.adminDetail(auth,org,id));}catch(error){if(!(error instanceof DomainError)||error.code!=='failed-precondition')throw error;}
        return{schemaVersion:1,mode:'accepted_workout',organizationId:org,records,nextAfterId:ids.length===25?ids[ids.length-1]:null};
      }
      if(e.operation==='admin.queue.detail'||e.operation==='delivery.process') {
        keys(q,['schemaVersion','organizationId','id']); if(q.schemaVersion!==1||typeof q.id!=='string')throw new DomainError('invalid-argument','Invalid lookup.');
        await lifecycle.adminDetail(auth,org,q.id);
        return e.operation==='delivery.process'?await lifecycle.deliver(org,q.id):await lifecycle.adminDetail(auth,org,q.id);
      }
      keys(q,['schemaVersion','organizationId','id','expectedRevision','commandId','action']);
      if(q.schemaVersion!==1||typeof q.id!=='string'||!Number.isSafeInteger(q.expectedRevision)||Number(q.expectedRevision)<1||typeof q.commandId!=='string'||!['send','dismiss'].includes(String(q.action)))throw new DomainError('invalid-argument','Invalid decision.');
      const result=await lifecycle.decide(auth,org,q.id,Number(q.expectedRevision),q.commandId,q.action as 'send'|'dismiss');
      if(q.action==='send')await lifecycle.deliver(org,q.id);
      return result;
    }catch(error){throw recommendationCommandError(error);}
  };
}
