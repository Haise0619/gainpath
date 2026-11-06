import {saveTimedDraft} from './timed-catalog-draft';
import {blueprintCatalog} from './blueprint-catalog';
import {DomainError} from '../../platform/errors';
import {requireActiveMembership,requireVerifiedEmail} from '../../platform/auth-context';
import {keyOf} from '../../platform/idempotency';
import {requiredIdentifier,InputValidationError} from '../../platform/validation';
import type {DocumentData,DocumentStore,TransactionPort} from '../../platform/firestore/store';
import {catalogDefaults} from './exercise-execution';
export interface CatalogAuth {uid:string;token:Record<string,unknown>}
export interface ManagedMediaIdentity {bucket:string;objectPath:string;videoUrl:string}
export interface CatalogMediaVerifier {verify(identity:ManagedMediaIdentity):Promise<{generation:string;contentType:string;sizeBytes:number;downloadTokens:readonly string[]}>}
export interface MediaValidation extends ManagedMediaIdentity {schemaVersion:1;generation:string;contentType:'video/mp4';sizeBytes:number;validatedAtMillis:number;sourceRevision:number}
export interface ActivationReceipt {schemaVersion:1;requestId:string;exerciseId:string;status:'active';editRevision:number;mediaValidation:MediaValidation}
const failed=(message:string)=>new DomainError('failed-precondition',message);
export function managedTimedMedia(org:string,url:unknown):ManagedMediaIdentity {
 if(typeof url!=='string'||url.length>2048)throw failed('Managed exercise video required.');
 let u:URL;try{u=new URL(url);}catch{throw failed('Invalid exercise video URL.');}
 const match=/^\/v0\/b\/([^/]+)\/o\/([^/]+)$/.exec(u.pathname);
 if(u.protocol!=='https:'||u.hostname!=='firebasestorage.googleapis.com'||u.port||u.username||u.password||u.hash||!match||match[1]!=='gainpath-0619.firebasestorage.app'||u.searchParams.get('alt')!=='media'||!u.searchParams.get('token')||Array.from(u.searchParams.keys()).some(k=>!['alt','token','generation'].includes(k)))throw failed('Use a managed exercise MP4 upload.');
 let objectPath:string;try{objectPath=decodeURIComponent(match[2]);}catch{throw failed('Invalid video object.');}
 const parts=objectPath.split('/');
 if(parts.length!==5||parts[0]!=='orgs'||parts[1]!==org||parts[2]!=='exerciseVideos'||!/^[-A-Za-z0-9_]{1,128}$/.test(parts[3])||! /^[a-f0-9]{32}\.mp4$/.test(parts[4]))throw failed('Exercise video belongs to another organization or path.');
 return {bucket:match[1],objectPath,videoUrl:url};
}
export async function verifyTimedCatalogMedia(org:string,id:string,data:DocumentData,media:CatalogMediaVerifier,clock:()=>number=Date.now):Promise<MediaValidation>{
 if(data.schemaVersion!==1||data.archived===true||catalogDefaults(org,id,data).executionMode!=='videoGuidedTimed')throw failed('Timed exercise is archived or invalid.');
 const identity=managedTimedMedia(org,data.videoUrl);
 let metadata:Awaited<ReturnType<CatalogMediaVerifier['verify']>>;try{metadata=await media.verify(identity);}catch{throw failed('Exercise video is unavailable. Upload it again.');}
 const generation=new URL(identity.videoUrl).searchParams.get('generation');
 if(!/^[1-9][0-9]*$/.test(metadata.generation)||metadata.contentType!=='video/mp4'||!Number.isSafeInteger(metadata.sizeBytes)||metadata.sizeBytes<1||metadata.sizeBytes>100*1024*1024||!metadata.downloadTokens.includes(new URL(identity.videoUrl).searchParams.get('token')!)||(generation!==null&&generation!==metadata.generation))throw failed('Exercise video metadata or access token is invalid.');
 return {...identity,schemaVersion:1,generation:metadata.generation,contentType:'video/mp4',sizeBytes:metadata.sizeBytes,validatedAtMillis:clock(),sourceRevision:Number(data.editRevision??0)};
}
export async function authorizeCatalogAuthor(tx:TransactionPort,auth:CatalogAuth,org:string){
 const [u,m,o]=await Promise.all([tx.get(`users/${auth.uid}`),tx.get(`orgs/${org}/members/${auth.uid}`),tx.get(`orgs/${org}`)]);
 const membership=requireActiveMembership(m),l=u?.accountLifecycle as DocumentData|undefined;
 if(o?.status!=='active'||u?.organizationId!==org||m?.organizationId!==org||!['admin','staff'].includes(membership.role)||(u.role!==undefined&&u.role!==membership.role)||(m.userId!==undefined&&m.userId!==auth.uid)||u.cohortId!==undefined||m.cohortId!==undefined||u.dataSource==='fypSimulation'||m.dataSource==='fypSimulation')throw new DomainError('permission-denied','Current canonical content author required.');
 if(l!==undefined&&(!l||l.schemaVersion!==1||l.state!=='active'||l.revocationPending!==false||!Number.isSafeInteger(l.sessionNotBeforeSeconds)||Number(l.sessionNotBeforeSeconds)<0||!Number.isSafeInteger(auth.token.auth_time)||Number(auth.token.auth_time)<Number(l.sessionNotBeforeSeconds)))throw new DomainError('permission-denied','Account session changed.');
}
export async function exerciseCatalog(store:DocumentStore,auth:CatalogAuth|undefined,raw:unknown,deps:{media:CatalogMediaVerifier;clock?:()=>number;freshAuth?:(auth:CatalogAuth)=>Promise<void>}):Promise<ActivationReceipt|DocumentData>{
 requireVerifiedEmail(auth);requiredIdentifier(auth!.uid,'uid');
 if(!raw||typeof raw!=='object'||Array.isArray(raw))throw new InputValidationError('Catalog command required.');
 const d=raw as DocumentData;
 if(d.action==='saveTimedDraft')return saveTimedDraft(store,auth!,d,{...deps,authorize:authorizeCatalogAuthor});
 if(d.action==='saveBlueprintV2'||d.action==='archiveBlueprintV2')return blueprintCatalog(store,auth!,d,{...deps,authorize:authorizeCatalogAuthor});
 if(Object.keys(d).some(k=>!['schemaVersion','action','organizationId','exerciseId','requestId','expectedRevision'].includes(k))||d.schemaVersion!==1||d.action!=='activateTimed'||!Number.isSafeInteger(d.expectedRevision)||Number(d.expectedRevision)<0)throw new InputValidationError('Invalid activation command.');
 const org=requiredIdentifier(d.organizationId,'organizationId'),id=requiredIdentifier(d.exerciseId,'exerciseId'),requestId=requiredIdentifier(d.requestId,'requestId'),path=`orgs/${org}/exerciseVideos/${id}`,receiptPath=`orgs/${org}/commandReceipts/${keyOf('exerciseCatalog',auth!.uid,requestId)}`,fingerprint=keyOf(d);
 const read=async(tx:TransactionPort)=>{await authorizeCatalogAuthor(tx,auth!,org);const receipt=await tx.get(receiptPath);if(receipt){if(receipt.fingerprint!==fingerprint)throw new DomainError('already-exists','requestId already used with different activation.');return {receipt:receipt.result as unknown as ActivationReceipt};}const source=await tx.get(path);if(!source)throw new DomainError('not-found','Exercise not found.');if(source.isActive!==false||source.archived===true||Number(source.editRevision??0)!==d.expectedRevision)throw failed('Exercise draft changed, is active, or archived. Reload before activating.');return {source};};
 await deps.freshAuth?.(auth!);
 const first=await store.transact(read);if(first.receipt)return first.receipt;
 const source=first.source!,stamp=await verifyTimedCatalogMedia(org,id,source,deps.media,deps.clock),snapshot=keyOf(source);
 await deps.freshAuth?.(auth!);
 return store.transact(async tx=>{const current=await read(tx);if(current.receipt)return current.receipt;if(keyOf(current.source)!==snapshot)throw new DomainError('aborted','Exercise changed during media verification. Reload and retry.');const revision=Number(d.expectedRevision)+1,result:ActivationReceipt={schemaVersion:1,requestId,exerciseId:id,status:'active',editRevision:revision,mediaValidation:stamp};tx.set(path,{...current.source,isActive:true,editRevision:revision,mediaValidation:stamp});tx.create(receiptPath,{fingerprint,result});return result;});
}
