import {randomBytes} from 'node:crypto';
import {spawn} from 'node:child_process';
import {resolve} from 'node:path';
import {mkdirSync,writeFileSync,readFileSync} from 'node:fs';
import {initializeApp,deleteApp,type App} from 'firebase-admin/app';
import {getFirestore,type Firestore} from 'firebase-admin/firestore';
import {getAuth,type Auth} from 'firebase-admin/auth';
import {beforeAll,afterAll,it,expect} from 'vitest';
import {buildFypDataset,type FypDataset} from '../src/modules/dataset/fyp-dataset';
import {applyFypSeed} from '../src/modules/dataset/fyp-seed';
import {unifiedSamplePlan,applyUnifiedSamplePlan} from '../src/modules/dataset/unified-sample-plan';
import {FirestoreStore} from '../src/platform/firestore/firestore-store';
import {fypDigest} from '../src/modules/dataset/fyp-integrity';
const project='demo-gainpath-fyp',out='../build/unified-admin-20261104',password=randomBytes(24).toString('base64url');let app:App,db:Firestore,auth:Auth,dataset:FypDataset;
const tokens=new Map<string,string>(),snapshots:Record<string,string>={},results:Record<string,unknown>={liveFirebase:false,actualEmulators:true,appCheck:'emulator decoded test token, not real attestation'};
const q=(x:Record<string,unknown>={})=>({schemaVersion:1,organizationId:'gainpath',...x});
async function call(uid:string,operation:string,data:unknown,missing?:'auth'|'app'){
 if(!tokens.has(uid)){const u=await auth.getUser(uid),r=await fetch('http://127.0.0.1:19131/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=emulator',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:u.email,password,returnSecureToken:true})}),b=await r.json() as any;if(!r.ok)throw Error('Emulator sign-in failed');tokens.set(uid,b.idToken);}
 const header=Buffer.from(JSON.stringify({alg:'none',typ:'JWT'})).toString('base64url'),body=Buffer.from(JSON.stringify({sub:'unified-admin-test',aud:[`projects/${project}`],iat:Math.floor(Date.now()/1000),exp:Math.floor(Date.now()/1000)+3600})).toString('base64url');
 const r=await fetch(`http://127.0.0.1:15031/${project}/asia-southeast1/fypDatasetCommand`,{method:'POST',headers:{'Content-Type':'application/json',...(missing==='auth'?{}:{Authorization:'Bearer '+tokens.get(uid)}),...(missing==='app'?{}:{'X-Firebase-AppCheck':`${header}.${body}.`})},body:JSON.stringify({data:{schemaVersion:1,operation,data}})}),b=await r.json() as any;if(!r.ok||b.error)throw Object.assign(Error(b.error?.message??'Rejected'),{code:b.error?.status});return b.result;
}
beforeAll(async()=>{
 if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:18231'||process.env.FIREBASE_AUTH_EMULATOR_HOST!=='127.0.0.1:19131'||process.env.GCLOUD_PROJECT!==project)throw Error('Dedicated emulator only');
 mkdirSync(out,{recursive:true});app=initializeApp({projectId:project},'unified-admin');db=getFirestore(app);auth=getAuth(app);dataset=await buildFypDataset({anchorMillis:1793752470496});
 const clear=await fetch(`http://127.0.0.1:18231/emulator/v1/projects/${project}/databases/(default)/documents`,{method:'DELETE'});if(!clear.ok)throw Error('Emulator reset failed');
 await auth.deleteUsers([...dataset.identities.map(x=>x.uid),'canonical-admin','canonical-member','foreign-admin']);
 await db.doc('orgs/gainpath').set({status:'active'});
 for(const[uid,role,org]of[['canonical-admin','admin','gainpath'],['canonical-member','member','gainpath'],['foreign-admin','admin','other']]){await auth.createUser({uid,email:uid+'@fixture.invalid',emailVerified:true,password});await db.doc('users/'+uid).set({organizationId:org,role});await db.doc(`orgs/${org}/members/${uid}`).set({schemaVersion:1,organizationId:org,userId:uid,role,status:'active',branchIds:['main'],displayName:uid,email:uid+'@fixture.invalid',createdAtMillis:dataset.anchorMillis-1000});}
 await applyFypSeed({firestore:db,auth,dataset,emulatorPassword:password});
 await db.doc('orgs/gainpath/coachProfiles/canonical-pending-coach').set({...dataset.documents['orgs/gainpath/cohorts/fyp-v1/coachProfiles/'+dataset.coachIds[0]],displayName:'Canonical pending Coach'});
 await db.doc('orgs/gainpath/members/canonical-pending-coach').set({organizationId:'gainpath',userId:'canonical-pending-coach',role:'coach',status:'pending',branchIds:['main']});
 // Replay only already-authorized fictional runtime state into the isolated
 // emulator. No generation, Send, provider request or live mutation occurs.
 const live=JSON.parse(readFileSync(out+'/fyp-state-before.private.json','utf8')) as {records:Record<string,Record<string,unknown>>};
 const recovery=Object.entries(live.records).find(([path])=>path.includes('/seedRuns/'))?.[1].recovery as {sessionNotBeforeSeconds:number;users:Record<string,string>};
 for(const path of Object.keys(recovery.users)){const baseline=dataset.documents[path];if(!baseline)throw Error('Missing replay source');await db.doc(path).set({...baseline,accountLifecycle:{schemaVersion:1,state:'active',revocationPending:false,sessionNotBeforeSeconds:recovery.sessionNotBeforeSeconds}});}
 for(const[path,data]of Object.entries(live.records))if(/^orgs\/gainpath\/cohorts\/fyp-v1\/(recommendation(?:Runs|Leads|Recipients|DeliveryReceipts|MemberCommandReceipts|DecisionAudits|CommandReceipts|GenerationState)|notifications|generatedOwnership)\//.test(path))await db.doc(path).set(data);
 const supplement=JSON.parse(readFileSync(out+'/fyp-runtime-supplement.private.json','utf8')) as {records:Record<string,Record<string,unknown>>};
 for(const[path,data]of Object.entries(supplement.records)){if(!path.startsWith('orgs/gainpath/cohorts/fyp-v1/'))throw Error('Invalid replay');await db.doc(path).set(data);snapshots[path]=fypDigest((await db.doc(path).get()).data());}
 const plan=unifiedSamplePlan({anchorAtMillis:dataset.anchorMillis,memberIds:dataset.memberIds,coachIds:dataset.coachIds.slice(0,7),programIds:dataset.programIds,plans:[{id:'basic',name:'Basic example',amountMinor:5900,durationDays:30,version:'fixture-v1'},{id:'premium',name:'Premium example',amountMinor:9900,durationDays:30,version:'fixture-v1'}]});await applyUnifiedSamplePlan(new FirestoreStore(db),plan,false);await applyUnifiedSamplePlan(new FirestoreStore(db),plan,true);
 for(const[path]of Object.entries(dataset.documents))snapshots[path]=fypDigest((await db.doc(path).get()).data());
 for(const[path]of Object.entries(live.records))if(!path.includes('/seedRuns/')&&!path.includes('/recommendationConsent/'))snapshots[path]=fypDigest((await db.doc(path).get()).data());
},120000);
afterAll(async()=>{writeFileSync(out+'/emulator-proof.json',JSON.stringify(results,null,2)+'\n');if(app)await deleteApp(app);});
it('canonical Admin sees all existing/FYP Members and eight Coaches without fictional login',async()=>{
 const members=await call('canonical-admin','admin.unified.directory',q({kind:'members',limit:50})),coaches=await call('canonical-admin','admin.unified.directory',q({kind:'coaches',limit:50}));expect(members.items).toHaveLength(19);expect(members.sourceCounts).toEqual({existing:1,fyp:18});expect(coaches.items).toHaveLength(8);expect(coaches.items.filter((x:any)=>x.record.status==='published')).toHaveLength(7);results.directory={members,coaches};
});
it('uses actual shared census,52 observations, Programs and coherent sample financial calculations',async()=>{
 const range={startAtMillis:0,endAtMillis:Date.now()},report=await call('canonical-admin','admin.unified.report',q({...range,schemaVersion:2})),workouts=await call('canonical-admin','admin.unified.workouts',q(range)),programs=await call('canonical-admin','admin.unified.programs',q());
 expect(report.currentAccounts).toEqual({members:19,coaches:7});expect(report.receipts.confirmedMinor).toBe(0);expect(report.unified.sampleBusiness.simulatedRevenueMinor).toBe(18*5900+17*9900+16*8000);expect(workouts.totals.sessions).toBe(52);expect(workouts.classification).toBe('mixed_descriptive_sources');expect(JSON.stringify(workouts)).not.toContain(dataset.memberIds[0]);expect(programs.programs).toHaveLength(3);expect(programs.routines).toHaveLength(12);results.report=report;results.workouts=workouts;results.programs=programs;
});
it('provides safe read-only Member/Coach details and original recommendation readers',async()=>{
 const member=await call('canonical-admin','admin.unified.member',q({memberId:dataset.memberIds[0]})),coach=await call('canonical-admin','admin.unified.coach',q({coachId:dataset.coachIds[0]}));expect(member.readOnly).toBe(true);expect(member.extra.some((x:any)=>x.value.includes('3 synthetic sessions'))).toBe(true);expect(coach.readOnly).toBe(true);expect(coach.fictionalCredentialMetadata).toBe(true);
 const pending=await call('canonical-admin','admin.unified.coach',q({coachId:'canonical-pending-coach'}));expect(pending.readOnly).toBe(false);expect(pending.publication).toBe(null);expect(pending.draft.displayName).toBe('Canonical pending Coach');
 const input=q({kind:'trainer',startAtMillis:dataset.anchorMillis-86400000,endAtMillis:Date.now(),status:'all',exerciseId:null,category:null,specialization:null,limit:25,afterLeadId:null});
 const leads=await call('canonical-admin','admin.unified.cohort',q({operation:'admin.queue.list',input}));expect(leads.leads).toHaveLength(6);
 const detail=await call('canonical-admin','admin.unified.cohort',q({operation:'admin.queue.detail',input:q({leadId:leads.leads[0].leadId})}));expect(detail.lead.leadId).toBe(leads.leads[0].leadId);
 const insights=await call('canonical-admin','admin.unified.cohort',q({operation:'admin.insights',input:q({startAtMillis:dataset.legacyDataset.window.startAtMillis,endAtMillis:Date.now()})}));
 results.details={member,coach,lead:detail};results.leads=leads;results.insights=insights;
});
it('rejects absent Auth/AppCheck, ordinary/FYP/foreign roles and every mutation through unified transport',async()=>{
 for(const uid of ['canonical-member','foreign-admin',dataset.adminId,dataset.memberIds[0]])await expect(call(uid,'admin.unified.directory',q({kind:'members'}))).rejects.toThrow();
 for(const missing of ['auth','app'] as const)await expect(call('canonical-admin','admin.unified.directory',q({kind:'members'}),missing)).rejects.toThrow();
 for(const operation of ['admin.queue.refresh','admin.queue.decide','member.consent.set','delivery.process'])await expect(call('canonical-admin','admin.unified.cohort',q({operation,input:q()}))).rejects.toThrow();
 const direct=async(uid:string,path:string)=>fetch(`http://127.0.0.1:18231/v1/projects/${project}/databases/(default)/documents/${path}`,{headers:{Authorization:'Bearer '+tokens.get(uid)}});
 expect((await direct('canonical-member','users/canonical-member')).status).toBe(200);
 for(const uid of ['canonical-admin','canonical-member','foreign-admin'])expect((await direct(uid,`orgs/gainpath/cohorts/fyp-v1/profiles/${dataset.memberIds[0]}`)).status).toBe(403);
 results.denials=true;
});
it('ordinary canonical Admin Flutter components render actual emulator calculations and preserved queues',async()=>{
 const exit=await new Promise<number>((done,reject)=>{const log=out+'/ordinary-admin-widget-output.txt';let pending='';const emit=(chunk:string)=>{pending+=chunk;const lines=pending.split('\n');pending=lines.pop()!;for(const line of lines){const clean=line.split(password).join('[ephemeral emulator credential redacted]')+'\n';writeFileSync(log,clean,{flag:'a'});process.stdout.write(clean);}};
  const child=spawn('C:/flutter/bin/cache/dart-sdk/bin/dart.exe',['C:/flutter/bin/cache/flutter_tools.snapshot','test','--no-pub','test/emulator/unified_ordinary_admin_test.dart'],{cwd:resolve('../apps/admin_web'),env:{...process.env,UNIFIED_EMULATOR_PASSWORD:password},windowsHide:true,stdio:['ignore','pipe','pipe']});child.stdout.on('data',x=>emit(String(x)));child.stderr.on('data',x=>emit(String(x)));child.once('error',reject);child.once('close',code=>{emit('\n');done(code??1);});});
 expect(exit).toBe(0);results.ordinaryCanonicalAdminWidgets=true;
},240000);
it('revoked canonical authority and source failures fail closed; source/consent/recommendation state stays unchanged',async()=>{
 const gate=db.doc('orgs/gainpath/adminDataIntegrations/fyp-v1'),old=(await gate.get()).data()!;await gate.update({enabled:false});await expect(call('canonical-admin','admin.unified.directory',q({kind:'members'}))).rejects.toThrow();await gate.set(old);
 const path=Object.keys(snapshots).find(x=>x.includes('/coaches/'))!,data=(await db.doc(path).get()).data()!;await db.doc(path).update({bio:'drift'});await expect(call('canonical-admin','admin.unified.directory',q({kind:'coaches'}))).rejects.toThrow();await db.doc(path).set(data);
 for(const kind of ['members','coaches','content']){const path=Object.keys(dataset.documents).find(p=>p.startsWith(`orgs/gainpath/cohorts/fyp-v1/${kind}/`)&&p.split('/').length===6)!,data=(await db.doc(path).get()).data()!;await db.doc(path).delete();await expect(call('canonical-admin','admin.unified.directory',q({kind}))).rejects.toThrow();await db.doc(path).set(data);}
 const orphan=db.doc('orgs/gainpath/cohorts/fyp-v1/notifications/unowned-notice');await orphan.set({recipientId:dataset.memberIds[0],message:'unowned'});await expect(call('canonical-admin','admin.unified.member',q({memberId:dataset.memberIds[0]}))).rejects.toThrow();await orphan.delete();
 for(const[path,digest]of Object.entries(snapshots))expect(fypDigest((await db.doc(path).get()).data())).toBe(digest);
 for(const col of ['transactions','bookings','rewardAwards','rewardBalances'])expect((await db.collection('orgs/gainpath/'+col).count().get()).data().count).toBe(0);results.preservation=true;
});
