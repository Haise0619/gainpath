import {applicationDefault} from 'firebase-admin/app';
import {DomainError} from '../../platform/errors';
import type {GoogleVault} from './google-gym-connection';

/** Dynamically created per-connection secrets. No tokens in Firestore or logs. */
export class GoogleSecretVault implements GoogleVault {
 constructor(private project:string,private fetcher:typeof fetch=fetch,private credential=async()=> (await applicationDefault().getAccessToken()).access_token){}
 private async request(path:string,method:string,body?:unknown,allow404=false){
  if(!/^[\w-]+$/.test(this.project))throw new DomainError('failed-precondition','Secret project is not configured.');
  try{
   const token=await this.credential();
   const r=await this.fetcher(`https://secretmanager.googleapis.com/v1/projects/${this.project}/secrets${path.startsWith('?')?'':'/'}${path}`,{method,redirect:'error',signal:AbortSignal.timeout(10000),headers:{Authorization:'Bearer '+token,...(body?{'Content-Type':'application/json'}:{})},...(body?{body:JSON.stringify(body)}:{})});
   if(allow404&&r.status===404)return undefined;if(!r.ok)throw Error();return r.status===204?{}:await r.json();
  }catch{throw new DomainError('unavailable','Secure Google token storage is unavailable.');}
 }
 private id(id:string){if(!/^gainpath-google-[a-f0-9]{20}-[a-f0-9-]{36}$/.test(id))throw new DomainError('failed-precondition','Invalid Google secret reference.');return id;}
 async put(id:string,value:{refreshToken:string}){
  this.id(id);if(!value.refreshToken||value.refreshToken.length>10000)throw new DomainError('failed-precondition','Missing refresh grant.');
  await this.request(`?secretId=${encodeURIComponent(id)}`,'POST',{replication:{automatic:{}}});
  await this.request(`${id}:addVersion`,'POST',{payload:{data:Buffer.from(JSON.stringify(value)).toString('base64')}});
 }
 async read(id:string){const r=await this.request(`${this.id(id)}/versions/latest:access`,'GET') as any;
  try{const v=JSON.parse(Buffer.from(r.payload.data,'base64').toString());if(typeof v.refreshToken!=='string'||!v.refreshToken)throw Error();return{refreshToken:v.refreshToken as string};}catch{throw new DomainError('failed-precondition','Google refresh grant needs reconnection.');}}
 async destroy(id:string){await this.request(this.id(id),'DELETE',undefined,true);}
}
