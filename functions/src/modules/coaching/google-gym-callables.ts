import {getAuth} from 'firebase-admin/auth';


import {onCall,onRequest,type CallableRequest} from 'firebase-functions/v2/https';

import {DomainError} from '../../platform/errors';
import {requiredIdentifier} from '../../platform/validation';
import {object,allowed} from './coach-availability-contracts';
import {coachCommandError} from './coach-profile-callables';
import {GymGoogleConnection,coachCalendarPath,gymConnectionPath,type GoogleActor} from './google-gym-connection';
import {GoogleGymProvider} from './google-gym-provider';

import {ensureCoachCalendar} from './gym-calendar-mapping';
import {GoogleBookingGateway} from './google-booking-delivery';
import {syncGymBooking} from './gym-booking-sync';

import {googleGymServices as services,googleGymClientSecret as clientSecret,googleGymRuntimeAccount as runtimeServiceAccount} from './google-gym-runtime';

/** Exported locally for an explicit future deployment only. */
export async function googleGymConnectionHandler(request:CallableRequest,dependencies?:{store:import('../../platform/firestore/store').DocumentStore;provider:GoogleGymProvider;connection:GymGoogleConnection}){
 try{
  if(!request.app||!request.auth)throw new DomainError('unauthenticated','Sign in with a verified GainPath app.');
  const d=object(request.data);allowed(d,['action','organizationId','coachId','confirmed']);const org=requiredIdentifier(d.organizationId,'organizationId'),auth=request.auth;
  const{store,provider,connection}=dependencies??services();
  if(d.action==='status')return await connection.status(auth,org,d.coachId===undefined?undefined:requiredIdentifier(d.coachId,'coachId'));
  if(d.action==='connect')return await connection.begin(auth,org);
  if(d.confirmed!==true)throw new DomainError('invalid-argument','Confirm the Google account operation first.');
  if(d.action==='disconnect')return await connection.disconnect(auth,org);
  if(d.action==='acknowledgeRevocation')return await connection.acknowledgeRevocation(auth,org);
  if(d.action==='createCalendar'){
   const coach=requiredIdentifier(d.coachId,'coachId');const name=await store.transact(async tx=>{await connection.authorize(tx,auth,org);const p=await tx.get(`orgs/${org}/coaches/${coach}`);if(p?.status!=='published'||typeof p.displayName!=='string'||!p.displayName.trim())throw new DomainError('failed-precondition','Publish the Coach profile before creating a calendar.');return p.displayName.slice(0,80);});
   const access=await connection.access(org);await ensureCoachCalendar(store,org,coach,access.subject,access.connectionId,async()=>{
    await store.transact(tx=>connection.authorize(tx,auth,org));return provider.createCalendar(access.accessToken,name);
   });return await connection.status(auth,org,coach);
  }
  throw new DomainError('invalid-argument','Unknown Google account operation.');
 }catch(error){throw coachCommandError(error);}
}
export const googleGymConnectionCommand=onCall({region:'us-central1',enforceAppCheck:true,secrets:[clientSecret],timeoutSeconds:60,serviceAccount:runtimeServiceAccount},request=>googleGymConnectionHandler(request));

/** Google cannot supply Firebase App Check; unguessable single-use state + PKCE binds this callback to a verified Admin. */
export const googleGymOAuthCallback=onRequest({region:'us-central1',secrets:[clientSecret],timeoutSeconds:60,serviceAccount:runtimeServiceAccount},async(req,res)=>{
 res.set({'Cache-Control':'no-store','Referrer-Policy':'no-referrer','Content-Security-Policy':"default-src 'none'; frame-ancestors 'none'",'X-Content-Type-Options':'nosniff'});
 if(req.method!=='GET'){res.status(405).send('Method not allowed.');return;}
 try{if(typeof req.query.state!=='string')throw Error();const connection=services().connection;if(req.query.error){await connection.deny(req.query.state);throw Error();}if(typeof req.query.code!=='string')throw Error();await connection.complete(req.query.state,req.query.code);res.status(200).type('text/plain').send('GainPath gym Google account connected. Close this tab and refresh Google integration in Admin.');}
 catch{res.status(400).type('text/plain').send('Google connection was not completed. Return to GainPath Admin and start again after checking the gym account and permissions.');}
});

export const syncGymBookingCommand=onCall({region:'us-central1',enforceAppCheck:true,secrets:[clientSecret],timeoutSeconds:90,serviceAccount:runtimeServiceAccount},async request=>{
 try{
  if(!request.app||!request.auth)throw new DomainError('unauthenticated','Sign in with a verified GainPath app.');
  const{store,connection}=services();const auth=request.auth as GoogleActor;
  // The gateway resolver receives canonical booking data only, never client-selected Calendar IDs, recipients or tokens.
  const gateway=new GoogleBookingGateway(async(kind,b)=>{
   await store.transact(tx=>connection.authorize(tx,auth,b.organizationId));const access=await connection.access(b.organizationId);
   const mapping=await store.transact(tx=>tx.get(coachCalendarPath(b.organizationId,b.coachId)));
   if(kind==='calendar'&&(mapping?.status!=='ready'||mapping.subject!==access.subject||mapping.coachId!==b.coachId||typeof mapping.calendarId!=='string'))throw new DomainError('failed-precondition','Create or reconcile this Coach calendar in Admin first.');
   return{accessToken:access.accessToken,senderEmail:access.senderEmail,assertCurrent:async()=>{await store.transact(async tx=>{const c=await tx.get(gymConnectionPath(b.organizationId));if(c?.status!=='connected'||c.secretId!==access.connectionId||c.subject!==access.subject)throw new DomainError('permission-denied','Google connection changed.');});},...(kind==='calendar'?{calendarId:String(mapping!.calendarId)}:{})};
  });
  return await syncGymBooking(store,auth,request.data,{gateway,
   authorize:async(org)=>{await store.transact(tx=>connection.authorize(tx,auth,org));await connection.access(org);},
   recipient:async uid=>{const u=await getAuth().getUser(uid);if(u.disabled||!u.emailVerified||!u.email)throw new DomainError('failed-precondition','The Member email is not verified.');return u.email;},
  });
 }catch(error){throw coachCommandError(error);}
});
