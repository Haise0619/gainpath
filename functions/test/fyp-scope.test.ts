import {expect, it} from 'vitest';
import {MemoryStore} from './memory-store';
import {resolveFypScope, createFypScopedStore, logicalFypPath} from '../src/modules/dataset/fyp-scope';
import {fypDigest} from '../src/modules/dataset/fyp-dataset';
const uid='fictional', created=1000, now=200000;
const incoming={app:{appId:'test-app'},auth:{uid,token:{email:'fictional@example.invalid',email_verified:true,auth_time:100,fypAuthCreatedAtMillis:created}},data:{schemaVersion:1}};
function fixture(){const store=new MemoryStore();store.documents.set(`datasetAssignments/${uid}`,{schemaVersion:1,datasetId:'fyp-v1',organizationId:'gainpath',seedId:'gainpath-fyp-v1',role:'member',revision:1,enabled:true,authCreatedAtMillis:created});
store.documents.set('orgs/gainpath/cohorts/fyp-v1',{schemaVersion:1,datasetId:'fyp-v1',organizationId:'gainpath',seedId:'gainpath-fyp-v1',enabled:true,status:'active'});
for(const p of ['users','members'])store.documents.set(`orgs/gainpath/cohorts/fyp-v1/${p}/${uid}`,{organizationId:'gainpath',userId:uid,role:'member',status:'active',branchIds:['main']});return store;}
const identity=async()=>({uid,email:'fictional@example.invalid',emailVerified:true,disabled:false,creationTimeMillis:created,tokensValidAfterMillis:0});
it('derives immutable scope from current assignment and reads only scoped logical paths',async()=>{const store=fixture(),scope=await resolveFypScope(incoming,{store,identity,clock:()=>now});expect(Object.isFrozen(scope)).toBe(true);expect(scope.role).toBe('member');
const bound=createFypScopedStore(store,scope);expect(await bound.transact(tx=>tx.get(`users/${uid}`))).toMatchObject({role:'member'});
expect(logicalFypPath(scope,'orgs/gainpath/coaches/id')).toBe('orgs/gainpath/cohorts/fyp-v1/coaches/id');
for(const p of ['users/../real','orgs/foreign/members/id','orgs/gainpath/cohorts/other/members/id','datasetAssignments/id'])expect(()=>logicalFypPath(scope,p)).toThrow();});
it('rejects forged client scope, missing App Check and recreated/revoked identities',async()=>{const store=fixture();for(const patch of [{app:undefined},{auth:undefined}])await expect(resolveFypScope({...incoming,...patch},{store,identity})).rejects.toThrow();
await expect(resolveFypScope({...incoming,data:{schemaVersion:1,cohortId:'fyp-v1'}},{store,identity})).rejects.toThrow();
await expect(resolveFypScope(incoming,{store,identity:async()=>({...await identity(),creationTimeMillis:2000})})).rejects.toThrow();
const scope=await resolveFypScope(incoming,{store,identity});store.documents.set(`datasetAssignments/${uid}`,{...store.documents.get(`datasetAssignments/${uid}`),enabled:false});await expect(createFypScopedStore(store,scope).transact(tx=>tx.get(`users/${uid}`))).rejects.toThrow();});
it('ordinary unassigned accounts receive no cohort capability',async()=>{await expect(resolveFypScope(incoming,{store:new MemoryStore(),identity})).rejects.toMatchObject({code:'permission-denied'});});
it.each([`users/${uid}`,`orgs/gainpath/members/${uid}`])('refuses mixed canonical/cohort identity at %s',async path=>{
 const store=fixture();store.documents.set(path,{role:'admin',organizationId:'gainpath'});await expect(resolveFypScope(incoming,{store,identity})).rejects.toThrow();
});
it('denies a deactivating lifecycle before minting a dataset scope',async()=>{
 const store=fixture();store.documents.set(`orgs/gainpath/cohorts/fyp-v1/users/${uid}`,{organizationId:'gainpath',role:'member',status:'active',accountLifecycle:{schemaVersion:1,state:'pendingDeletion',revocationPending:true,sessionNotBeforeSeconds:0}});
 await expect(resolveFypScope(incoming,{store,identity})).rejects.toThrow();
});
it('invalidates an immutable request scope when branch authority changes',async()=>{
 const store=fixture(),scope=await resolveFypScope(incoming,{store,identity});store.documents.set(`orgs/gainpath/cohorts/fyp-v1/members/${uid}`,{...store.documents.get(`orgs/gainpath/cohorts/fyp-v1/members/${uid}`),branchIds:['other']});
 await expect(createFypScopedStore(store,scope).transact(tx=>tx.get(`users/${uid}`))).rejects.toThrow();
});
it('atomically records exact generated ownership and refuses unowned collisions',async()=>{
 const store=fixture(),scope=await resolveFypScope(incoming,{store,identity}),bound=createFypScopedStore(store,scope),path='orgs/gainpath/notifications/notice',physical='orgs/gainpath/cohorts/fyp-v1/notifications/notice';
 await bound.transact(async tx=>tx.create(path,{recipientId:uid,read:false}));
 const registry=`orgs/gainpath/cohorts/fyp-v1/generatedOwnership/${fypDigest(physical)}`;
 expect(store.documents.get(registry)).toMatchObject({seedId:'gainpath-fyp-v1',path:physical,digest:fypDigest({recipientId:uid,read:false})});
 store.documents.set('orgs/gainpath/cohorts/fyp-v1/notifications/unowned',{recipientId:uid,read:false});const before=structuredClone([...store.documents]);
 await expect(bound.transact(async tx=>tx.set('orgs/gainpath/notifications/unowned',{recipientId:uid,read:true}))).rejects.toThrow();expect([...store.documents]).toEqual(before);
});
it('never overwrites a foreign generated registry beside a valid seeded source',async()=>{
 const store=fixture(),scope=await resolveFypScope(incoming,{store,identity}),path='orgs/gainpath/notifications/source',physical='orgs/gainpath/cohorts/fyp-v1/notifications/source',data={recipientId:uid,read:false},key=fypDigest(physical);
 store.documents.set(physical,data);store.documents.set(`orgs/gainpath/cohorts/fyp-v1/seedOwnership/${key}`,{schemaVersion:1,seedId:scope.seedId,path:physical,digest:fypDigest(data)});
 store.documents.set(`orgs/gainpath/cohorts/fyp-v1/generatedOwnership/${key}`,{schemaVersion:1,seedId:'foreign',path:physical,preserve:true});const before=structuredClone([...store.documents]);
 await expect(createFypScopedStore(store,scope).transact(async tx=>tx.set(path,{...data,read:true}))).rejects.toThrow();expect([...store.documents]).toEqual(before);
});
