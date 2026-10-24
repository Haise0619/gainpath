import {DomainError} from '../../platform/errors';
import {GoogleGrantCleanupError,type GymGoogleProvider} from './google-gym-connection';
const unavailable=()=>new DomainError('unavailable','Google could not confirm the operation. Check connection status.');
export class GoogleGymProvider implements GymGoogleProvider {
 constructor(private clientId:string,private clientSecret:string,private fetcher:typeof fetch=fetch){}
 private async token(body:Record<string,string>){
  let r:Response;try{r=await this.fetcher('https://oauth2.googleapis.com/token',{method:'POST',redirect:'error',signal:AbortSignal.timeout(15000),headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({...body,client_id:this.clientId,client_secret:this.clientSecret})});}catch{if(body.grant_type==='authorization_code')throw new GoogleGrantCleanupError(true);throw unavailable();}
  const value=await r.json().catch(()=>({})) as any;
  if(!r.ok){if(value.error==='invalid_grant')throw new DomainError('failed-precondition','Google authorization expired or was revoked. Reconnect the gym account.');throw unavailable();}
  if(typeof value.access_token!=='string'||!value.access_token){if(body.grant_type==='authorization_code')throw new GoogleGrantCleanupError(true);throw unavailable();}return value;
 }
 async exchange(input:{code:string;verifier:string;redirectUri:string}){
  const t=await this.token({grant_type:'authorization_code',code:input.code,code_verifier:input.verifier,redirect_uri:input.redirectUri});
  try{
   const r=await this.fetcher('https://openidconnect.googleapis.com/v1/userinfo',{headers:{Authorization:'Bearer '+t.access_token},redirect:'error',signal:AbortSignal.timeout(10000)});
   if(!r.ok)throw unavailable();const u=await r.json() as any;
   return{refreshToken:typeof t.refresh_token==='string'?t.refresh_token:'',accessToken:t.access_token as string,scope:typeof t.scope==='string'?t.scope:'',subject:typeof u.sub==='string'?u.sub:'',email:typeof u.email==='string'?u.email:'',emailVerified:u.email_verified===true};
  }catch{
   let pending=false;try{await this.revoke(typeof t.refresh_token==='string'?t.refresh_token:t.access_token);}catch{pending=true;}
   throw new GoogleGrantCleanupError(pending);
  }
 }
 async refresh(refreshToken:string){const t=await this.token({grant_type:'refresh_token',refresh_token:refreshToken});return{accessToken:t.access_token as string};}
 async revoke(refreshToken:string){let r:Response;try{r=await this.fetcher('https://oauth2.googleapis.com/revoke',{method:'POST',redirect:'error',signal:AbortSignal.timeout(10000),headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({token:refreshToken})});}catch{throw unavailable();}if(!r.ok)throw unavailable();}
 async createCalendar(accessToken:string,coachName:string){
  let r:Response;try{r=await this.fetcher('https://www.googleapis.com/calendar/v3/calendars',{method:'POST',redirect:'error',signal:AbortSignal.timeout(10000),headers:{Authorization:'Bearer '+accessToken,'Content-Type':'application/json'},body:JSON.stringify({summary:`GainPath — ${coachName}`,description:'Managed by GainPath. Availability and bookings are maintained in GainPath.',timeZone:'Asia/Kuala_Lumpur'})});}catch{throw unavailable();}
  if(!r.ok)throw unavailable();const v=await r.json() as any;if(typeof v.id!=='string'||!v.id||v.id.length>512)throw unavailable();return{calendarId:v.id};
 }
}
