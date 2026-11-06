import {Timestamp} from 'firebase-admin/firestore';
import {DomainError} from '../../platform/errors';
import {InputValidationError,requiredIdentifier} from '../../platform/validation';
import {keyOf} from '../../platform/idempotency';
import type {DocumentData,DocumentStore,TransactionPort} from '../../platform/firestore/store';
import {catalogDefaults,resolveExerciseExecution} from './exercise-execution';
import {exerciseTutorialProjection} from './exercise-tutorial';
const bad=()=>new InputValidationError('Invalid timed exercise draft.');
export async function saveTimedDraft(store:DocumentStore,auth:{uid:string;token:Record<string,unknown>},d:DocumentData,deps:{authorize:(tx:TransactionPort,auth:{uid:string;token:Record<string,unknown>},org:string)=>Promise<void>;clock?:()=>number;freshAuth?:(auth:{uid:string;token:Record<string,unknown>})=>Promise<void>}):Promise<DocumentData>{
 if(d.schemaVersion!==1||Object.keys(d).some(k=>!['schemaVersion','action','organizationId','exerciseId','requestId','expectedRevision','exercise'].includes(k))||!Number.isSafeInteger(d.expectedRevision)||Number(d.expectedRevision)<0||!d.exercise||typeof d.exercise!=='object'||Array.isArray(d.exercise))throw bad();
 const org=requiredIdentifier(d.organizationId,'organizationId'),id=requiredIdentifier(d.exerciseId,'exerciseId'),requestId=requiredIdentifier(d.requestId,'requestId'),e=d.exercise as DocumentData;
 if(Object.keys(e).some(k=>!['schemaVersion','exerciseName','muscleCategory','videoUrl','isActive','executionMode','workoutDefaults','description','coverImageUrl','difficulty','equipment','tutorialSteps','archived'].includes(k))||e.schemaVersion!==1||e.executionMode!=='videoGuidedTimed'||e.isActive!==false||typeof e.exerciseName!=='string'||!e.exerciseName.trim()||e.exerciseName.length>100||typeof e.muscleCategory!=='string'||!e.muscleCategory.trim()||e.muscleCategory.length>80||typeof e.videoUrl!=='string'||e.videoUrl.length>2048||(e.archived!==undefined&&typeof e.archived!=='boolean'))throw bad();
 catalogDefaults(org,id,e);exerciseTutorialProjection(e);
 const image=(v:unknown)=>{if(v===undefined||v==='')return;if(typeof v!=='string'||v.length>2048||/[\x00-\x20\x7f\\#]/.test(v))throw bad();let u:URL;try{u=new URL(v);}catch{throw bad();}if(u.protocol!=='https:'||u.username||u.password||u.hash)throw bad();};
 image(e.coverImageUrl);
 for(const [key,max] of [['description',2000],['equipment',300]] as const)if(e[key]!==undefined&&(typeof e[key]!=='string'||String(e[key]).length>max))throw bad();
 if(e.tutorialSteps!==undefined){if(!Array.isArray(e.tutorialSteps)||e.tutorialSteps.length>12)throw bad();for(const step of e.tutorialSteps){if(String(step.title).length>80||String(step.description).length>1200)throw bad();image(step.imageUrl);}}
 if(Buffer.byteLength(JSON.stringify(e))>700000)throw bad();
 const path=`orgs/${org}/exerciseVideos/${id}`,receiptPath=`orgs/${org}/commandReceipts/${keyOf('exerciseCatalog',auth.uid,requestId)}`,fingerprint=keyOf(d);await deps.freshAuth?.(auth);
 return store.transact(async tx=>{await deps.authorize(tx,auth,org);const [previous,receipt]=await Promise.all([tx.get(path),tx.get(receiptPath)]);if(receipt){if(receipt.fingerprint!==fingerprint)throw new DomainError('already-exists','Request reference used.');return receipt.result as DocumentData;}if(Number(previous?.editRevision??0)!==d.expectedRevision||(previous&&resolveExerciseExecution(org,id,previous)!=='videoGuidedTimed'))throw new DomainError('aborted','Exercise changed. Reload.');if(!previous&&e.archived===true)throw bad();
 if(previous?.archived===true){const fields=(v:DocumentData)=>Object.fromEntries(Object.entries(v).filter(([k])=>!['archived','editRevision','createdAt','updatedAt','mediaValidation'].includes(k)));if(keyOf(fields(previous))!==keyOf(fields(e)))throw new DomainError('failed-precondition','Restore before editing archived content.');}
 const editRevision=Number(d.expectedRevision)+1,now=Timestamp.fromMillis((deps.clock??Date.now)()),result={schemaVersion:1,exerciseId:id,editRevision};tx.set(path,{...e,exerciseName:e.exerciseName!.toString().trim(),muscleCategory:e.muscleCategory!.toString().trim(),archived:e.archived??false,editRevision,createdAt:previous?.createdAt??now,updatedAt:now});tx.create(receiptPath,{fingerprint,result});return result;});
}
