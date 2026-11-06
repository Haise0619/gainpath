/** Prepared two-callable release package. NOT imported by production index.ts.
 * Missing/disabled server release metadata denies every request. No live seed or
 * config activation is performed by importing or deploying this package. */
import {initializeApp,getApps} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {getAuth} from 'firebase-admin/auth';
import {onCall,HttpsError} from 'firebase-functions/v2/https';
import {createFypDatasetBackend} from './modules/dataset/fyp-backend';
import {resolveFypRuntimeRelease} from './modules/dataset/fyp-runtime-release';
import {recommendationCommandError} from './modules/recommendation/recommendation-configuration';
import {createUnifiedAdminBackend} from './modules/dataset/unified-admin-backend';
if(!getApps().length)initializeApp();
const options={region:'asia-southeast1',enforceAppCheck:true,timeoutSeconds:540,maxInstances:1,concurrency:4} as const;
const callable=(method:'session'|'command')=>onCall(options,async request=>{
  try{
    if(!request.auth||!request.app)throw new HttpsError('unauthenticated','Verified Auth and App Check are required.');
    const db=getFirestore(),release=await resolveFypRuntimeRelease(db);
    const input={app:{appId:request.app.appId},auth:{uid:request.auth.uid,token:request.auth.token},data:request.data};
    if(method==='command'&&typeof request.data?.operation==='string'&&request.data.operation.startsWith('admin.unified.'))return await createUnifiedAdminBackend({db,auth:getAuth(),release}).command(input);
    return await createFypDatasetBackend({db,auth:getAuth(),release})[method](input);
  }catch(e){const safe=recommendationCommandError(e);throw new HttpsError(safe.code,safe.message);}
});
export const fypDatasetSessionCommand=callable('session');
export const fypDatasetCommand=callable('command');
