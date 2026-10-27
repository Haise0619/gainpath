import {randomUUID} from 'node:crypto';
import {getStorage} from 'firebase-admin/storage';
import {DomainError} from '../../platform/errors';
import type {RewardCoverStore} from './reward-cover-upload';
export class FirebaseRewardCoverStore implements RewardCoverStore {
 async upload(path:string,bytes:Buffer,contentType:string,sha256:string){
  const bucket=getStorage().bucket('gainpath-0619.firebasestorage.app'),file=bucket.file(path);
  const validate=(metadata:{contentType?:string;size?:number|string;metadata?:Record<string,unknown>})=>{
   const token=String(metadata.metadata?.firebaseStorageDownloadTokens??'').split(',')[0];
   if(metadata.contentType!==contentType||Number(metadata.size)!==bytes.length||metadata.metadata?.gainpathSha256!==sha256||!/^[a-f0-9-]{36}$/i.test(token))throw new DomainError('already-exists','This upload reference was already used for another image.');
   return `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(path)}?alt=media&token=${encodeURIComponent(token)}`;
  };
  try{const [existing]=await file.getMetadata();return validate(existing);}catch(error){if(Number((error as {code?:unknown})?.code)!==404)throw error;}
  try{
   await file.save(bytes,{resumable:false,preconditionOpts:{ifGenerationMatch:0},metadata:{contentType,cacheControl:'private, max-age=3600',metadata:{firebaseStorageDownloadTokens:randomUUID(),gainpathSha256:sha256}}});
  }catch(error){if(Number((error as {code?:unknown})?.code)!==412)throw error;}
  const [metadata]=await file.getMetadata();
  return validate(metadata);
 }
}
