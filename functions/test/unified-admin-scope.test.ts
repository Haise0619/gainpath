import {expect,it} from 'vitest';
import {MemoryStore} from './memory-store';
import {fypDigest} from '../src/modules/dataset/fyp-integrity';
import {UNIFIED_ADMIN_GATE} from '../src/modules/dataset/unified-admin-scope';
import {resolveFypAdminReadScope,createFypScopedStore,mintFypRuntimeCapability,requireFypObservationScope} from '../src/modules/dataset/fyp-scope';
const uid='canonical-admin';
const request={app:{appId:'verified-app'},auth:{uid,token:{email:'admin@example.invalid',email_verified:true,auth_time:100}},data:{schemaVersion:1}};
const identity=async()=>({uid,email:'admin@example.invalid',emailVerified:true,disabled:false,creationTimeMillis:1000,tokensValidAfterMillis:0});
function fixture(){const store=new MemoryStore();store.documents.set('orgs/gainpath',{status:'active'});
 store.documents.set('users/'+uid,{organizationId:'gainpath',role:'admin'});
 store.documents.set('orgs/gainpath/members/'+uid,{organizationId:'gainpath',userId:uid,role:'admin',status:'active',branchIds:['main']});
 store.documents.set('orgs/gainpath/cohorts/fyp-v1',{schemaVersion:1,organizationId:'gainpath',datasetId:'fyp-v1',seedId:'gainpath-fyp-v1',enabled:true,status:'active'});
 store.documents.set('orgs/gainpath/adminDataIntegrations/fyp-v1',{schemaVersion:1,organizationId:'gainpath',cohortId:'fyp-v1',rootPath:'orgs/gainpath/cohorts/fyp-v1',enabled:true,version:'unified-admin-v1'});
 store.documents.set('orgs/gainpath/cohorts/fyp-v1/unifiedSampleOwnership/'+fypDigest(UNIFIED_ADMIN_GATE),{schemaVersion:1,seedId:'unified-admin-business-v1',path:UNIFIED_ADMIN_GATE,digest:fypDigest(store.documents.get(UNIFIED_ADMIN_GATE))});
 store.documents.set('orgs/gainpath/cohorts/fyp-v1/members/fictional',{organizationId:'gainpath',role:'member'});return store;}
it('rejects a copied gate without exact ownership and revalidates ownership after reads',async()=>{const store=fixture(),path='orgs/gainpath/cohorts/fyp-v1/unifiedSampleOwnership/'+fypDigest(UNIFIED_ADMIN_GATE),scope=await resolveFypAdminReadScope(request,{store,identity});store.documents.delete(path);await expect(resolveFypAdminReadScope(request,{store,identity})).rejects.toThrow();await expect(createFypScopedStore(store,scope).transact(tx=>tx.get('orgs/gainpath/members/fictional'))).rejects.toThrow();});
it('mints immutable canonical Admin read authority without dataset assignment or impersonation',async()=>{
 const store=fixture(),scope=await resolveFypAdminReadScope(request,{store,identity});expect(scope.uid).toBe(uid);expect(scope.role).toBe('admin');expect(Object.isFrozen(scope)).toBe(true);
 const bound=createFypScopedStore(store,scope);expect(await bound.transact(tx=>tx.get('users/'+uid))).toEqual(store.documents.get('users/'+uid));
 expect(await bound.transact(tx=>tx.get('orgs/gainpath/members/fictional'))).toMatchObject({role:'member'});
 expect(()=>requireFypObservationScope(mintFypRuntimeCapability(scope),'gainpath','fictional')).not.toThrow();
 for(const action of ['create','set'] as const)await expect(bound.transact(async tx=>{tx[action]('orgs/gainpath/recommendationLeads/new',{status:'prepared'});})).rejects.toMatchObject({code:'permission-denied'});
 expect(store.documents.has('orgs/gainpath/cohorts/fyp-v1/recommendationLeads/new')).toBe(false);
});
it.each(['member','coach','staff'])('denies canonical %s and dataset-assigned accounts',async role=>{
 const store=fixture();store.documents.set('orgs/gainpath/members/'+uid,{organizationId:'gainpath',role,status:'active',branchIds:['main']});
 await expect(resolveFypAdminReadScope(request,{store,identity})).rejects.toMatchObject({code:'permission-denied'});
});
it('denies missing attestation, foreign organizations, stale sessions and disabled/recreated identities',async()=>{
 for(const incoming of [{...request,app:undefined},{...request,auth:undefined},{...request,data:{schemaVersion:1,rootPath:'other'}}])await expect(resolveFypAdminReadScope(incoming,{store:fixture(),identity})).rejects.toThrow();
 for(const patch of [{disabled:true},{emailVerified:false},{tokensValidAfterMillis:101000},{email:'other@example.invalid'}])await expect(resolveFypAdminReadScope(request,{store:fixture(),identity:async()=>({...await identity(),...patch})})).rejects.toThrow();
 const store=fixture();store.documents.set('users/'+uid,{organizationId:'foreign',role:'admin'});await expect(resolveFypAdminReadScope(request,{store,identity})).rejects.toThrow();
});
it('defaults off, refuses any FYP assignment and revalidates canonical membership/integration each transaction',async()=>{
 for(const path of ['orgs/gainpath/adminDataIntegrations/fyp-v1','orgs/gainpath/cohorts/fyp-v1']){const store=fixture();store.documents.delete(path);await expect(resolveFypAdminReadScope(request,{store,identity})).rejects.toThrow();}
 const assigned=fixture();assigned.documents.set('datasetAssignments/'+uid,{enabled:false});await expect(resolveFypAdminReadScope(request,{store:assigned,identity})).rejects.toThrow();
 for(const path of ['orgs/gainpath/members/'+uid,'orgs/gainpath/adminDataIntegrations/fyp-v1']){const store=fixture(),scope=await resolveFypAdminReadScope(request,{store,identity});store.documents.set(path,{...store.documents.get(path),status:'inactive',enabled:false});await expect(createFypScopedStore(store,scope).transact(tx=>tx.get('orgs/gainpath/members/fictional'))).rejects.toThrow();}
});
it('denies a revoked lifecycle and serialized authority',async()=>{
 const store=fixture();store.documents.set('users/'+uid,{organizationId:'gainpath',role:'admin',accountLifecycle:{schemaVersion:1,state:'active',revocationPending:false,sessionNotBeforeSeconds:101}});
 await expect(resolveFypAdminReadScope(request,{store,identity})).rejects.toThrow();
 const scope=await resolveFypAdminReadScope(request,{store:fixture(),identity});expect(()=>createFypScopedStore(store,JSON.parse(JSON.stringify(scope)))).toThrow();
});
