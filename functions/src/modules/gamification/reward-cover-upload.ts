import {createHash} from 'node:crypto';
import {requireVerifiedEmail} from '../../platform/auth-context';
import {InputValidationError,requiredIdentifier} from '../../platform/validation';
import {DomainError} from '../../platform/errors';
import type {DocumentStore,DocumentData} from '../../platform/firestore/store';
import {authorizeRewardsAdmin} from './verified-rewards-service';
export interface RewardCoverStore {upload(path:string,bytes:Buffer,contentType:string,sha256:string):Promise<string>}
type Auth={uid:string;token:Record<string,unknown>}|undefined;
export async function uploadRewardCover(store:DocumentStore,auth:Auth,raw:unknown,media:RewardCoverStore,clock:()=>number=Date.now){
 requireVerifiedEmail(auth);
 if(!raw||typeof raw!=='object'||Array.isArray(raw))throw new InputValidationError('Cover upload required.');
 const d=raw as DocumentData,fields=['schemaVersion','organizationId','action','uploadId','contentType','dataBase64'];
 if(d.schemaVersion!==1||d.action!=='uploadCover'||Object.keys(d).length!==fields.length||Object.keys(d).some(k=>!fields.includes(k))||typeof d.uploadId!=='string'||!/^[a-f0-9]{32}$/.test(d.uploadId)||!['image/jpeg','image/png','image/webp'].includes(String(d.contentType))||typeof d.dataBase64!=='string'||d.dataBase64.length>Math.ceil(5*1024*1024/3)*4)throw new InputValidationError('Choose a JPG, PNG or WebP up to 5 MB.');
 const org=requiredIdentifier(d.organizationId,'organizationId'),uid=requiredIdentifier(auth!.uid,'uid');
 await store.transact(tx=>authorizeRewardsAdmin(tx,auth!,org));
 const bytes=Buffer.from(d.dataBase64,'base64');
 if(!bytes.length||bytes.length>5*1024*1024||bytes.toString('base64')!==d.dataBase64)throw new InputValidationError('Invalid cover image.');
 const starts=(a:number[])=>a.every((v,i)=>bytes[i]===v);
 const type=starts([255,216,255])?'image/jpeg':starts([137,80,78,71,13,10,26,10])?'image/png':starts([82,73,70,70])&&bytes.subarray(8,12).toString()==='WEBP'?'image/webp':null;
 if(!type||type!==d.contentType)throw new InputValidationError('Cover content does not match the image type.');
 const now=clock();if(!Number.isSafeInteger(now)||now<=0)throw new DomainError('failed-precondition','Server time is unavailable.');
 const url=await media.upload(`orgs/${org}/rewardImages/${uid}/${d.uploadId}`,bytes,type,createHash('sha256').update(bytes).digest('hex'));
 await store.transact(tx=>authorizeRewardsAdmin(tx,auth!,org));
 return {schemaVersion:1,organizationId:org,url};
}
