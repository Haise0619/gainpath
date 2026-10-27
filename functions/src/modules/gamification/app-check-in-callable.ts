import {getAuth} from 'firebase-admin/auth';
import {getFirestore} from 'firebase-admin/firestore';
import {onCall,HttpsError} from 'firebase-functions/v2/https';
import {FirestoreStore} from '../../platform/firestore/firestore-store';
import {DomainError} from '../../platform/errors';
import {InputValidationError} from '../../platform/validation';
import {appCheckInCommand as execute} from './app-check-in-service';
// Proposed base app-engagement policy only; selective deployment needs approval.
export const appCheckInCommand=onCall({region:'asia-southeast1',enforceAppCheck:true,timeoutSeconds:30,maxInstances:5},async request=>{
 try{
  const auth=request.auth?{uid:request.auth.uid,token:request.auth.token}:undefined;
  if(!auth||auth.token.email_verified!==true||typeof auth.token.email!=='string'||!Number.isSafeInteger(auth.token.auth_time))throw new DomainError('unauthenticated','Sign in with a verified account.');
  const current=await getAuth().getUser(auth.uid),validAfter=current.tokensValidAfterTime?Date.parse(current.tokensValidAfterTime):0;
  if(current.disabled||!current.emailVerified||current.email!==auth.token.email||!Number.isFinite(validAfter)||Number(auth.token.auth_time)*1000<validAfter)throw new DomainError('unauthenticated','Your account session changed.');
  return await execute(new FirestoreStore(getFirestore()),auth,request.data);
 }catch(e){if(e instanceof DomainError)throw new HttpsError(e.code,e.message);if(e instanceof InputValidationError)throw new HttpsError('invalid-argument',e.message);throw new HttpsError('unavailable','Check-in could not be confirmed. Refresh and retry.');}
});
