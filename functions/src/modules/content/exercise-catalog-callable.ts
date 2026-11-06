import {getAuth} from 'firebase-admin/auth';
import {getFirestore} from 'firebase-admin/firestore';
import {getStorage} from 'firebase-admin/storage';
import {HttpsError,onCall} from 'firebase-functions/v2/https';
import {DomainError} from '../../platform/errors';
import {InputValidationError} from '../../platform/validation';
import {FirestoreStore} from '../../platform/firestore/firestore-store';
import {requireCurrentLifecycleIdentity} from '../identity/member-account-lifecycle-callables';
import {exerciseCatalog,type CatalogMediaVerifier} from './exercise-catalog';
export class FirebaseCatalogMediaVerifier implements CatalogMediaVerifier {
 async verify(identity:Parameters<CatalogMediaVerifier['verify']>[0]){
  const [metadata]=await getStorage().bucket(identity.bucket).file(identity.objectPath).getMetadata();
  return {generation:String(metadata.generation??''),contentType:metadata.contentType??'',sizeBytes:Number(metadata.size),downloadTokens:String(metadata.metadata?.firebaseStorageDownloadTokens??'').split(',')};
 }
}
export const exerciseCatalogCommand=onCall({region:'asia-southeast1',enforceAppCheck:true,timeoutSeconds:60,maxInstances:5},async request=>{
 try{
  if(!request.app)throw new DomainError('unauthenticated','App verification required.');
  return await exerciseCatalog(new FirestoreStore(getFirestore()),request.auth,request.data,{media:new FirebaseCatalogMediaVerifier(),freshAuth:async auth=>{await requireCurrentLifecycleIdentity(auth,uid=>getAuth().getUser(uid));}});
 }catch(error){if(error instanceof DomainError)throw new HttpsError(error.code,error.message);if(error instanceof InputValidationError)throw new HttpsError('invalid-argument',error.message);throw new HttpsError('unavailable','Activation could not be confirmed. Retry the same request.');}
});
