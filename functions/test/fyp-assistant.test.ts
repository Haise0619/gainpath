import {expect,it} from 'vitest';
import {parseFypEnvelope} from '../src/modules/dataset/fyp-backend';
import {createFypAssistantFirestore} from '../src/modules/dataset/fyp-assistant';
import {resolveFypScope,createFypScopedStore} from '../src/modules/dataset/fyp-scope';
import {MemoryStore} from './memory-store';
import {fitnessAssistantHandler} from '../src/modules/chatbot/chatbot-callable';
const uid='fictional',root='orgs/gainpath/cohorts/fyp-v1';
const incoming={app:{appId:'fixture'},auth:{uid,token:{email:'f@example.invalid',email_verified:true,auth_time:100,fypAuthCreatedAtMillis:1000}},data:{schemaVersion:1}};
async function fixture(){
 const base=new MemoryStore();base.documents.set(`datasetAssignments/${uid}`,{schemaVersion:1,datasetId:'fyp-v1',organizationId:'gainpath',seedId:'gainpath-fyp-v1',role:'member',revision:1,enabled:true,authCreatedAtMillis:1000});
 base.documents.set(root,{schemaVersion:1,datasetId:'fyp-v1',organizationId:'gainpath',seedId:'gainpath-fyp-v1',enabled:true,status:'active'});
 for(const p of ['users','members'])base.documents.set(`${root}/${p}/${uid}`,{organizationId:'gainpath',userId:uid,role:'member',status:'active',branchIds:['main']});
 const scope=await resolveFypScope(incoming,{store:base,identity:async()=>({uid,email:'f@example.invalid',emailVerified:true,disabled:false,creationTimeMillis:1000,tokensValidAfterMillis:0})});
 return{base,scope,store:createFypScopedStore(base,scope)};
}
it('registers bounded Assistant and membership reads without accepting scope fields',()=>{
 expect(parseFypEnvelope({schemaVersion:1,operation:'member.assistant',data:{action:'bootstrap'}}).operation).toBe('member.assistant');
 expect(parseFypEnvelope({schemaVersion:1,operation:'module/getMembershipOverviewCommand',data:{schemaVersion:1}}).operation).toBe('module/getMembershipOverviewCommand');
 expect(()=>parseFypEnvelope({schemaVersion:1,operation:'member.assistant',data:{action:'bootstrap',rootPath:'foreign'}})).toThrow();
});
it('routes state through owned cohort store and rejects other member writes and assignment revocation',async()=>{
 const f=await fixture();const adapter=createFypAssistantFirestore({scope:f.scope,store:f.store,db:{} as never,readNotice:async()=>({text:'Approved',revision:1,isActive:true})});
 const state=`orgs/gainpath/members/${uid}/chatbot/state`;
 await adapter.runTransaction(async(tx:any)=>{expect((await tx.get(adapter.doc(`users/${uid}`))).data().userId).toBe(uid);tx.set(adapter.doc(state),{schemaVersion:1,acknowledgedRevision:1});});
 expect(f.base.documents.get(`${root}/members/${uid}/chatbot/state`)).toMatchObject({acknowledgedRevision:1});expect(f.base.documents.has(state)).toBe(false);
 await expect(adapter.runTransaction(async(tx:any)=>tx.set(adapter.doc('orgs/gainpath/members/other/chatbot/state'),{}))).rejects.toThrow();
 f.base.documents.get(`datasetAssignments/${uid}`)!.enabled=false;
 await expect(adapter.runTransaction(async(tx:any)=>tx.get(adapter.doc(`users/${uid}`)))).rejects.toThrow();
 expect(()=>adapter.collection('orgs/foreign/coaches')).toThrow();
});
it('uses the same disclaimer, saved advice and generated response guards for a scoped FYP Member',async()=>{
 const f=await fixture(),db=createFypAssistantFirestore({scope:f.scope,store:f.store,db:{} as never,readNotice:async()=>({text:'Shared approved notice',revision:4,isActive:true})});
 const call=(data:object,fetcher?:typeof fetch)=>fitnessAssistantHandler({...incoming,data:{organizationId:'gainpath',...data}} as never,{db:db as never,fypScopeHandled:true,apiKey:'offline-fixture',fetcher});
 expect(await call({action:'bootstrap'})).toMatchObject({acknowledged:false,disclaimer:{revision:4}});
 await call({action:'acknowledge',disclaimerRevision:4});
 const fetcher=async()=>({ok:true,json:async()=>({candidates:[{content:{parts:[{text:'Warm up gently.'}]}}]})});
 expect(await call({action:'reply',text:'Explain a warmup'},fetcher as never)).toMatchObject({text:'Warm up gently.',telemetry:{providerRequests:1}});
 await call({action:'bookmark',text:'Warm up gently.'});
 expect(await call({action:'bootstrap'})).toMatchObject({acknowledged:true,bookmarks:['Warm up gently.']});
 expect(f.base.documents.has(`orgs/gainpath/members/${uid}/chatbot/state`)).toBe(false);
 const revoke=async()=>{f.base.documents.get(`datasetAssignments/${uid}`)!.enabled=false;return fetcher();};
 await expect(call({action:'reply',text:'Explain stretching'},revoke as never)).rejects.toBeDefined();
});
