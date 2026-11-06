import {DomainError} from '../../platform/errors';
import type {TransactionPort} from '../../platform/firestore/store';
import {exerciseTutorialProjection} from '../content/exercise-tutorial';
import {tutorialMediaUrl} from '../content/tutorial-media';
import {parseRecommendationLead,queueText,type RecommendationLead} from './recommendation-queue-contracts';
import type {CurrentRecommendationTarget,RecommendationDeliveryDependencies} from './recommendation-member-contracts';

/** Authoritative source extension. Caller supplies the existing B-backed eligibility
 * guard and owns current Member authorization. No SDK bootstrap or permissive fallback. */
export function createCurrentRecommendationTargetResolver(options:{organizationId?:'synthetic-org'|'gainpath';revalidateEligibility:(tx:Pick<TransactionPort,'get'|'getAll'>,lead:RecommendationLead)=>Promise<'valid'|'stale'>}):RecommendationDeliveryDependencies['resolveTarget']{
  return async(tx,raw):Promise<CurrentRecommendationTarget|null>=>{
    if(raw.organizationId!==(options.organizationId??'synthetic-org'))throw new DomainError('permission-denied','Recommendation scope mismatch.');
    const lead=parseRecommendationLead(raw,options.organizationId??'synthetic-org');
    if(await options.revalidateEligibility(tx,lead)!=='valid')return null;
    const root=`orgs/${lead.organizationId}`;
    if(lead.target.kind==='trainer'){
      const target=lead.target,profile=await tx.get(`${root}/coaches/${target.coachId}`),branch=await tx.get(`${root}/branches/${target.branchId}`);
      if(profile?.status!=='published'||branch?.status!=='active'||!queueText(profile.displayName,80)||!queueText(profile.specialty,80))return null;
      let photoPath:string|null=null;
      if(profile.photoPath!==null&&profile.photoPath!==undefined){
        const prefix=`${root}/coachProfilePhotos/${target.coachId}/`;
        if(typeof profile.photoPath!=='string'||!profile.photoPath.startsWith(prefix)||!/^[a-f0-9]{32}$/.test(profile.photoPath.slice(prefix.length)))return null;
        photoPath=profile.photoPath;
      }
      return{target:structuredClone(target),label:profile.displayName,specialization:profile.specialty,imageUrl:null,photoPath};
    }
    const target=lead.target,d=target.destination,publication=await tx.get(`${root}/content/${d.routineId}`),catalog=await tx.get(`${root}/exerciseVideos/${d.exerciseId}`);
    if(d.organizationId!==lead.organizationId||publication?.kind!=='routine'||publication.status!=='published'||publication.archived===true||publication.isActive===false||catalog?.isActive!==true||catalog.archived===true||!Array.isArray(publication.exercises))return null;
    const exercise=publication.exercises[d.exerciseIndex];
    if(!exercise||exercise.exerciseId!==d.exerciseId||(exercise.dayNumber??1)!==d.dayNumber||!queueText(exercise.name,200))return null;
    const projected=exerciseTutorialProjection(exercise);
    if(!(Array.isArray(projected.tutorialSteps)&&projected.tutorialSteps.length)&&!tutorialMediaUrl(exercise.videoUrl))return null;
    return{target:structuredClone(target),label:exercise.name,specialization:null,imageUrl:typeof projected.imageUrl==='string'?projected.imageUrl:null,photoPath:null};
  };
}
