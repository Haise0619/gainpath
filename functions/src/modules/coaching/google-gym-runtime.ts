import {getAuth} from 'firebase-admin/auth';
import {getFirestore} from 'firebase-admin/firestore';
import {defineSecret,defineString} from 'firebase-functions/params';
import {FirestoreStore} from '../../platform/firestore/firestore-store';
import type {DocumentStore} from '../../platform/firestore/store';
import {DomainError} from '../../platform/errors';
import {GymGoogleConnection} from './google-gym-connection';
import {GoogleGymProvider} from './google-gym-provider';
import {GoogleSecretVault} from './google-secret-vault';
export const googleGymClientSecret=defineSecret('GOOGLE_GYM_CLIENT_SECRET');
export const googleGymRuntimeAccount=defineString('GOOGLE_GYM_SERVICE_ACCOUNT');
export function googleGymServices(store:DocumentStore=new FirestoreStore(getFirestore())){
 if(!process.env.GOOGLE_GYM_SERVICE_ACCOUNT||!process.env.GOOGLE_GYM_ORGANIZATION_ID)throw new DomainError('failed-precondition','Configure the dedicated Google integration runtime and organization first.');
 const provider=new GoogleGymProvider(process.env.GOOGLE_GYM_CLIENT_ID??'',googleGymClientSecret.value());
 const connection=new GymGoogleConnection(store,new GoogleSecretVault(process.env.GCLOUD_PROJECT??''),provider,
 {clientId:process.env.GOOGLE_GYM_CLIENT_ID??'',gymEmail:process.env.GOOGLE_GYM_EMAIL??'',redirectUri:process.env.GOOGLE_GYM_REDIRECT_URI??'',organizationId:process.env.GOOGLE_GYM_ORGANIZATION_ID},Date.now,
 async(uid,authTime)=>{const u=await getAuth().getUser(uid);if(u.disabled||!u.emailVerified||authTime<Math.floor(new Date(u.tokensValidAfterTime??0).getTime()/1000))throw new DomainError('permission-denied','Sign in again before using Google integration.');});
 return{store,provider,connection};
}
