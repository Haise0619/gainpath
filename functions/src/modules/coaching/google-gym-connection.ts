import {createHash,randomBytes,randomUUID} from 'node:crypto';
import {DomainError} from '../../platform/errors';
import {requireVerifiedEmail} from '../../platform/auth-context';
import type {DocumentStore,TransactionPort,DocumentData} from '../../platform/firestore/store';
import {currentBookingMembership,requireBookingOrganization} from './booking-validation';
import {requiredIdentifier} from '../../platform/validation';
import {googleAutomationConfig} from './google-automation-config';
import {automaticScopeConfigured} from './automatic-google-delivery';

export const GOOGLE_SCOPES=['openid','email','https://www.googleapis.com/auth/calendar.app.created','https://www.googleapis.com/auth/gmail.send'];
export class GoogleGrantCleanupError extends DomainError {
 constructor(readonly revocationPending:boolean){super('failed-precondition','Google consent could not complete. Check gym account permissions before reconnecting.');}
}
export type GoogleActor={uid:string;token:Record<string,unknown>}|undefined;
export interface GoogleVault {put(id:string,value:{refreshToken:string}):Promise<void>;read(id:string):Promise<{refreshToken:string}>;destroy(id:string):Promise<void>}
export interface GymGoogleProvider {
 exchange(input:{code:string;verifier:string;redirectUri:string}):Promise<{refreshToken:string;accessToken:string;scope:string;subject:string;email:string;emailVerified:boolean}>;
 refresh(refreshToken:string):Promise<{accessToken:string}>;
 revoke(refreshToken:string):Promise<void>;
}
export const gymConnectionPath=(org:string)=>`system/googleGym/orgs/${org}`;
export const coachCalendarPath=(org:string,coach:string)=>`${gymConnectionPath(org)}/calendars/${coach}`;
const digest=(v:string)=>createHash('sha256').update(v).digest('hex');
const denied=()=>new DomainError('permission-denied','Current organization Admin access is required.');

/** All documents live below system: denied to every client by existing Rules. */
export class GymGoogleConnection {
 constructor(readonly store:DocumentStore,private vault:GoogleVault,private provider:GymGoogleProvider,
   readonly config:{clientId:string;redirectUri:string;gymEmail:string;organizationId?:string},private clock=Date.now,
   private identity?: (uid:string,authTime:number)=>Promise<void>){}
 async authorize(tx:TransactionPort,auth:GoogleActor,org:string,admin=true){
  requireVerifiedEmail(auth);requiredIdentifier(org,'organizationId');
  if(this.config.organizationId&&org!==this.config.organizationId)throw denied();
  if(this.identity)await this.identity(auth!.uid,Number(auth!.token.auth_time??0));
  const m=await currentBookingMembership(tx,org,auth!.uid);await requireBookingOrganization(tx,org);
  const user=await tx.get(`users/${auth!.uid}`),l=user?.accountLifecycle as DocumentData|undefined;
  if(l&&(l.state!=='active'||l.revocationPending!==false||!Number.isSafeInteger(l.sessionNotBeforeSeconds)||Number(auth!.token.auth_time??0)<Number(l.sessionNotBeforeSeconds)))throw denied();
  if(admin&&m.role!=='admin')throw denied();return m;
 }
 async begin(auth:GoogleActor,org:string){
  if(!this.config.clientId||!this.config.gymEmail||!this.config.redirectUri.startsWith('https://'))throw new DomainError('failed-precondition','Admin must configure Google OAuth first.');
  const state=randomBytes(32).toString('base64url'),verifier=randomBytes(48).toString('base64url'),attempt=randomUUID(),now=this.clock();
  await this.store.transact(async tx=>{await this.authorize(tx,auth,org);const old=await tx.get(gymConnectionPath(org));
   if(old?.status==='connected'||old?.revocationPending===true||old?.exchangeInFlight===true||old?.status==='needs_reconnect'&&typeof old.secretId==='string')throw new DomainError('failed-precondition','Disconnect or resolve the existing Google grant first.');
   if(old?.status==='connecting'&&Number(old.expiresAtMillis)>now)throw new DomainError('failed-precondition','Finish the current Google connection or wait for it to expire.');
   tx.set(gymConnectionPath(org),{...old,status:'connecting',attempt,pendingExchangeAttempt:'',exchangeInFlight:false,expiresAtMillis:now+600000});
   tx.create(`system/googleOAuth/states/${digest(state)}`,{org,uid:auth!.uid,authTime:auth!.token.auth_time??0,verifier,attempt,status:'pending',expiresAtMillis:now+600000});
  });
  const url=new URL('https://accounts.google.com/o/oauth2/v2/auth');url.search=new URLSearchParams({client_id:this.config.clientId,redirect_uri:this.config.redirectUri,response_type:'code',scope:GOOGLE_SCOPES.join(' '),state,code_challenge:createHash('sha256').update(verifier).digest('base64url'),code_challenge_method:'S256',access_type:'offline',prompt:'consent',login_hint:this.config.gymEmail,include_granted_scopes:'false'}).toString();
  return{authorizationUrl:url.toString(),expiresAtMillis:now+600000};
 }
 async complete(state:string,code:string){
  if(!/^[\w-]{43}$/.test(state)||!code||code.length>4096)throw new DomainError('invalid-argument','Invalid Google callback.');
  const path=`system/googleOAuth/states/${digest(state)}`,now=this.clock();
  const pending=await this.store.transact(async tx=>{
   const p=await tx.get(path);if(!p||p.status!=='pending'||Number(p.expiresAtMillis)<=now)throw new DomainError('failed-precondition','Google consent expired or was already used.');
   await this.authorize(tx,{uid:String(p.uid),token:{email_verified:true,auth_time:p.authTime}},String(p.org));
   const c=await tx.get(gymConnectionPath(String(p.org)));if(c?.status!=='connecting'||c.attempt!==p.attempt)throw denied();
   tx.set(path,{org:p.org,uid:p.uid,attempt:p.attempt,status:'consumed',expiresAtMillis:p.expiresAtMillis});
   tx.set(gymConnectionPath(String(p.org)),{...c,exchangeInFlight:true,exchangeLeaseUntilMillis:now+300000,pendingExchangeAttempt:p.attempt});return p;
  });
  const org=String(pending.org),secretId=`gainpath-google-${digest(org).slice(0,20)}-${pending.attempt}`;
  let written=false,issuedRefresh:string|undefined;
  try{
   const grant=await this.provider.exchange({code,verifier:String(pending.verifier),redirectUri:this.config.redirectUri});
   issuedRefresh=grant.refreshToken||grant.accessToken;
   const scopes=new Set(grant.scope.split(' ').filter(Boolean).map(s=>s==='https://www.googleapis.com/auth/userinfo.email'?'email':s));
   if(!grant.emailVerified||grant.email.toLowerCase()!==this.config.gymEmail.toLowerCase()||!grant.subject||!grant.refreshToken||scopes.size!==GOOGLE_SCOPES.length||GOOGLE_SCOPES.some(s=>!scopes.has(s)))throw denied();
   await this.store.transact(async tx=>{await this.authorize(tx,{uid:String(pending.uid),token:{email_verified:true,auth_time:pending.authTime}},org);const c=await tx.get(gymConnectionPath(org));if(!c||c.attempt!==pending.attempt||c.status!=='connecting'||(c.subject&&c.subject!==grant.subject))throw denied();});
   written=true;await this.vault.put(secretId,{refreshToken:grant.refreshToken});
   await this.store.transact(async tx=>{await this.authorize(tx,{uid:String(pending.uid),token:{email_verified:true,auth_time:pending.authTime}},org);const c=await tx.get(gymConnectionPath(org));if(!c||c.attempt!==pending.attempt||c.status!=='connecting')throw denied();
    tx.set(gymConnectionPath(org),{...c,schemaVersion:1,status:'connected',subject:grant.subject,senderEmail:grant.email,secretId,connectedAtMillis:this.clock(),scopes:GOOGLE_SCOPES,revocationPending:false,exchangeInFlight:false});});
  }catch(error){
   let revocationPending=error instanceof GoogleGrantCleanupError&&error.revocationPending,cleanupPending=false;
   if(issuedRefresh)try{await this.provider.revoke(issuedRefresh);}catch{revocationPending=true;}
   if(written)try{await this.vault.destroy(secretId);}catch{cleanupPending=true;revocationPending=true;}
   await this.store.transact(async tx=>{const c=await tx.get(gymConnectionPath(org));if(c&&c.pendingExchangeAttempt===pending.attempt)tx.set(gymConnectionPath(org),{...c,status:c.status==='disconnected'?'disconnected':'needs_reconnect',exchangeInFlight:false,revocationPending,...(cleanupPending?{cleanupSecretId:secretId}:{})});});
   throw new DomainError('failed-precondition','Google connection failed. Check the gym account, scopes and Admin access, then start again.');
  }
 }
 async status(auth:GoogleActor,org:string,coachId?:string){
  if(coachId)requiredIdentifier(coachId,'coachId');
  return this.store.transact(async tx=>{const m=await this.authorize(tx,auth,org,false);if(m.role!=='admin'&&(m.role!=='coach'||coachId!==auth!.uid))throw denied();
   const c=await tx.get(gymConnectionPath(org)),calendar=coachId?await tx.get(coachCalendarPath(org,coachId)):undefined;
   const abandoned=c?.exchangeInFlight===true&&Number.isSafeInteger(c.exchangeLeaseUntilMillis)&&Number(c.exchangeLeaseUntilMillis)<=this.clock();
   const state=abandoned||c?.status==='connecting'&&Number(c.expiresAtMillis)<=this.clock()?'needs_reconnect':String(c?.status??'disconnected');
   const automation=googleAutomationConfig(),automationEnabled=automation.organizationId===org&&automaticScopeConfigured(automation);
   return{schemaVersion:1,connectionStatus:state,calendarStatus:String(calendar?.status??'not_created'),revocationPending:c?.revocationPending===true||abandoned,automationEnabled,automationStatus:String(c?.automaticLastStatus??'not_started'),emailSyncStatus:String(calendar?.lastEmailDeliveryStatus??'not_sent'),
    syncStatus:String(calendar?.lastDeliveryStatus??'not_synced'),...(m.role==='admin'&&c?.senderEmail?{senderEmail:String(c.senderEmail)}:{}),...(calendar?.lastSyncedAtMillis?{lastSyncedAtMillis:calendar.lastSyncedAtMillis}:{})};
  });
 }
 async deny(state:string){
  if(!/^[\w-]{43}$/.test(state))throw denied();const path=`system/googleOAuth/states/${digest(state)}`;
  await this.store.transact(async tx=>{const p=await tx.get(path);if(!p||p.status!=='pending'||Number(p.expiresAtMillis)<=this.clock())throw denied();
   const c=await tx.get(gymConnectionPath(String(p.org)));if(c?.attempt!==p.attempt||c?.status!=='connecting')throw denied();
   tx.set(path,{org:p.org,uid:p.uid,attempt:p.attempt,status:'denied',expiresAtMillis:p.expiresAtMillis});tx.set(gymConnectionPath(String(p.org)),{...c,status:'needs_reconnect'});
  });
 }
 async access(org:string){
  const c=await this.store.transact(async tx=>{await requireBookingOrganization(tx,org);const c=await tx.get(gymConnectionPath(org));if(c?.status!=='connected'||typeof c.secretId!=='string'||typeof c.subject!=='string')throw new DomainError('failed-precondition','The gym Google account needs connection.');return c;});
  try{
   const token=await this.provider.refresh((await this.vault.read(String(c.secretId))).refreshToken);
   await this.store.transact(async tx=>{const current=await tx.get(gymConnectionPath(org));if(current?.status!=='connected'||current.secretId!==c.secretId)throw denied();});
   return{...token,subject:String(c.subject),senderEmail:String(c.senderEmail),connectionId:String(c.secretId)};
  }catch(error){if(error instanceof DomainError&&error.code==='failed-precondition')await this.store.transact(async tx=>{const current=await tx.get(gymConnectionPath(org));if(current&&current.secretId===c.secretId&&current.status==='connected')tx.set(gymConnectionPath(org),{...current,status:'needs_reconnect'});});throw new DomainError('unavailable','Google access is unavailable. Check connection status and retry later.');}
 }
 async disconnect(auth:GoogleActor,org:string){
  const c=await this.store.transact(async tx=>{await this.authorize(tx,auth,org);const c=await tx.get(gymConnectionPath(org));tx.set(gymConnectionPath(org),{...c,status:'disconnected',attempt:randomUUID(),revocationPending:!!c?.secretId||c?.exchangeInFlight===true||c?.revocationPending===true});return c;});
  let pending=c?.exchangeInFlight===true||c?.revocationPending===true;
  if(c?.secretId){try{await this.provider.revoke((await this.vault.read(String(c.secretId))).refreshToken);}catch{pending=true;}
   try{await this.vault.destroy(String(c.secretId));}catch{pending=true;}
  }
  await this.store.transact(async tx=>{const current=await tx.get(gymConnectionPath(org));if(current?.status==='disconnected'){
   // Callback cleanup owns its in-flight outcome; never overwrite it with an older disconnect snapshot.
   if(c?.exchangeInFlight===true&&current.exchangeInFlight===false)return;
   if(!pending){const {secretId:_,...rest}=current;tx.set(gymConnectionPath(org),{...rest,revocationPending:false});}else tx.set(gymConnectionPath(org),{...current,revocationPending:true});
  }});
  return{disconnected:true,revocationPending:pending};
 }
 async acknowledgeRevocation(auth:GoogleActor,org:string){
  const prior=await this.store.transact(async tx=>{await this.authorize(tx,auth,org);const c=await tx.get(gymConnectionPath(org));
   const abandoned=c?.exchangeInFlight===true&&Number.isSafeInteger(c.exchangeLeaseUntilMillis)&&Number(c.exchangeLeaseUntilMillis)<=this.clock();
   if(!c||!abandoned&&(!['disconnected','needs_reconnect'].includes(String(c.status))||c.revocationPending!==true||c.exchangeInFlight===true))throw new DomainError('failed-precondition','No pending disconnection is ready for acknowledgement. Wait for the consent exchange lease before recovery.');return c;});
  const cleanup=prior.cleanupSecretId??prior.secretId??(prior.exchangeInFlight===true?`gainpath-google-${digest(org).slice(0,20)}-${prior.pendingExchangeAttempt}`:undefined);
  if(typeof cleanup==='string')await this.vault.destroy(cleanup);
  await this.store.transact(async tx=>{await this.authorize(tx,auth,org);const c=await tx.get(gymConnectionPath(org));if(!c||c.attempt!==prior.attempt||c.status!==prior.status||c.exchangeInFlight!==prior.exchangeInFlight||c.revocationPending!==prior.revocationPending)throw denied();
   const {secretId:_,cleanupSecretId:__,...rest}=c;
   tx.set(gymConnectionPath(org),{...rest,status:'disconnected',attempt:randomUUID(),pendingExchangeAttempt:'',exchangeInFlight:false,revocationPending:false,revocationAcknowledgedBy:auth!.uid,revocationAcknowledgedAtMillis:this.clock()});});
  return{acknowledged:true};
 }
}
