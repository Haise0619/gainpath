import {canonicalRecommendationPage} from './canonical-recommendation-page';
import {DomainError} from '../../platform/errors';
import {requiredIdentifier} from '../../platform/validation';
import {keys,object} from '../workouts/workout-backup-validation';
import {authorizeRecommendationSession,recommendationCommandError,type RecommendationCommandDependencies} from './recommendation-configuration';
import {requireQueueAdmin} from './recommendation-queue-security';
import type {InsightsRequest} from './exercise-insights-contracts';
import {createCanonicalRecommendationLifecycle,type ReviewedCanonicalRuntime} from './canonical-recommendation-lifecycle';
import {createAdminAiService,type AdminAiDependencies} from './admin-ai-service';
import {RecommendationProviderError} from './gemini-recommendation-ranker';

export function createCanonicalRecommendationAdmin(deps: RecommendationCommandDependencies & {runtime?: ReviewedCanonicalRuntime;aiReader?:AdminAiDependencies['aiReader'];aiProvider?:AdminAiDependencies['aiProvider']}) {
  return async(incoming: InsightsRequest): Promise<unknown> => {
    try {
      const e=object(incoming.data); keys(e,['schemaVersion','operation','data']); const q=object(e.data);
      if(e.schemaVersion!==1||Buffer.byteLength(JSON.stringify(e))>16384||!['session.access','admin.queue.list','admin.queue.detail','admin.queue.decide','delivery.process','admin.ai.members','admin.ai.member.search','admin.ai.member','admin.ai.planner','admin.ai.outreach.generate','admin.ai.outreach.send'].includes(String(e.operation))) throw new DomainError('invalid-argument','Invalid canonical command.');
      const org=requiredIdentifier(q.organizationId,'organization'), request={...incoming,data:q};
      const auth=await authorizeRecommendationSession(request,deps);
      await deps.store.transact(async tx=>{if(!deps.runtime?.scopedDataset && await tx.get(`datasetAssignments/${auth.uid}`))throw new DomainError('permission-denied','Canonical Admin required.');await requireQueueAdmin(tx,auth,org);});
      if(e.operation==='session.access') {keys(q,['schemaVersion','organizationId']);if(q.schemaVersion!==1)throw new DomainError('invalid-argument','Invalid version.');
        return{schemaVersion:1,mode:'accepted_workout',organizationId:org,role:'admin',enabled:!!deps.runtime,reason:deps.runtime?null:'review_required'};}
      if(!deps.runtime) throw new DomainError('failed-precondition','Canonical source and target policies require review.');
      if(String(e.operation).startsWith('admin.ai.')){
        if(q.schemaVersion!==1||!deps.aiReader)throw new DomainError('failed-precondition','Admin AI assistance is unavailable.');
        return await createAdminAiService({...deps,runtime:deps.runtime,aiReader:deps.aiReader}).execute(auth,org,String(e.operation),q);
      }
      const lifecycle=createCanonicalRecommendationLifecycle({...deps,runtime:deps.runtime});
      if(e.operation==='admin.queue.list') {
        keys(q,['schemaVersion','organizationId','afterId','includeRoutine'],['schemaVersion','organizationId','afterId']);
        if(q.schemaVersion!==1||q.includeRoutine!==undefined&&typeof q.includeRoutine!=='boolean'||
          q.afterId!==null&&(typeof q.afterId!=='string'||!/^[a-f0-9]{64}$/.test(q.afterId)))throw new DomainError('invalid-argument','Invalid query.');
        const page=await canonicalRecommendationPage({...deps,runtime:deps.runtime},auth,org,q.afterId as string|null,true,false,q.includeRoutine===true);
        return{schemaVersion:1,mode:'accepted_workout',organizationId:org,enabled:true,reason:null,records:page.records,nextAfterId:page.nextAfterId};
      }
      if(e.operation==='admin.queue.detail'||e.operation==='delivery.process') {
        keys(q,['schemaVersion','organizationId','id']); if(q.schemaVersion!==1||typeof q.id!=='string')throw new DomainError('invalid-argument','Invalid lookup.');
        const detail=await lifecycle.adminDetail(auth,org,q.id);
        return e.operation==='delivery.process'?await lifecycle.deliver(org,q.id):detail;
      }
      keys(q,['schemaVersion','organizationId','id','expectedRevision','commandId','action']);
      if(q.schemaVersion!==1||typeof q.id!=='string'||!Number.isSafeInteger(q.expectedRevision)||Number(q.expectedRevision)<1||typeof q.commandId!=='string'||!['send','dismiss'].includes(String(q.action)))throw new DomainError('invalid-argument','Invalid decision.');
      const result=await lifecycle.decide(auth,org,q.id,Number(q.expectedRevision),q.commandId,q.action as 'send'|'dismiss');
      if(q.action==='send')await lifecycle.deliver(org,q.id);
      return result;
    }catch(error){
      if((incoming.data as any)?.operation?.startsWith?.('admin.ai.')){
        if(error instanceof DomainError)throw error;
        if(error instanceof RecommendationProviderError)throw new DomainError('unavailable',error.reason==='timeout'?'Gemini timed out. Try Generate again.':error.reason==='rate_limited'?'Gemini is busy. Wait a moment and retry.':'Gemini could not generate suggestions. Check the server configuration or try again.');
      }
      throw recommendationCommandError(error);
    }
  };
}
