import {Timestamp} from 'firebase-admin/firestore';
import {DomainError} from '../../platform/errors';
import {requiredIdentifier,InputValidationError} from '../../platform/validation';
import {keyOf} from '../../platform/idempotency';
import type {DocumentData,DocumentStore,TransactionPort} from '../../platform/firestore/store';
import {parseExercisePrescription,resolveExerciseExecution} from './exercise-execution';
const bad=()=>new InputValidationError('Invalid v2 routine blueprint.');
const record=(v:unknown):v is DocumentData=>!!v&&typeof v==='object'&&!Array.isArray(v);
export function parseBlueprintV2(raw:unknown):DocumentData {
 if(!record(raw)||Object.keys(raw).some(k=>!['schemaVersion','name','sessionDurationMin','days','level','goal','tags','equipmentNeeded','imageUrl'].includes(k))||raw.schemaVersion!==2||typeof raw.name!=='string'||!raw.name.trim()||raw.name.length>120||!Number.isInteger(raw.sessionDurationMin)||Number(raw.sessionDurationMin)<5||Number(raw.sessionDurationMin)>240||!Array.isArray(raw.days)||!raw.days.length||raw.days.length>14)throw bad();
 for(const k of ['goal','imageUrl'])if(raw[k]!==undefined&&(typeof raw[k]!=='string'||String(raw[k]).length>2048))throw bad();
 if(raw.level!==undefined&&!['Beginner','Intermediate','Advanced'].includes(String(raw.level)))throw bad();
 for(const k of ['tags','equipmentNeeded'])if(raw[k]!==undefined&&(!Array.isArray(raw[k])||(raw[k] as unknown[]).length>30||(raw[k] as unknown[]).some(v=>typeof v!=='string'||v.length>100)))throw bad();
 const days=new Set<number>(),entries=new Set<string>();let total=0;
 const result={...raw,name:raw.name.trim(),days:raw.days.map(day=>{if(!record(day)||Object.keys(day).some(k=>!['dayNumber','exercises'].includes(k))||!Number.isInteger(day.dayNumber)||Number(day.dayNumber)<1||Number(day.dayNumber)>14||days.has(Number(day.dayNumber))||!Array.isArray(day.exercises)||!day.exercises.length||day.exercises.length>20)throw bad();days.add(Number(day.dayNumber));
 return {dayNumber:day.dayNumber,exercises:day.exercises.map(e=>{if(!record(e)||Object.keys(e).some(k=>!['entryId','exerciseId','executionMode','sets','reps','durationSeconds','restSeconds','sourceCatalogRevision'].includes(k)))throw bad();requiredIdentifier(e.entryId,'entryId');requiredIdentifier(e.exerciseId,'exerciseId');if(entries.has(String(e.entryId)))throw bad();entries.add(String(e.entryId));if(e.sourceCatalogRevision!==undefined&&(!Number.isSafeInteger(e.sourceCatalogRevision)||Number(e.sourceCatalogRevision)<0))throw bad();total++;return {...e,...parseExercisePrescription(e)};})};})};
 if(total>50||Buffer.byteLength(JSON.stringify(result))>700000)throw bad();return result;
}
export async function blueprintCatalog(store:DocumentStore,auth:{uid:string;token:Record<string,unknown>},d:DocumentData,deps:{authorize:(tx:TransactionPort,auth:{uid:string;token:Record<string,unknown>},org:string)=>Promise<void>;clock?:()=>number;freshAuth?:(auth:{uid:string;token:Record<string,unknown>})=>Promise<void>}):Promise<DocumentData>{
 const allowed=['schemaVersion','action','organizationId','blueprintId','requestId','expectedRevision',...(d.action==='saveBlueprintV2'?['blueprint','expectedLegacyUpdatedAtMillis']:[])];
 if(d.schemaVersion!==1||!['saveBlueprintV2','archiveBlueprintV2'].includes(String(d.action))||Object.keys(d).some(k=>!allowed.includes(k))||!Number.isSafeInteger(d.expectedRevision)||Number(d.expectedRevision)<0)throw bad();
 const org=requiredIdentifier(d.organizationId,'organizationId'),id=requiredIdentifier(d.blueprintId,'blueprintId'),requestId=requiredIdentifier(d.requestId,'requestId'),base=`orgs/${org}`,path=`${base}/routineBlueprintsV2/${id}`,receiptPath=`${base}/commandReceipts/${keyOf('exerciseCatalog',auth.uid,requestId)}`,fingerprint=keyOf(d),blueprint=d.action==='saveBlueprintV2'?parseBlueprintV2(d.blueprint):undefined;
 await deps.freshAuth?.(auth);
 return store.transact(async tx=>{await deps.authorize(tx,auth,org);const [previous,receipt,legacy]=await Promise.all([tx.get(path),tx.get(receiptPath),tx.get(`${base}/routineBlueprints/${id}`)]);
 if(receipt){if(receipt.fingerprint!==fingerprint)throw new DomainError('already-exists','Request reference used.');return receipt.result as DocumentData;}
 if(Number(previous?.editRevision??0)!==d.expectedRevision||previous?.archived===true)throw new DomainError('aborted','Blueprint changed or archived. Reload.');
 if(!previous&&legacy&&d.expectedLegacyUpdatedAtMillis===undefined)throw new DomainError('aborted','A current legacy baseline is required for migration.');
 if(d.expectedLegacyUpdatedAtMillis!==undefined){const ts=legacy?.updatedAt as {toMillis?:()=>number}|undefined;if(previous||!Number.isSafeInteger(d.expectedLegacyUpdatedAtMillis)||!ts?.toMillis||ts.toMillis()!==d.expectedLegacyUpdatedAtMillis)throw new DomainError('aborted','Legacy blueprint changed. Reload.');}
 if(!blueprint&&!previous)throw new DomainError('not-found','Blueprint not found.');
 if(blueprint){const rows=(blueprint.days as DocumentData[]).flatMap(day=>day.exercises as DocumentData[]);const sources=await Promise.all(rows.map(e=>tx.get(`${base}/exerciseVideos/${e.exerciseId}`)));rows.forEach((e,i)=>{const source=sources[i];if(!source||source.isActive!==true||source.archived===true||resolveExerciseExecution(org,String(e.exerciseId),source)!==e.executionMode)throw new DomainError('failed-precondition','Exercise is inactive or execution mode changed.');if(e.executionMode==='videoGuidedTimed'){const stamp=source.mediaValidation as DocumentData|undefined;if(!stamp||stamp.schemaVersion!==1||stamp.videoUrl!==source.videoUrl||stamp.sourceRevision!==Number(source.editRevision)-1)throw new DomainError('failed-precondition','Timed exercise validation changed.');}});}
 const revision=Number(d.expectedRevision)+1,now=Timestamp.fromMillis((deps.clock??Date.now)()),result={schemaVersion:1,blueprintId:id,editRevision:revision};tx.set(path,blueprint?{...blueprint,editRevision:revision,archived:false,createdAt:previous?.createdAt??now,updatedAt:now,updatedBy:auth.uid}:{...previous,archived:true,editRevision:revision,updatedAt:now,updatedBy:auth.uid});tx.create(receiptPath,{fingerprint,result});return result;});
}
