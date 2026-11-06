import {createRequire} from 'node:module';
import {resolve} from 'node:path';
import {spawnSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
import {expect,it} from 'vitest';
import {MemoryStore} from './memory-store';
const req=createRequire(resolve('package.json'));
const provision=req('../build/fyp-live-20261104/registration-ready/lib/modules/identity/member-provisioning.js').provisionMember;
it.each([true,false])('exact registration archive denies assigned and tombstoned identities (enabled=%s)',async enabled=>{
 const store=new MemoryStore();store.documents.set('datasetAssignments/synthetic',{enabled});
 await expect(provision(store,{userId:'synthetic',email:'synthetic@example.invalid',displayName:'Synthetic'})).rejects.toMatchObject({code:'permission-denied'});
 expect(store.documents.size).toBe(1);
});
it('exact registration archive preserves ordinary Member-only provisioning and idempotency',async()=>{
 const store=new MemoryStore(),input={userId:'normal-synthetic',email:'normal@example.invalid',displayName:'Ordinary Fixture'};
 expect(await provision(store,input)).toMatchObject({role:'member',status:'active',organizationId:'gainpath'});
 const before=[...store.documents.entries()];await provision(store,input);expect([...store.documents.entries()]).toEqual(before);
});
it('Node22 exact release package exports only the two callable endpoints and retains enforced App Check source',()=>{
 expect(process.version.startsWith('v22.')).toBe(true);
 const code="const p=require('../build/fyp-live-20261104/fyp-ready');console.log(JSON.stringify(Object.entries(p).map(([name,v])=>({name,endpoint:v.__endpoint}))))";
 const child=spawnSync(process.execPath,['-e',code],{cwd:process.cwd(),env:{...process.env,NODE_PATH:resolve('node_modules'),GCLOUD_PROJECT:'gainpath-0619',GCE_METADATA_HOST:'127.0.0.1:9'},encoding:'utf8',windowsHide:true});
 expect(child.status).toBe(0);const exports=JSON.parse(child.stdout);expect(exports.map((e:any)=>e.name).sort()).toEqual(['fypDatasetCommand','fypDatasetSessionCommand']);
 for(const item of exports)expect(item.endpoint).toMatchObject({platform:'gcfv2',region:['asia-southeast1'],timeoutSeconds:540,maxInstances:1,concurrency:4,callableTrigger:{}});
 expect(readFileSync('../build/fyp-live-20261104/fyp-ready/lib/fyp-release-index.js','utf8')).toContain('enforceAppCheck: true');
});
it('boots the actual Admin SDK with the same explicit project environment as the Firebase CLI',()=>{
 const generated=req('./tools/fyp-live-deploy.cjs').firebaseEnvs(),env:Record<string,string|undefined>={...process.env,NODE_PATH:resolve('node_modules'),GCE_METADATA_HOST:'127.0.0.1:9'};
 for(const key of ['GCLOUD_PROJECT','GOOGLE_CLOUD_PROJECT','FIREBASE_CONFIG'])delete env[key];
 const code="require('firebase-admin/app').initializeApp();console.log(require('firebase-admin/firestore').getFirestore().projectId)";
 const absent=spawnSync(process.execPath,['-e',code],{env,encoding:'utf8',windowsHide:true});expect(absent.status).not.toBe(0);
 const configured=spawnSync(process.execPath,['-e',code],{env:{...env,...generated},encoding:'utf8',windowsHide:true});expect(configured.status).toBe(0);expect(configured.stdout.trim()).toBe('gainpath-0619');
});
