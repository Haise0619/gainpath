import {getAuth} from 'firebase-admin/auth';
import {getFirestore,FieldPath} from 'firebase-admin/firestore';
import {onCall,HttpsError} from 'firebase-functions/v2/https';
import {FirestoreStore} from '../../platform/firestore/firestore-store';
import {DomainError} from '../../platform/errors';
import {InputValidationError,requiredIdentifier} from '../../platform/validation';
import {adminReport} from './admin-reporting';

// Read-only preparation. Deploy this isolated export only after exact approval.
export const adminReportingCommand=onCall({region:'asia-southeast1',enforceAppCheck:true,
 timeoutSeconds:60,maxInstances:5},async request=>{
 try{
   const auth=request.auth?{uid:request.auth.uid,token:request.auth.token}:undefined;
   if(!auth||auth.token.email_verified!==true||typeof auth.token.email!=='string'||!Number.isSafeInteger(auth.token.auth_time))throw new DomainError('unauthenticated','Sign in with a verified account.');
   const current=await getAuth().getUser(auth.uid),validAfter=current.tokensValidAfterTime?Date.parse(current.tokensValidAfterTime):0;
   if(current.disabled||!current.emailVerified||current.email!==auth.token.email||!Number.isFinite(validAfter)||Number(auth.token.auth_time)*1000<validAfter)throw new DomainError('unauthenticated','Your account session changed.');
   const org=requiredIdentifier(request.data?.organizationId,'organizationId'),db=getFirestore();
   return await adminReport(new FirestoreStore(db),auth,request.data,{page:async(kind,after,limit)=>{
     let q=db.collection(`orgs/${org}/${kind}`).orderBy(FieldPath.documentId()).limit(limit);
     if(after)q=q.startAfter(after);
     return (await q.get()).docs.map(doc=>({id:doc.id,data:doc.data()}));
   }});
 }catch(e){if(e instanceof DomainError)throw new HttpsError(e.code,e.message);
   if(e instanceof InputValidationError)throw new HttpsError('invalid-argument',e.message);
   throw new HttpsError('unavailable','Reports could not be loaded. No partial totals were returned.');}
});
