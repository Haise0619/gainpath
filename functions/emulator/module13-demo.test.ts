import {readFileSync,mkdirSync,writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {spawn} from 'node:child_process';
import {initializeApp,deleteApp,type App} from 'firebase-admin/app';
import {getFirestore,type Firestore} from 'firebase-admin/firestore';
import {getAuth,type Auth} from 'firebase-admin/auth';
import {getStorage} from 'firebase-admin/storage';
import {beforeAll,afterAll,it,expect} from 'vitest';
import {buildModule13DemoDataset,type Module13DemoDataset} from '../src/modules/recommendation/demo-dataset';
import {applyModule13DemoSeed,validateModule13DemoSeed,describeModule13DemoSeed,cleanupModule13DemoSeedDryRun} from '../src/modules/recommendation/demo-seed';
import {digestOf} from '../src/modules/workouts/workout-backup-validation';
import {FirestoreStore} from '../src/platform/firestore/firestore-store';

const PROJECT='demo-gainpath-module13-demo',ROOT='orgs/gainpath',OUT='../build/module13-firebase-demo';
let app:App,db:Firestore,defaultDb:Firestore,auth:Auth,dataset:Module13DemoDataset,seed:Awaited<ReturnType<typeof applyModule13DemoSeed>>;
const tokens=new Map<string,string>(),leads:Record<string,any[]>={},proof:any={schemaVersion:1,projectId:PROJECT,databaseId:'module13-demo',realFirebase:false,authEmulatorIdentityTokens:true,appCheck:'Functions Emulator decoded test token; not cryptographic attestation',stages:{}};
function guard(){if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:18119'||process.env.FIREBASE_AUTH_EMULATOR_HOST!=='127.0.0.1:19099'||process.env.GCLOUD_PROJECT!==PROJECT)throw Error('Dedicated demo emulator required');}
const appCheck=()=>[Buffer.from(JSON.stringify({alg:'none',typ:'JWT'})).toString('base64url'),Buffer.from(JSON.stringify({sub:'module13-demo-emulated-app',aud:[`projects/${PROJECT}`],exp:Math.floor(Date.now()/1000)+3600,iat:Math.floor(Date.now()/1000)})).toString('base64url'),''].join('.');
async function token(uid:string,force=false){
 if(!force&&tokens.has(uid))return tokens.get(uid)!;
 const custom=await auth.createCustomToken(uid),r=await fetch('http://127.0.0.1:19099/identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=emulator-only-key',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({token:custom,returnSecureToken:true})});
 const j=await r.json() as any;if(!r.ok||typeof j.idToken!=='string')throw Error('Auth Emulator sign-in failed');tokens.set(uid,j.idToken);return j.idToken;
}
async function call(uid:string,operation:string,data:Record<string,unknown>,options:{withoutAppCheck?:boolean;withoutAuth?:boolean}={}){
 guard();const name=operation==='delivery.process'?'module13DemoDeliveryCommand':uid===dataset.adminId?'module13DemoAdminCommand':'module13DemoMemberCommand';
 const headers:Record<string,string>={'Content-Type':'application/json'};if(!options.withoutAuth)headers.Authorization=`Bearer ${await token(uid)}`;if(!options.withoutAppCheck)headers['X-Firebase-AppCheck']=appCheck();
 const response=await fetch(`http://127.0.0.1:15019/${PROJECT}/asia-southeast1/${name}`,{method:'POST',headers,body:JSON.stringify({data:{schemaVersion:1,operation,data}})}),body=await response.json() as any;
 if(!response.ok||body.error)throw Object.assign(Error('Protected demo callable refused'),{code:body.error?.status??response.status});return body.result??body.data;
}
const scope=(fields:Record<string,unknown>={})=>({schemaVersion:1,organizationId:'gainpath',...fields});
async function refresh(kind:string,id:string){let continuation:null|string=null,result:any;for(let page=0;page<11;page++){result=await call(dataset.adminId,'admin.queue.refresh',scope({kind,commandId:id,continuation}));continuation=result.summary.nextCursor;if(!continuation)return result;}throw Error('Bounded refresh exceeded');}
async function list(kind:string){return call(dataset.adminId,'admin.queue.list',scope({kind,status:'all',startAtMillis:dataset.clockMillis-86400000,endAtMillis:Date.now(),exerciseId:null,category:null,specialization:null,afterLeadId:null,limit:25}));}
async function snapshot(){const out:Record<string,unknown>={};for(const name of ['bookings','consultations','payments','paymentReceipts','rewardWallets','rewardReceipts','memberPrograms','workoutSessions'])out[name]=(await db.collection(`${ROOT}/${name}`).get()).docs.map(d=>({id:d.id,data:d.data()}));return out;}
beforeAll(async()=>{
 guard();mkdirSync(OUT,{recursive:true});app=initializeApp({projectId:PROJECT},'module13-demo-full');db=getFirestore(app,'module13-demo');defaultDb=getFirestore(app);auth=getAuth(app);
 // The installed CLI cannot configure named emulator Rules, while its cached
 // Firestore runtime supports the database-specific Rules API. Load explicitly
 // and verify actual client denials; never accept an implicitly open database.
 const rules=await fetch(`http://127.0.0.1:18119/emulator/v1/projects/${PROJECT}/databases/module13-demo:securityRules`,{method:'PUT',headers:{'Content-Type':'application/json'},body:JSON.stringify({rules:{files:[{name:'demo.rules',content:readFileSync('../firebase/module13-demo.firestore.rules','utf8')}]}})});expect(rules.status).toBe(200);
 await defaultDb.doc('protectedDefault/sentinel').set({unchanged:true});
 const defaults=defaultDb.batch();for(const[p,data]of Object.entries({
  'orgs/gainpath':{status:'active'},'users/non-demo-probe':{organizationId:'gainpath',role:'member'},'orgs/gainpath/members/non-demo-probe':{organizationId:'gainpath',role:'member',status:'active',branchIds:['main']},'orgs/gainpath/coaches/ordinary-coach-probe':{status:'published',displayName:'Protected ordinary fixture'},'orgs/gainpath/content/ordinary-content-probe':{kind:'routine',status:'published'}
 }))defaults.set(defaultDb.doc(p),data);await defaults.commit();
 dataset=await buildModule13DemoDataset({nowMillis:Date.now()-1000});
 seed=await applyModule13DemoSeed({firestore:db,auth,bucket:getStorage(app).bucket(dataset.storageBucket),dataset});dataset=seed.dataset;
 writeFileSync(`${OUT}/seed-manifest.json`,JSON.stringify(seed.manifest,null,2));writeFileSync(`${OUT}/seed-integrity.json`,JSON.stringify(seed.validation,null,2));
},120000);
afterAll(async()=>{if(proof.stages.completed)writeFileSync(`${OUT}/connected-proof.json`,JSON.stringify(proof,null,2));await db?.terminate();await defaultDb?.terminate();if(app)await deleteApp(app);});

it('seeds actual Auth, named Firestore and original credential assets with complete relationships and idempotent rerun',async()=>{
 expect((await auth.listUsers(100)).users).toHaveLength(27);expect(seed.validation.eligibleSquatCoaches.length).toBeGreaterThanOrEqual(3);expect(seed.validation.eligibleSquatTutorials.length).toBeGreaterThanOrEqual(3);
 expect(seed.manifest).toMatchObject({coaches:8,members:18,authAccounts:27,storageObjects:8,noRecommendationOutcomesSeeded:true});
 const rerun=await applyModule13DemoSeed({firestore:db,auth,bucket:getStorage(app).bucket(dataset.storageBucket),dataset});expect(rerun.createdAuthThisRun).toBe(0);
 for(const c of ['recommendationLeads','recommendationRecipients','notifications'])expect((await db.collection(`${ROOT}/${c}`).get()).size).toBe(0);
 proof.seed={...seed.validation,manifestDocuments:seed.manifest.firestoreDocuments};proof.stages.sourceSeeded=true;
},120000);

it('uses actual Auth Emulator ID tokens and protected callable protocol; absent App Check and wrong roles refuse',async()=>{
 expect(await call(dataset.adminId,'session.access',scope())).toMatchObject({databaseId:'module13-demo',role:'admin',demoData:true});
 expect(await call(dataset.memberIds[0],'session.access',scope())).toMatchObject({role:'member'});
 await expect(call(dataset.adminId,'session.access',scope(),{withoutAppCheck:true})).rejects.toThrow();await expect(call(dataset.adminId,'session.access',scope(),{withoutAuth:true})).rejects.toThrow();
 await expect(call(dataset.memberIds[0],'admin.configuration.get',scope())).rejects.toThrow();await expect(call(dataset.adminId,'admin.configuration.get',{schemaVersion:1,organizationId:'foreign'})).rejects.toThrow();
 const history=await call(dataset.memberIds[0],'member.workoutHistory',scope({afterKey:null,backupConsented:true}));expect(JSON.stringify(history)).toContain(dataset.memberIds[0]);proof.stages.ownedHistoryRead=true;
});

it('named database Rules refuse non-demo users, cross-Member records and direct private writes or catalog reads',async()=>{
 const member=dataset.memberIds[0],headers={Authorization:`Bearer ${await token(member)}`,'Content-Type':'application/json'};
 const url=(database:string,p:string)=>`http://127.0.0.1:18119/v1/projects/${PROJECT}/databases/${database}/documents/${p}`;
 expect((await fetch(url('module13-demo',`users/${member}`),{headers})).status).toBe(200);
 for(const p of [`users/${dataset.memberIds[1]}`,`${ROOT}/coaches/${dataset.coachIds[0]}`,`${ROOT}/content/${dataset.publicationIds[0]}`,`${ROOT}/recommendationConsent/${member}`,'module13Demo/current'])expect((await fetch(url('module13-demo',p),{headers})).status).toBe(403);
 expect((await fetch(url('module13-demo',`users/${member}`),{method:'PATCH',headers,body:JSON.stringify({fields:{role:{stringValue:'admin'}}})})).status).toBe(403);
 expect((await fetch(url('(default)','protectedDefault/sentinel'),{headers})).status).toBe(403);
 const asset=dataset.storageAssets[0],assetUrl=`http://127.0.0.1:19119/v0/b/${dataset.storageBucket}/o/${encodeURIComponent(asset.path)}?alt=media`;
 expect((await fetch(assetUrl)).status).toBe(403);expect((await fetch(assetUrl,{headers:{Authorization:`Firebase ${await token(member)}`}})).status).toBe(403);proof.stages.credentialDirectReadsDenied=true;
 const probe='non-demo-probe';await auth.createUser({uid:probe,email:'probe@isolated.invalid',emailVerified:true});try{const outsider={Authorization:`Bearer ${await token(probe)}`};expect((await fetch(url('module13-demo',`users/${member}`),{headers:outsider})).status).toBe(403);await expect(call(probe,'session.access',scope())).rejects.toThrow();
  expect((await fetch(url('(default)',`${ROOT}/coaches/ordinary-coach-probe`),{headers:outsider})).status).toBe(200);
  expect((await fetch(url('(default)',`${ROOT}/content/ordinary-content-probe`),{headers:outsider})).status).toBe(200);
  expect((await fetch(url('(default)',`${ROOT}/coaches/ordinary-coach-probe`),{headers})).status).toBe(403);
  expect((await fetch(url('module13-demo',`${ROOT}/coaches/${dataset.coachIds[0]}`),{headers:outsider})).status).toBe(403);
 }finally{await auth.deleteUser(probe);}
 // Historical database-isolation reproduction only. The owner superseded the
 // reserved-name registration guard; it is no longer an accepted live safeguard.
 expect((await defaultDb.doc(`users/${member}`).get()).exists).toBe(false);
 proof.stages.normalMembershipEnrollmentBlocked=false;
 proof.registrationGuard='superseded; see the shared-default audit; live activation is blocked';
 proof.stages.namedDatabaseRules=true;
});

it('exercises the actual Auth Emulator email verification protocol separately from preverified fixture creation',async()=>{
 const uid=dataset.memberIds[17];await auth.updateUser(uid,{emailVerified:false});
 await expect(call(uid,'session.access',scope(),{})).rejects.toThrow();
 const idToken=await token(uid,true),endpoint='http://127.0.0.1:19099/identitytoolkit.googleapis.com/v1/';
 const sent=await fetch(endpoint+'accounts:sendOobCode?key=emulator-only-key',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({requestType:'VERIFY_EMAIL',idToken})});expect(sent.ok).toBe(true);
 const codes=await(await fetch(`http://127.0.0.1:19099/emulator/v1/projects/${PROJECT}/oobCodes`)).json() as any;
 const own=codes.oobCodes.filter((c:any)=>c.email===`${uid}@gainpath-demo.invalid`&&c.requestType==='VERIFY_EMAIL').at(-1);expect(own).toBeDefined();
 const verified=await fetch(endpoint+'accounts:update?key=emulator-only-key',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({oobCode:own.oobCode})});expect(verified.ok).toBe(true);expect((await auth.getUser(uid)).emailVerified).toBe(true);
 await token(uid,true);expect(await call(uid,'session.access',scope())).toMatchObject({role:'member'});proof.stages.emailVerificationProtocol=true;
});

it('derives actual learning needs from the complete seeded source and ranks multiple eligible Coaches and tutorials',async()=>{
 for(const kind of ['trainer','content']){
  const run=await refresh(kind,`demo-${kind}-first`);expect(run.summary.status).toBe('complete');expect(run.summary.generated).toBeGreaterThanOrEqual(5);
  const page=await list(kind);leads[kind]=page.leads;expect(page.leads.some((l:any)=>l.memberId===dataset.memberIds[6])).toBe(false);expect(page.leads.some((l:any)=>l.memberId===dataset.memberIds[8])).toBe(false);
  const lead=page.leads.find((l:any)=>l.memberId===dataset.memberIds[0]);expect(lead).toMatchObject({exerciseId:'F3b8xIr8ynBDd3gEICKX',evidence:{scoredSessions:3,estimatedFormScorePercent:60,coverage:.8},ranking:{origin:'ai_reranked',model:'gainpath-demo-structured-mock-v1'}});
  const b=(await db.doc(`${ROOT}/recommendationEvidenceBindings/${lead.sourceFingerprint}`).get()).data()!;expect(b.provenance.origin).toBe('validated_workout_evidence');expect(b.need.exercise).toBe('squat');
  const repeated=await refresh(kind,`demo-${kind}-repeat`);expect(repeated.summary.generated).toBe(0);
  proof[kind]={summary:run.summary,lead,evidenceBinding:b};
 }
 proof.stages.evidenceDerived=true;proof.stages.existingEngineRanked=true;
},600000);

it.skipIf(process.env.MODULE13_DEMO_CLIENT_UI!=='1')('actual authenticated Flutter Admin and Member consume seeded sources through the Functions Emulator',async()=>{
 const before=await snapshot();
 async function flutter(application:string,uid:string,test:string){
  const idToken=await token(uid);return new Promise<number>((done,reject)=>{
   const child=spawn('C:/flutter/bin/cache/dart-sdk/bin/dart.exe',['C:/flutter/bin/cache/flutter_tools.snapshot','test',test,'--no-pub','--reporter','expanded'],{cwd:resolve(`../apps/${application}`),env:{...process.env,MODULE13_DEMO_GATEWAY:'127.0.0.1:15019',MODULE13_DEMO_ID_TOKEN:idToken},stdio:'inherit',windowsHide:true});child.once('error',reject);child.once('exit',code=>done(code??1));
  });
 }
 const adminExit=await flutter('admin_web',dataset.adminId,'test/emulator/module13_demo_admin_emulator_test.dart');
 const memberExit=await flutter('mobile',dataset.memberIds[1],'test/emulator/module13_demo_member_emulator_test.dart');
 expect(adminExit).toBe(0);expect(memberExit).toBe(0);
 const recipients=(await db.collection(`${ROOT}/recommendationRecipients`).where('memberId','==',dataset.memberIds[1]).get()).docs.map(d=>d.data());expect(recipients).toHaveLength(2);expect(recipients.every(r=>r.status==='delivered'&&typeof r.memberReadAtMillis==='number')).toBe(true);
 expect(await snapshot()).toEqual(before);proof.stages.actualAdminWidget=true;proof.stages.actualMemberWidget=true;proof.stages.clientAuthClaimsFromProtectedNamedDatabase=true;
 proof.flutterMember=recipients.map(r=>({kind:r.kind,revision:r.revision,status:r.status,read:r.memberReadAtMillis!==null,acknowledged:r.acknowledgedAtMillis!==null,dismissed:r.dismissedAtMillis!==null}));
},600000);

it('current Admin decisions, prepared recipients, delivery and owned Member destinations persist without protected mutations',async()=>{
 const before=await snapshot();
 for(const kind of ['trainer','content']){
  const lead=leads[kind].find(l=>l.memberId===dataset.memberIds[0]),detail=await call(dataset.adminId,'admin.queue.detail',scope({leadId:lead.leadId}));expect(detail.lead.evidence.scoredSessions).toBe(3);
  const command=scope({leadId:lead.leadId,commandId:`demo-send-${kind}`,expectedRevision:lead.revision,action:'send',reason:null}),decision=await call(dataset.adminId,'admin.queue.decide',command);expect(decision.outcome).toBe('prepared');expect(await call(dataset.adminId,'admin.queue.decide',command)).toEqual(decision);
  const id=decision.recipientRecommendationId,delivery=await call(dataset.adminId,'delivery.process',scope({recommendationId:id}));expect(await call(dataset.adminId,'delivery.process',scope({recommendationId:id}))).toEqual(delivery);
  const member=dataset.memberIds[0],get=scope({recommendationId:id,action:'get',commandId:null,expectedRevision:null}),current=await call(member,'member.recommendation.command',get);expect(current.state).toBe('available');
  await expect(call(dataset.memberIds[1],'member.recommendation.command',get)).rejects.toThrow();
  const target=current.target,source=target.kind==='trainer'?await call(member,'member.coach',scope({coachId:target.coachId})):await call(member,'member.routine',scope({routineId:target.destination.routineId}));expect(source.status).toBe('published');
  const read=await call(member,'member.recommendation.command',scope({recommendationId:id,action:'read',commandId:`demo-read-${kind}`,expectedRevision:current.revision}));
  const finished=await call(member,'member.recommendation.command',scope({recommendationId:id,action:kind==='trainer'?'acknowledge':'dismiss',commandId:`demo-finish-${kind}`,expectedRevision:read.revision}));expect(kind==='trainer'?finished.acknowledgedAtMillis:finished.dismissedAtMillis).toBeTypeOf('number');
  Object.assign(proof[kind],{decision,delivery,memberResult:finished,currentDestination:target});
 }
 const dismissed=leads.content.find(l=>l.memberId===dataset.memberIds[2]);expect((await call(dataset.adminId,'admin.queue.decide',scope({leadId:dismissed.leadId,commandId:'demo-dismiss-second-member',expectedRevision:1,action:'dismiss',reason:'Demonstration review records this optional guidance as dismissed.'}))).status).toBe('dismissed');
 const inbox=await call(dataset.memberIds[0],'member.inbox',scope());expect(inbox.records).toHaveLength(2);expect(await snapshot()).toEqual(before);expect((await defaultDb.doc('protectedDefault/sentinel').get()).data()).toEqual({unchanged:true});
 proof.stages.adminPrepared=true;proof.stages.delivered=true;proof.stages.currentDestinations=true;proof.stages.protectedCollectionsUnchanged=true;proof.stages.defaultDatabaseUnchanged=true;
});

it('revocation denies current detail and a disabled manifest refuses even known users',async()=>{
 const member=dataset.memberIds[0],consent=await call(member,'member.consent.get',{schemaVersion:2,organizationId:'gainpath'});
 await call(member,'member.consent.set',{schemaVersion:2,organizationId:'gainpath',commandId:'demo-revoke-insights',expectedRevision:consent.revision,purpose:'exerciseInsights',action:'revoke'});
 const id=proof.trainer.decision.recipientRecommendationId,current=await call(member,'member.recommendation.command',scope({recommendationId:id,action:'get',commandId:null,expectedRevision:null}));expect(current.state).toBe('unavailable');
 const manifest=db.doc('module13Demo/current');await manifest.update({enabled:false});await expect(call(dataset.adminId,'session.access',scope())).rejects.toThrow();await manifest.update({enabled:true});
 proof.stages.revocationRefused=true;
 // Inventory after the final consent mutation so its audit/receipt sidecars
 // are included as well as source, queue, recipient and notification records.
 const cleanup=await cleanupModule13DemoSeedDryRun({firestore:db,auth,bucket:getStorage(app).bucket(dataset.storageBucket),dataset});expect(cleanup.willDelete).toBe(false);expect(cleanup.firestorePaths.some(p=>p.includes('/recommendationRecipients/'))).toBe(true);expect(cleanup.firestorePaths.some(p=>p.includes('/notifications/'))).toBe(true);writeFileSync(`${OUT}/cleanup-dry-run.json`,JSON.stringify(cleanup,null,2));proof.cleanup={afterFinalRevocation:true,ownedFirestorePaths:cleanup.firestorePaths.length,authIdentities:cleanup.authUids.length,storageObjects:cleanup.storageObjects.length,deleted:false};proof.stages.completed=true;
});
