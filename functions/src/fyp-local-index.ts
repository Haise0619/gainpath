/** Dedicated emulator entrypoint ONLY. Production src/index.ts does not import it. */
import {initializeApp,getApps} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {getAuth} from 'firebase-admin/auth';
import {onCall,HttpsError} from 'firebase-functions/v2/https';
import {createFypDatasetBackend} from './modules/dataset/fyp-backend';
import {recommendationCommandError} from './modules/recommendation/recommendation-configuration';
import {createUnifiedAdminBackend} from './modules/dataset/unified-admin-backend';
if(!getApps().length)initializeApp();
const options={region:'asia-southeast1',enforceAppCheck:true,timeoutSeconds:540,maxInstances:1,concurrency:4} as const;
const callable=(method:'session'|'command')=>onCall(options,async request=>{
  try{const input={app:request.app?{appId:request.app.appId}:undefined,auth:request.auth?{uid:request.auth.uid,token:request.auth.token}:undefined,data:request.data};
    if(method==='command'&&typeof request.data?.operation==='string'&&request.data.operation.startsWith('admin.unified.'))return await createUnifiedAdminBackend({db:getFirestore(),auth:getAuth()}).command(input);
    return await createFypDatasetBackend({db:getFirestore(),auth:getAuth()})[method](input);}
  catch(e){const error=recommendationCommandError(e);throw new HttpsError(error.code,error.message);}
});
export const fypDatasetSessionCommand=callable('session');
export const fypDatasetCommand=callable('command');
// Actual legacy endpoints are loaded ONLY in this emulator package to prove
// assigned actors cannot acquire canonical authority through older clients.
export {provisionMemberRegistration} from './modules/identity/provision-member-registration';
export {adminReportingCommand} from './modules/analytics/admin-reporting-callable';
export {getCoachAvailabilityCommand} from './modules/coaching/coach-availability-callables';
export {listAdminBookingPaymentsCommand} from './modules/commerce/booking-payment-admin-callables';
export {getMembershipAccessCommand} from './modules/commerce/membership-access-callables';
export {verifiedRewardsCommand} from './modules/gamification/verified-rewards-callables';
export {miniGameRoundCommand} from './modules/gamification/mini-game-round-callable';
