import {describe,it,expect} from 'vitest';
import {MemoryStore} from './memory-store';
import {digestOf} from '../src/modules/workouts/workout-backup-validation';
import {parseModule13DemoManifest,authorizeModule13DemoActor,createOwnedDemoStore,DEMO_OPERATIONS} from '../src/modules/recommendation/demo-access-policy';
const source='orgs/gainpath/content/demo-m13-lesson-01';
const value={schemaVersion:1,status:'published'};
function fixture(){return{schemaVersion:1,seedId:'module13-full-demo-v1',projectId:'demo-gainpath-module13-demo',databaseId:'module13-demo',organizationId:'gainpath',enabled:true,adminIds:['demo-m13-admin'],memberIds:['demo-m13-member-01'],coachIds:['demo-m13-coach-01'],recordPaths:[source],recordDigests:{[source]:digestOf(value)},mutablePaths:[],noticePolicies:[],policyIds:[],inference:'structured_mock_only',createdAtMillis:1};}
describe('Module13 named-database server-owned demo boundary',()=>{
 it('requires exact named database manifest and refuses scope/enablement/role substitution',()=>{
  const f=fixture(),m=parseModule13DemoManifest(f,{projectId:f.projectId,databaseId:'module13-demo'});
  expect(authorizeModule13DemoActor(m,'demo-m13-member-01','member.inbox')).toBe('member');
  expect(()=>authorizeModule13DemoActor(m,'real-member','member.inbox')).toThrow();
  expect(()=>authorizeModule13DemoActor(m,'demo-m13-member-01','admin.queue.refresh')).toThrow();
  expect(()=>parseModule13DemoManifest({...f,databaseId:'(default)'},{projectId:f.projectId,databaseId:'module13-demo'})).toThrow();
  expect(()=>parseModule13DemoManifest({...f,enabled:false},{projectId:f.projectId,databaseId:'module13-demo'})).toThrow();
  expect(DEMO_OPERATIONS).toContain('member.workoutHistory');
 });
 it('reads only manifest-owned exact source records and validates immutable content',async()=>{
  const raw=new MemoryStore(),f=fixture();raw.documents.set('module13Demo/current',f);raw.documents.set(source,value);
  const store=createOwnedDemoStore(raw,parseModule13DemoManifest(f,{projectId:f.projectId,databaseId:'module13-demo'}));
  expect(await store.transact(tx=>tx.get(source))).toEqual(value);
  await expect(store.transact(tx=>tx.get('orgs/gainpath/content/real-content'))).rejects.toThrow();
  raw.documents.set(source,{...value,status:'withdrawn'});await expect(store.transact(tx=>tx.get(source))).rejects.toThrow();
 });
 it('atomically marks runtime records and refuses collision with unrelated records',async()=>{
  const raw=new MemoryStore(),f=fixture(),p='orgs/gainpath/recommendationRuns/'+'a'.repeat(64);raw.documents.set('module13Demo/current',f);
  const store=createOwnedDemoStore(raw,parseModule13DemoManifest(f,{projectId:f.projectId,databaseId:'module13-demo'}));
  await store.transact(async tx=>{expect(await tx.get(p)).toBeUndefined();tx.create(p,{schemaVersion:1});});
  expect(raw.documents.get(`module13DemoOwnership/${digestOf(p)}`)).toEqual({schemaVersion:1,seedId:f.seedId,path:p});
  const foreign='orgs/gainpath/recommendationRuns/'+'b'.repeat(64);raw.documents.set(foreign,{schemaVersion:1});
  await expect(store.transact(tx=>tx.get(foreign))).rejects.toThrow();
 });
 it('rejects current manifest withdrawal before output and unauthorized source writes',async()=>{
  const raw=new MemoryStore(),f=fixture();raw.documents.set('module13Demo/current',f);raw.documents.set(source,value);
  const store=createOwnedDemoStore(raw,parseModule13DemoManifest(f,{projectId:f.projectId,databaseId:'module13-demo'}));
  await expect(store.transact(async tx=>{tx.set(source,{changed:true});})).rejects.toThrow();
  raw.documents.set('module13Demo/current',{...f,enabled:false});await expect(store.transact(tx=>tx.get(source))).rejects.toThrow();
 });
});
