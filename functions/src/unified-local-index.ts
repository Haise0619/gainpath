/** Actual emulator transport: same services, no legacy provider/payment exports. */
import {initializeApp,getApps} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {getAuth} from 'firebase-admin/auth';
import {onCall,HttpsError} from 'firebase-functions/v2/https';
import {createUnifiedAdminBackend} from './modules/dataset/unified-admin-backend';
import {createFypDatasetBackend} from './modules/dataset/fyp-backend';
import {recommendationCommandError} from './modules/recommendation/recommendation-configuration';
if(!getApps().length)initializeApp();
const options={region:'asia-southeast1',enforceAppCheck:true,timeoutSeconds:540,maxInstances:1,concurrency:4} as const;
export const fypDatasetCommand=onCall(options,async request=>{try{
 const input={app:request.app?{appId:request.app.appId}:undefined,auth:request.auth?{uid:request.auth.uid,token:request.auth.token}:undefined,data:request.data};
 if(typeof request.data?.operation==='string'&&request.data.operation.startsWith('admin.unified.'))return await createUnifiedAdminBackend({db:getFirestore(),auth:getAuth()}).command(input);
 return await createFypDatasetBackend({db:getFirestore(),auth:getAuth()}).command(input);
}catch(e){const x=recommendationCommandError(e);throw new HttpsError(x.code,x.message);}});
