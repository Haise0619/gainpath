import {readFileSync} from 'node:fs';
import {Firestore} from 'firebase-admin/firestore';
import type {Auth} from 'firebase-admin/auth';
import {afterEach, beforeAll, expect, it, vi} from 'vitest';
import {loadFypLiveManifest, type FypLiveManifest} from '../src/modules/dataset/fyp-live-manifest';
import {createFypLiveExecutor, guardFypLiveClients} from '../src/modules/dataset/fyp-live-executor';
import {FYP_ROOT} from '../src/modules/dataset/fyp-dataset';

let accepted: FypLiveManifest;
const manifestText=readFileSync('../docs/integration/gainpath-fyp-cohort-preflight.json','utf8');
const sourceText=readFileSync('../build/fyp-cohort-integration/proposed-source-records.json','utf8');
beforeAll(async()=>{accepted=await loadFypLiveManifest(manifestText,sourceText);});
afterEach(()=>vi.unstubAllEnvs());

function fixture(){
 const data=new Map<string,any>(),users=new Map<string,any>(),events:any[]=[],secrets=new Map<string,any>();let sequence=0,interruptAfterCreate=false,failEnable=false,enableCount=0,clockMillis=1793752570496;
 const snap=(p:string)=>({exists:data.has(p),data:()=>structuredClone(data.get(p)),id:p.split('/').at(-1),ref:{path:p}});
 const db=Object.create(Firestore.prototype) as Firestore;
 const doc=(p:string)=>({path:p,get:async()=>snap(p),listCollections:async()=>[...new Set([...data.keys()].filter(k=>k.startsWith(p+'/')).map(k=>k.slice(p.length+1).split('/')[0]))],create:async(d:any)=>{if(data.has(p))throw Error('collision');data.set(p,structuredClone(d));}});
 Object.defineProperties(db,{_projectId:{value:'gainpath-0619',writable:true},_databaseId:{value:'(default)',writable:true},_settings:{value:{ssl:true},writable:true},
  doc:{value:doc},getAll:{value:async(...refs:any[])=>refs.filter(r=>r.path).map(r=>snap(r.path))},collection:{value:(p:string)=>({limit:()=>({get:async()=>({size:0,docs:[]})})})},
  runTransaction:{value:async(work:any)=>{const writes:any[]=[];const tx={get:async(r:any)=>{if(writes.length)throw Error('read after write');return snap(r.path);},getAll:async(...refs:any[])=>{if(writes.length)throw Error('read after write');return refs.map(r=>snap(r.path));},create:(r:any,d:any)=>writes.push({p:r.path,d,create:true}),set:(r:any,d:any)=>writes.push({p:r.path,d})};const result=await work(tx);for(const w of writes)if(w.create&&data.has(w.p))throw Error('collision');for(const w of writes)data.set(w.p,structuredClone(w.d));return result;}}});
 const missing=()=>Object.assign(Error('missing'),{code:'auth/user-not-found'});
 const auth={app:{options:{projectId:'gainpath-0619'}},getUser:async(uid:string)=>{if(!users.has(uid))throw missing();return structuredClone(users.get(uid));},getUserByEmail:async(email:string)=>{const u=[...users.values()].find(u=>u.email===email);if(!u)throw missing();return structuredClone(u);},
  createUser:async(spec:any)=>{if(users.has(spec.uid))throw Error('UID occupied');const u={...spec,metadata:{creationTime:new Date(1793752570496+ ++sequence).toISOString()},customClaims:{}};delete u.password;users.set(u.uid,u);if(interruptAfterCreate){interruptAfterCreate=false;throw Error('Simulated lost Auth create response');}return structuredClone(u);},
  updateUser:async(uid:string,patch:any)=>{if(failEnable&&patch.disabled===false&&++enableCount===2)throw Error('Simulated enable failure');Object.assign(users.get(uid),patch);return structuredClone(users.get(uid));},revokeRefreshTokens:async(uid:string)=>{users.get(uid).tokensValidAfterTime=new Date(clockMillis).toISOString();},setCustomUserClaims:async(uid:string,claims:any)=>{users.get(uid).customClaims=structuredClone(claims);}} as unknown as Auth;
 for(const i of accepted.dataset.identities)secrets.set(i.uid,{password:'Synthetic_test_password_only_'+i.uid,provisioningNonce:('nonce_'+i.uid).padEnd(64,'x')});
 const vault={executionId:'fyp-live-fixture-operation',get:async(uid:string)=>secrets.get(uid),bind:async(uid:string,time:number)=>{const s=secrets.get(uid);if(s.createdAt&&s.createdAt!==time)throw Error('binding drift');s.createdAt=time;}};
 let activationAllowed=true;
 const engine=()=>createFypLiveExecutor({firestore:db,auth,manifest:accepted,vault,clock:()=>clockMillis,audit:async e=>{events.push(e);},activationCheck:async()=>{if(!activationAllowed)throw Error('Readiness gate failed');}});
 return{data,users,events,secrets,db,auth,engine,advance:()=>{clockMillis+=5000;},interrupt:()=>{interruptAfterCreate=true;},denyActivation:()=>{activationAllowed=false;},failEnable:()=>{failEnable=true;}};
}

it('loads only the exact owner-reviewed manifest and source graph',async()=>{
 expect(accepted.dataset.counts.documents).toBe(466);
 expect(accepted.dataset.identities).toHaveLength(27);
 await expect(loadFypLiveManifest(manifestText.replace('gainpath-0619','foreign'),sourceText)).rejects.toThrow();
 await expect(loadFypLiveManifest(manifestText,sourceText.replace('fictional_synthetic','realCamera'))).rejects.toThrow();
});
it('keeps all manifest authority immutable after validation',()=>{
 expect(Object.isFrozen(accepted.plan.sourcePaths)).toBe(true);
 expect(Object.isFrozen(accepted.plan.releaseRecord)).toBe(true);
 expect(()=>accepted.plan.sourcePaths.push('users/unrelated')).toThrow();
 expect(()=>{accepted.plan.releaseRecord.enabled=true;}).toThrow();
 expect(Object.isFrozen(accepted.dataset.documents)).toBe(true);
 expect(Object.isFrozen(accepted.dataset.identities)).toBe(true);
 expect(()=>{(accepted.dataset as any).digest='forged';}).toThrow();
});
it('requires actual fixed-project/default-database SDK clients and rejects endpoint/emulator overrides',()=>{
 const f=fixture();expect(()=>guardFypLiveClients(f.db,f.auth)).not.toThrow();
 Object.defineProperty(f.db,'_projectId',{value:'foreign'});expect(()=>guardFypLiveClients(f.db,f.auth)).toThrow();
 const other=fixture();vi.stubEnv('FIRESTORE_EMULATOR_HOST','127.0.0.1:18231');expect(()=>guardFypLiveClients(other.db,other.auth)).toThrow();
});
it('rejects named databases, insecure/custom endpoints and foreign Auth projects',()=>{
 for(const patch of [{ssl:false},{port:80},{servicePath:'example.invalid'},{sslCreds:{}},{universeDomain:'example.invalid'}]){const f=fixture();Object.defineProperty(f.db,'_settings',{value:patch});expect(()=>guardFypLiveClients(f.db,f.auth)).toThrow();}
 const f=fixture();Object.defineProperty(f.db,'_databaseId',{value:'named'});expect(()=>guardFypLiveClients(f.db,f.auth)).toThrow();
});
it('rejects alternate Google universe environment configuration',()=>{
 const f=fixture();vi.stubEnv('GOOGLE_CLOUD_UNIVERSE_DOMAIN','example.invalid');expect(()=>guardFypLiveClients(f.db,f.auth)).toThrow();
});
it('dry-runs without cloud writes and rejects unowned/canonical/Auth collisions before creating anything',async()=>{
 const f=fixture();expect(await f.engine().dryRun()).toMatchObject({dryRun:true,willWrite:false});expect(f.data.size).toBe(0);expect(f.users.size).toBe(0);
 for(const p of [FYP_ROOT,'datasetAssignments/demo-m13-admin','users/demo-m13-member-01']){const c=fixture();c.data.set(p,{unowned:true});await expect(c.engine().apply()).rejects.toThrow();expect(c.users.size).toBe(0);}
 const c=fixture();c.users.set('demo-m13-admin',{uid:'demo-m13-admin',email:'unrelated@invalid.test'});await expect(c.engine().apply()).rejects.toThrow();expect(c.data.size).toBe(0);
 const orphan=fixture();orphan.data.set(FYP_ROOT+'/coaches/unowned-orphan',{status:'published'});await expect(orphan.engine().apply()).rejects.toThrow();expect(orphan.users.size).toBe(0);
});
it('creates exact owned source with disabled accounts and preserves canonical sentinels',async()=>{
 const f=fixture();f.data.set('users/canonical-sentinel',{private:'preserve'});const result=await f.engine().apply();
 expect(result).toMatchObject({sourceDocuments:466,authIdentities:27,releaseEnabled:false,accountsEnabled:false});
 expect([...f.users.values()].every(u=>u.disabled===true)).toBe(true);
 expect(f.data.get('users/canonical-sentinel')).toEqual({private:'preserve'});
 expect(f.data.get('datasetRuntimeReleases/fyp-v1').enabled).toBe(false);
 for(const identity of accepted.dataset.identities){const u=f.users.get(identity.uid),assignment=f.data.get('datasetAssignments/'+identity.uid);expect(u.displayName).toBe(identity.displayName);expect(Object.keys(u.customClaims)).toEqual(['fypAuthCreatedAtMillis']);expect(assignment.authCreatedAtMillis).toBe(Date.parse(u.metadata.creationTime));}
 expect(JSON.stringify(f.events)).not.toContain('Synthetic_test_password');expect(JSON.stringify(f.events)).not.toContain('nonce_');
});
it('resumes an interrupted disabled Auth creation only with its secret provisioning nonce',async()=>{
 const f=fixture();f.interrupt();await expect(f.engine().apply()).rejects.toThrow('lost Auth');expect(f.users.size).toBe(1);
 await f.engine().apply();expect(f.users.size).toBe(27);expect(await f.engine().validate()).toMatchObject({valid:true,accountsEnabled:false});
 const bad=fixture();bad.interrupt();await expect(bad.engine().apply()).rejects.toThrow();bad.users.get('demo-m13-admin').displayName='foreign occupant';await expect(bad.engine().apply()).rejects.toThrow();expect(bad.users.size).toBe(1);
});
it('does not activate when readiness fails and activates only the exact validated graph',async()=>{
 const f=fixture();await f.engine().apply();f.denyActivation();await expect(f.engine().activate()).rejects.toThrow('Readiness');expect([...f.users.values()].every(u=>u.disabled)).toBe(true);expect(f.data.get('datasetRuntimeReleases/fyp-v1').enabled).toBe(false);
 const ready=fixture();await ready.engine().apply();await ready.engine().activate();expect(ready.data.get('datasetRuntimeReleases/fyp-v1').enabled).toBe(true);expect(ready.data.get(FYP_ROOT+'/seedRuns/gainpath-fyp-v1').status).toBe('complete');expect([...ready.users.values()].every(u=>!u.disabled)).toBe(true);
});
it('automatically quarantines callable and direct access after a partial Auth activation failure',async()=>{
 const f=fixture();await f.engine().apply();f.failEnable();await expect(f.engine().activate()).rejects.toThrow('enable failure');
 expect(f.data.get('datasetRuntimeReleases/fyp-v1').enabled).toBe(false);expect(f.data.get(FYP_ROOT).enabled).toBe(false);
 expect([...f.users.values()].every(u=>u.disabled)).toBe(true);expect(accepted.dataset.identities.every(i=>f.data.get('datasetAssignments/'+i.uid).enabled===false)).toBe(true);
});
it('rejects changed source and never resets a later consent change on reapply',async()=>{
 const f=fixture();await f.engine().apply();const p=Object.keys(accepted.dataset.documents).find(p=>p.includes('/recommendationConsent/'))!;const before=structuredClone(f.data.get(p));f.data.set(p,{...before,revision:999});await expect(f.engine().apply()).rejects.toThrow();expect(f.data.get(p).revision).toBe(999);
});
it('bounded disable revokes assignments before Auth and cleanup remains dry-run only',async()=>{
 const f=fixture();await f.engine().apply();await f.engine().activate();await f.engine().disable();expect(f.data.get('datasetRuntimeReleases/fyp-v1').enabled).toBe(false);expect(accepted.dataset.identities.every(i=>f.data.get('datasetAssignments/'+i.uid).enabled===false)).toBe(true);expect([...f.users.values()].every(u=>u.disabled)).toBe(true);
 const before=f.data.size;expect(await f.engine().cleanupDryRun()).toMatchObject({dryRun:true,willDelete:false});expect(f.data.size).toBe(before);
 expect(f.data.get(FYP_ROOT).enabled).toBe(false);
});
it('quarantines release/direct reads before rejecting a tampered assignment without overwriting it',async()=>{
 const f=fixture();await f.engine().apply();await f.engine().activate();const p='datasetAssignments/demo-m13-member-01';f.data.set(p,{...f.data.get(p),role:'admin'});
 await expect(f.engine().disable()).rejects.toThrow();expect(f.data.get(p).role).toBe('admin');expect(f.data.get('datasetRuntimeReleases/fyp-v1').enabled).toBe(false);expect(f.data.get(FYP_ROOT).enabled).toBe(false);
});
it('cleanup inventories exact source, ownership, control and Auth identities without deletion',async()=>{
 const f=fixture();await f.engine().apply();const result=await f.engine().cleanupDryRun();expect(result.firestorePaths).toHaveLength(1015);expect(result.authBindings).toHaveLength(27);expect(result.willDelete).toBe(false);
});
it('recovers once from exact owned quarantine with newer assignment revisions and an old-token lifecycle barrier',async()=>{
 const f=fixture();await f.engine().apply();await f.engine().activate();await f.engine().disable();f.advance();
 const beforeConsent=[...f.data].filter(([p])=>p.includes('/recommendationConsent/'));
 const restored=await (f.engine() as any).recover();expect(restored.status).toBe('validated');expect(restored.releaseEnabled).toBe(false);
 for(const i of accepted.dataset.identities){const a=f.data.get('datasetAssignments/'+i.uid),u=f.data.get(FYP_ROOT+'/users/'+i.uid);expect(a.revision).toBe(3);expect(a.enabled).toBe(true);expect(u.accountLifecycle.sessionNotBeforeSeconds).toBeGreaterThan(1793752570);expect(f.users.get(i.uid).disabled).toBe(true);expect(f.users.get(i.uid).tokensValidAfterTime).toBeTruthy();}
 expect([...f.data].filter(([p])=>p.includes('/recommendationConsent/'))).toEqual(beforeConsent);
 await f.engine().activate();expect((await f.engine().validate()).releaseEnabled).toBe(true);
 expect((await f.engine().cleanupDryRun()).preserved).toEqual([]);
 await f.engine().disable();f.advance();await expect((f.engine() as any).recover()).rejects.toThrow();
});
it.each(['assignment','consent'])('never recovers over a changed %s after quarantine',async kind=>{
 const f=fixture();await f.engine().apply();await f.engine().activate();await f.engine().disable();f.advance();
 const p=kind==='assignment'?'datasetAssignments/demo-m13-member-01':Object.keys(accepted.dataset.documents).find(p=>p.includes('/recommendationConsent/'))!;
 const changed={...f.data.get(p),revision:999};f.data.set(p,changed);await expect((f.engine() as any).recover()).rejects.toThrow();
 expect(f.data.get(p)).toEqual(changed);expect(f.data.get(FYP_ROOT).enabled).toBe(false);expect(f.data.get('datasetRuntimeReleases/fyp-v1').enabled).toBe(false);
});
it('temporarily revokes only fixture Member18 and restores access with a newer revision',async()=>{
 const f=fixture();await f.engine().apply();await f.engine().activate();await f.engine().disable();f.advance();await f.engine().recover();await f.engine().activate();
 const p='datasetAssignments/demo-m13-member-18',untouched=structuredClone(f.data.get('datasetAssignments/demo-m13-member-01'));
 const result=await (f.engine() as any).testRevokedFixtureAssignment(async()=>{expect(f.data.get(p).enabled).toBe(false);expect(f.data.get(p).revision).toBe(4);expect(f.data.get('datasetAssignments/demo-m13-member-01')).toEqual(untouched);});
 expect(result).toMatchObject({tested:true,restored:true,revision:5});expect(f.data.get(p).enabled).toBe(true);expect((await f.engine().validate()).valid).toBe(true);
 await expect((f.engine() as any).testRevokedFixtureAssignment(async()=>{})).rejects.toThrow();
});
it('restores a test-revoked assignment on a failed check but never overwrites concurrent assignment drift',async()=>{
 const f=fixture();await f.engine().apply();await f.engine().activate();await f.engine().disable();f.advance();await f.engine().recover();await f.engine().activate();
 await expect((f.engine() as any).testRevokedFixtureAssignment(async()=>{throw Error('simulated check failure');})).rejects.toThrow('simulated');expect(f.data.get('datasetAssignments/demo-m13-member-18')).toMatchObject({enabled:true,revision:5});
 const other=fixture();await other.engine().apply();await other.engine().activate();await other.engine().disable();other.advance();await other.engine().recover();await other.engine().activate();const p='datasetAssignments/demo-m13-member-18';
 await expect((other.engine() as any).testRevokedFixtureAssignment(async()=>{other.data.set(p,{...other.data.get(p),revision:999});})).rejects.toThrow();expect(other.data.get(p)).toMatchObject({enabled:false,revision:999});
});
