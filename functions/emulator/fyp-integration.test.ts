import {demoWorkoutPayload, DEMO_EXERCISES} from '../src/modules/recommendation/demo-dataset';
import {randomBytes} from 'node:crypto';
import {mkdirSync,writeFileSync} from 'node:fs';
import {spawn} from 'node:child_process';
import {resolve} from 'node:path';
import {initializeApp,deleteApp,type App} from 'firebase-admin/app';
import {getFirestore,type Firestore} from 'firebase-admin/firestore';
import {getAuth,type Auth} from 'firebase-admin/auth';
import {afterAll,beforeAll,expect,it} from 'vitest';
import {buildFypDataset,FYP_ROOT,type FypDataset} from '../src/modules/dataset/fyp-dataset';
import {applyFypSeed,describeFypSeed,cleanupFypSeedDryRun} from '../src/modules/dataset/fyp-seed';
import {fypDigest} from '../src/modules/dataset/fyp-integrity';
import {UNIFIED_ADMIN_GATE} from '../src/modules/dataset/unified-admin-scope';
const project='demo-gainpath-fyp',out='../build/fyp-cohort-integration';
let app:App,db:Firestore,auth:Auth,dataset:FypDataset;
const password=randomBytes(24).toString('base64url'),tokens=new Map<string,string>(),proof:Record<string,unknown>={schemaVersion:1,projectId:project,databaseId:'(default)',liveFirebase:false,appCheck:'Functions emulator decoded test token, not production cryptographic attestation'};

function guard(){if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:18231'||process.env.FIREBASE_AUTH_EMULATOR_HOST!=='127.0.0.1:19131'||process.env.GCLOUD_PROJECT!==project)throw Error('Dedicated loopback emulators only.');}
const check=()=>[Buffer.from(JSON.stringify({alg:'none',typ:'JWT'})).toString('base64url'),Buffer.from(JSON.stringify({sub:'gainpath-fyp-node',aud:[`projects/${project}`],iat:Math.floor(Date.now()/1000),exp:Math.floor(Date.now()/1000)+3600})).toString('base64url'),''].join('.');
async function token(uid:string,refresh=false){if(!refresh&&tokens.has(uid))return tokens.get(uid)!;const u=await auth.getUser(uid);const r=await fetch('http://127.0.0.1:19131/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=emulator-key',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:u.email,password,returnSecureToken:true})});const body=await r.json() as any;if(!r.ok||!body.idToken)throw Error('Fictional emulator sign-in failed.');tokens.set(uid,body.idToken);return body.idToken as string;}
async function rawCall(uid:string,name:string,data:unknown,options:{region?:string;noAuth?:boolean;noApp?:boolean}={}){
 const headers:Record<string,string>={'Content-Type':'application/json'};if(!options.noAuth)headers.Authorization=`Bearer ${await token(uid)}`;if(!options.noApp)headers['X-Firebase-AppCheck']=check();
 const r=await fetch(`http://127.0.0.1:15031/${project}/${options.region??'asia-southeast1'}/${name}`,{method:'POST',headers,body:JSON.stringify({data})});const body=await r.json() as any;
 if(body.error||!r.ok){const error=new Error(body.error?.message??'Emulator command rejected') as Error&{code?:string};error.code=body.error?.status;throw error;}return body.result;
}
const call=(uid:string,operation:string,data:unknown)=>rawCall(uid,'fypDatasetCommand',{schemaVersion:1,operation,data});
const q=(fields:Record<string,unknown>={})=>({schemaVersion:1,organizationId:'gainpath',...fields});
async function directory(uid:string,root:string,collectionId:string,filters:{field:string;value:string}[]){const r=await fetch(`http://127.0.0.1:18231/v1/projects/${project}/databases/(default)/documents/${root}:runQuery`,{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${await token(uid)}`},body:JSON.stringify({structuredQuery:{from:[{collectionId}],where:filters.length===1?{fieldFilter:{field:{fieldPath:filters[0].field},op:'EQUAL',value:{stringValue:filters[0].value}}}:{compositeFilter:{op:'AND',filters:filters.map(f=>({fieldFilter:{field:{fieldPath:f.field},op:'EQUAL',value:{stringValue:f.value}}}))}},limit:100}})});const data=await r.json() as any;if(!r.ok)throw Error('Rules denied directory');return data.filter((r:any)=>r.document).map((r:any)=>r.document.name.split('/').at(-1));}
async function protectedSnapshot(){const result:Record<string,unknown>={};for(const p of ['users/baseline-member','users/baseline-admin','orgs/gainpath','orgs/gainpath/members/baseline-member','orgs/gainpath/members/baseline-admin'])result[p]=(await db.doc(p).get()).data();for(const col of ['transactions','bookings','rewardBalances','rewardAwards','membershipAccounts','notifications','workoutSessions'])result[`orgs/gainpath/${col}`]=(await db.collection(`orgs/gainpath/${col}`).get()).docs.map(d=>({id:d.id,data:d.data()}));return result;}
beforeAll(async()=>{
 guard();mkdirSync(out,{recursive:true});app=initializeApp({projectId:project},'fyp-integration');db=getFirestore(app);auth=getAuth(app);
 dataset=await buildFypDataset({anchorMillis:Date.now()-2000});
 const cleared=await fetch(`http://127.0.0.1:18231/emulator/v1/projects/${project}/databases/(default)/documents`,{method:'DELETE'});if(!cleared.ok)throw Error('Emulator clear failed');
 await auth.deleteUsers([...dataset.identities.map(u=>u.uid),'baseline-member','baseline-admin']);
 await db.doc('orgs/gainpath').set({schemaVersion:1,organizationId:'gainpath',status:'active'});
 for(const[uid,role]of[['baseline-member','member'],['baseline-admin','admin']]){
  await auth.createUser({uid,email:`${uid}@baseline.invalid`,emailVerified:true,password});
  await db.doc(`users/${uid}`).set({organizationId:'gainpath',role,primaryBranchId:'main'});
  await db.doc(`orgs/gainpath/members/${uid}`).set({schemaVersion:1,organizationId:'gainpath',userId:uid,role,status:'active',branchIds:['main']});
 }
 await db.doc('orgs/gainpath/coaches/baseline-coach').set({status:'published',displayName:'Baseline fictional Coach'});
 await db.doc('orgs/gainpath/content/baseline-tutorial').set({status:'published',kind:'routine',title:'Baseline fictional tutorial'});
 const before=await protectedSnapshot(),seed=await applyFypSeed({firestore:db,auth,dataset,emulatorPassword:password});proof.seed=seed.validation;proof.plan=describeFypSeed(dataset);proof.protectedBefore=before;
},60000);
afterAll(async()=>{if(db){proof.protectedAfter=await protectedSnapshot();try{proof.cleanup=await cleanupFypSeedDryRun({firestore:db,auth,dataset});}catch{proof.cleanup={executable:false,status:'changed_owned_sources_preserved_after_lifecycle_tests'};}writeFileSync(`${out}/integration-proof.json`,JSON.stringify(proof,null,2));}await db?.terminate();if(app)await deleteApp(app);});
it('normal email/password sign-in resolves a server-owned session without canonical membership',async()=>{
 const session=await rawCall(dataset.memberIds[0],'fypDatasetSessionCommand',{schemaVersion:1});expect(session).toMatchObject({datasetId:'fyp-v1',rootPath:FYP_ROOT,role:'member',fictional:true,user:{role:'member'},member:{role:'member'}});
 expect((await db.doc(`users/${dataset.memberIds[0]}`).get()).exists).toBe(false);expect((await db.doc(`orgs/gainpath/members/${dataset.adminId}`).get()).exists).toBe(false);
 proof.normalAuthSession=true;
});
it('actual Rules-backed published queries cannot cross the dataset boundary',async()=>{
 await expect(directory(dataset.memberIds[0],FYP_ROOT,'coaches',[{field:'status',value:'published'}])).rejects.toThrow();
 const coaches=await directory(dataset.adminId,FYP_ROOT,'coaches',[{field:'status',value:'published'}]);expect(coaches.length).toBe(7);expect(coaches).not.toContain('baseline-coach');
 const tutorials=await directory(dataset.memberIds[0],FYP_ROOT,'content',[{field:'status',value:'published'},{field:'kind',value:'routine'}]);expect(tutorials).toHaveLength(12);
 expect(await directory('baseline-admin','orgs/gainpath','coaches',[{field:'status',value:'published'}])).toEqual(['baseline-coach']);
 await expect(directory('baseline-member',FYP_ROOT,'coaches',[{field:'status',value:'published'}])).rejects.toThrow();
 await expect(directory(dataset.memberIds[0],'orgs/gainpath','coaches',[{field:'status',value:'published'}])).rejects.toThrow();
 proof.publishedIsolation={coaches:coaches.length,tutorials:tutorials.length};
});
it('owned fictional history, Programs and descriptive Module12 use the same source observations',async()=>{
 const history=await call(dataset.memberIds[0],'member.history',q());expect(history).toMatchObject({fictional:true,provenance:'recordedFixture'});expect(history.records).toHaveLength(3);expect(history.records.every((r:any)=>r.payload.provenance==='recordedFixture'&&r.payload.userId===dataset.memberIds[0])).toBe(true);
 const programs=await call(dataset.memberIds[0],'module/workoutProgramCommand',q({action:'list'}));expect(programs.programs).toHaveLength(3);
 const range={startAtMillis:dataset.legacyDataset.window.startAtMillis,endAtMillis:Date.now()};
 const report=await call(dataset.adminId,'module/adminWorkoutReportingCommand',q(range));expect(report).toMatchObject({fictional:true,classification:'fictional_synthetic_observation'});expect(report.totals.sessions).toBeGreaterThan(40);expect(JSON.stringify(report)).not.toContain(dataset.memberIds[0]);
 const census=await call(dataset.adminId,'module/adminReportingCommand',q(range));expect(census.currentAccounts.members).toBe(18);expect(census.currentAccounts.coaches).toBe(7);
 const baseline=await rawCall('baseline-admin','adminReportingCommand',q(range));expect(baseline.currentAccounts.members).toBe(1);
 proof.sharedHistoryAndReports={historySessions:history.records.length,report,census:census.currentAccounts,programs:programs.programs.length,baselineCensus:baseline.currentAccounts};
});
it('existing candidate availability and current tutorial destinations resolve only in the cohort',async()=>{
 const availability=await call(dataset.memberIds[0],'module/getCoachAvailabilityCommand',q({coachId:dataset.coachIds[0],firstLocalDate:dataset.legacyDataset.bookingDate,dayCount:1}));expect(availability).toBeTruthy();
 const tutorial=await call(dataset.memberIds[0],'member.routine',q({routineId:dataset.publicationIds[0]}));expect(tutorial.status).toBe('published');expect(tutorial.exercises[0].tutorialSteps.length).toBeGreaterThan(0);
 await expect(call(dataset.memberIds[0],'member.coach',q({coachId:'baseline-coach'}))).rejects.toThrow();proof.destinationsAndAvailability=true;
});
it('legacy registration, payment, rewards, competition and Admin endpoints reject assigned actors',async()=>{
 const member=dataset.memberIds[0];
 for(const[name,data,region]of[
  ['provisionMemberRegistration',{schemaVersion:1,displayName:'Unauthorized old client'},'us-central1'],
  ['adminReportingCommand',q({startAtMillis:dataset.anchorMillis-86400000,endAtMillis:Date.now()}),'asia-southeast1'],
  ['listAdminBookingPaymentsCommand',q(),'us-central1'],
  ['getMembershipAccessCommand',q({feature:'exercise',resourceId:dataset.legacyDataset.memberScenarios[0].exerciseId}),'us-central1'],
  ['getCoachAvailabilityCommand',q({coachId:dataset.coachIds[0],dayCount:1}),'us-central1'],
  ['verifiedRewardsCommand',q({action:'overview'}),'asia-southeast1'],
  ['miniGameRoundCommand',q({action:'begin',gameId:'move-catch-v1',requestId:'a'.repeat(32)}),'asia-southeast1'],
  ['miniGameRoundCommand',q({action:'competition',command:{action:'preference'}}),'asia-southeast1'],
 ]as const)await expect(rawCall(name==='adminReportingCommand'||name==='listAdminBookingPaymentsCommand'?dataset.adminId:member,name,data,{region})).rejects.toMatchObject({code:'PERMISSION_DENIED'});
 expect((await db.doc(`orgs/gainpath/members/${member}`).get()).exists).toBe(false);proof.legacyDenials=true;
});
it('rejects missing AppCheck/Auth, client scope selection, wrong roles and unassigned actors',async()=>{
 await expect(rawCall(dataset.memberIds[0],'fypDatasetSessionCommand',{schemaVersion:1},{noAuth:true})).rejects.toThrow();
 await expect(rawCall(dataset.memberIds[0],'fypDatasetSessionCommand',{schemaVersion:1},{noApp:true})).rejects.toThrow();
 await expect(rawCall('baseline-member','fypDatasetSessionCommand',{schemaVersion:1})).rejects.toThrow();
 await expect(call(dataset.memberIds[0],'admin.queue.list',q({kind:'trainer'}))).rejects.toThrow();
 await expect(call(dataset.adminId,'member.history',q())).rejects.toThrow();
 await expect(call(dataset.memberIds[0],'member.history',{schemaVersion:1,cohortId:'foreign'})).rejects.toThrow();proof.authorizationNegatives=true;
});
it('automatically delivers qualified recommendations and replays without duplicate inbox entries', async () => {
  const admin = dataset.adminId, uid = dataset.memberIds[0];
  const command = (kind: string, continuation: string | null) =>
    q({kind, commandId: `fyp-automatic-${kind}`, continuation});
  await expect(call(uid, 'admin.queue.automatic', command('content', null))).rejects.toThrow();
  for (const kind of ['content', 'trainer']) {
    let continuation: string | null = null, finalInput: unknown, result: any;
    for (let page = 0; page < 11; page++) {
      finalInput = command(kind, continuation);
      result = await call(admin, 'admin.queue.automatic', finalInput);
      continuation = result.summary.nextCursor;
      if (!continuation) break;
    }
    expect(result.summary.status).toBe('complete');
    expect(result.summary.generated).toBeGreaterThanOrEqual(5);
    expect(result.delivery.delivered).toBeGreaterThan(0);
    const inboxCount = (await db.collection(`${FYP_ROOT}/notifications`).count().get()).data().count;
    expect(await call(admin, 'admin.queue.automatic', finalInput)).toEqual(result);
    expect((await db.collection(`${FYP_ROOT}/notifications`).count().get()).data().count).toBe(inboxCount);
    const page = await call(admin, 'admin.queue.monitor', q({kind,status:'all',
      startAtMillis:dataset.anchorMillis-86400000,endAtMillis:Date.now(),exerciseId:null,
      category:null,specialization:null,afterLeadId:null,limit:25}));
    const lead = page.leads.find((row: any) => row.memberId === uid);
    expect(lead).toMatchObject({status:'sent', ranking:{model:null,origin:'deterministic_fallback'}});
    expect(page.deliveredLeadIds).toContain(lead.leadId);
    expect(page.leads.some((row: any) => row.memberId === dataset.memberIds[8])).toBe(false);
    const id = lead.decision.recipientRecommendationId;
    const lookup = q({action:'get',commandId:null,expectedRevision:null,recommendationId:id});
    const detail = await call(uid, 'member.recommendation.command', lookup);
    expect(detail.state).toBe('available');
    await expect(call(dataset.memberIds[1], 'member.recommendation.command', lookup)).rejects.toMatchObject({code:'PERMISSION_DENIED'});
    const destination = kind === 'trainer'
      ? await call(uid, 'member.coach', q({coachId:detail.target.coachId}))
      : await call(uid, 'member.routine', q({routineId:detail.target.destination.routineId}));
    expect(destination.status).toBe('published');
  }
  const inbox = await call(uid, 'module/module9MemberCommandCallable', q({action:'inbox'}));
  expect(inbox.records.filter((row: any) => row.recommendation?.state === 'available')).toHaveLength(2);
  proof.automaticMemberDelivery = true;
},300000);
it.skipIf(process.env.FYP_WITH_FLUTTER!=='1')('ordinary Flutter Admin and Member compositions consume the seeded default emulator graph and capture UI',async()=>{
 async function flutter(application:string,test:string){return new Promise<number>((done,reject)=>{const log=`${out}/${application}-client-output-${dataset.anchorMillis}.log`;proof[`${application}ClientLog`]=log;let pending='';const emit=(chunk:string)=>{pending+=chunk;const lines=pending.split('\n');pending=lines.pop()!;for(const line of lines){const clean=line.replaceAll(password,'[ephemeral emulator credential redacted]')+'\n';writeFileSync(log,clean,{flag:'a'});process.stdout.write(clean);}};const child=spawn('C:/flutter/bin/cache/dart-sdk/bin/dart.exe',['C:/flutter/bin/cache/flutter_tools.snapshot','test','--no-pub','--reporter','expanded',test],{cwd:resolve(`../apps/${application}`),env:{...process.env,FYP_EMULATOR_PASSWORD:password},stdio:['ignore','pipe','pipe'],windowsHide:true});child.stdout.on('data',c=>emit(String(c)));child.stderr.on('data',c=>emit(String(c)));child.once('error',reject);child.once('close',code=>{emit('\n');done(code??1);});});}
 expect(await flutter('admin_web','test/emulator/fyp_ordinary_admin_emulator_test.dart')).toBe(0);
 expect(await flutter('mobile','test/emulator/fyp_ordinary_member_emulator_test.dart')).toBe(0);proof.ordinaryFlutterCompositions=true;
});
it('consent revocation redacts a previously available recommendation and assignment revocation closes the session',async()=>{
 // Member02 consumes the exact Admin-widget sends. Keep Member01's separate
 // callable-delivery scenario available for the revocation proof.
 const uid=dataset.memberIds[0],consent=await call(uid,'member.consent.get',{schemaVersion:2,organizationId:'gainpath'});
 const recipient=(await db.collection(`${FYP_ROOT}/recommendationRecipients`).get()).docs.find(d=>d.data().memberId===uid)?.id;expect(recipient).toBeTruthy();
 const lookup=q({action:'get',commandId:null,expectedRevision:null,recommendationId:recipient});expect((await call(uid,'member.recommendation.command',lookup)).state).toBe('available');
 await call(uid,'member.consent.set',{schemaVersion:2,organizationId:'gainpath',commandId:'fyp-revoke-delivery',expectedRevision:consent.revision,purpose:'recommendationDelivery',action:'revoke'});
 expect(await call(uid,'member.recommendation.command',lookup)).toMatchObject({state:'unavailable',target:null,exerciseLabel:null,explanations:[]});
 const assignment=db.doc(`datasetAssignments/${uid}`);await assignment.update({enabled:false,revision:2});await expect(rawCall(uid,'fypDatasetSessionCommand',{schemaVersion:1})).rejects.toThrow();
 await assignment.update({enabled:true,revision:1});proof.revocations=true;
});
it('saved workout automatically reaches the real inbox and Admin monitor without an Admin command', async () => {
  const uid = dataset.memberIds[1];
  // Keep this test focused on a newly saved camera-summary event. Separate
  // coverage below exercises permission-triggered replay of sample history.
  const oldHistory = await db.collection(`${FYP_ROOT}/members/${uid}/syntheticObservations`).get();
  for (const row of oldHistory.docs) await row.ref.delete();
  const notice = await call(uid, 'workout.member.consent.notice', q());
  let consent = await call(uid, 'workout.member.consent.get', {schemaVersion:2,organizationId:'gainpath'});
  for (const purpose of ['exerciseInsights','recommendationGeneration','recommendationDelivery']) {
    await call(uid, 'workout.member.consent.set', {schemaVersion:2,organizationId:'gainpath',
      commandId:'allow-workout-'+purpose,expectedRevision:consent.revision,purpose,action:'grant',
      noticePolicyId:notice.policyId,acceptedNoticeVersion:notice.noticeVersion,acceptedContentVersion:notice.contentVersion});
    consent = await call(uid,'workout.member.consent.get',{schemaVersion:2,organizationId:'gainpath'});
  }
  const exercise = DEMO_EXERCISES.squat, id = 'new-unscored-workout';
  const payload = demoWorkoutPayload(uid,id,exercise,null,Date.now()-1000);
  const command = {schemaVersion:1,organizationId:'gainpath',memberId:uid,consented:true,kind:'session',id,baseDigest:null,payload};
  await call(uid,'member.workout.backup',{action:'save',command});
  // Await the Firestore emulator event. No direct generation/evaluation call is made here.
  let rows: any[] = [];
  for (let attempt=0;attempt<40;attempt++) {
    const page = await call(uid,'workout.member.recommendation.list',q({history:false,afterId:null}));
    rows=page.recommendations;
    if(rows.length)break;
    await new Promise(resolve=>setTimeout(resolve,500));
  }
  expect(rows.filter((r:any)=>r.kind==='content')).toHaveLength(1);
  const recommendation=rows.find((r:any)=>r.kind==='content');
  expect(recommendation).toMatchObject({mode:'workout_backup',state:'available',kind:'content'});
  const inbox=await call(uid,'member.inbox',q());
  expect(inbox.records.some((r:any)=>r.recommendation?.recommendationId===recommendation.recommendationId)).toBe(true);
  const monitor=await call(dataset.adminId,'workout.admin.queue.list',q({afterId:null}));
  expect(monitor.records.some((r:any)=>r.id===recommendation.recommendationId&&r.status==='delivered'&&r.memberId===uid)).toBe(true);
  await call(uid,'member.workout.backup',{action:'save',command});
  const second={...command,id:'second-unscored',payload:demoWorkoutPayload(uid,'second-unscored',exercise,null,Date.now()-1000)};
  await call(uid,'member.workout.backup',{action:'save',command:second});
  await new Promise(resolve=>setTimeout(resolve,1200));
  const repeated=await call(uid,'workout.member.recommendation.list',q({history:true,afterId:null}));
  expect(repeated.recommendations.filter((r:any)=>r.kind==='content')).toHaveLength(1);
  expect(repeated.recommendations.filter((r:any)=>r.kind==='trainer').length).toBeLessThanOrEqual(1);
  await expect(call(dataset.memberIds[2],'member.recommendation.command',q({
    recommendationId:recommendation.recommendationId,action:'get',commandId:null,expectedRevision:null,
  }))).rejects.toThrow();
  await call(uid,'member.recommendation.command',q({recommendationId:recommendation.recommendationId,
    action:'dismiss',commandId:'dismiss-auto',expectedRevision:recommendation.revision}));
  expect((await call(uid,'workout.member.recommendation.list',q({history:false,afterId:null}))).recommendations.some((r:any)=>r.recommendationId===recommendation.recommendationId)).toBe(false);
  proof.workoutEventDelivered={id:recommendation.recommendationId,source:'unscored synthesized emulator workout payload',actualCamera:false};
},60000);
it('granting summary personalization automatically replays existing sample history once', async () => {
  const uid = dataset.memberIds[3];
  const notice = await call(uid, 'workout.member.consent.notice', q());
  let consent = await call(uid, 'workout.member.consent.get', {schemaVersion:2,organizationId:'gainpath'});
  for (const purpose of ['exerciseInsights','recommendationGeneration','recommendationDelivery']) {
    await call(uid, 'workout.member.consent.set', {schemaVersion:2,organizationId:'gainpath',
      commandId:'history-permission-'+purpose,expectedRevision:consent.revision,purpose,action:'grant',
      noticePolicyId:notice.policyId,acceptedNoticeVersion:notice.noticeVersion,acceptedContentVersion:notice.contentVersion});
    consent = await call(uid,'workout.member.consent.get',{schemaVersion:2,organizationId:'gainpath'});
  }
  let rows: any[] = [];
  for (let attempt=0;attempt<40;attempt++) {
    rows=(await call(uid,'workout.member.recommendation.list',q({history:false,afterId:null}))).recommendations;
    if(rows.some(r=>r.kind==='content'))break;
    await new Promise(resolve=>setTimeout(resolve,500));
  }
  expect(rows.some(r=>r.kind==='content')).toBe(true);
  const saved=await db.doc(`${FYP_ROOT}/canonicalRecommendations/${rows.find(r=>r.kind==='content').recommendationId}`).get();
  expect(saved.data()?.suggestion.source.kind).toBe('recorded_history');
  expect((await db.collection(`${FYP_ROOT}/members/${uid}/workoutBackups`).get()).empty).toBe(true);
  const replay=async()=> {
    let afterId: string|null=null;
    for(let page=0;page<20;page++) {
      const result=await call(uid,'workout.member.history.replay',q({afterId}));
      afterId=result.nextAfterId;
      if(!afterId)break;
    }
  };
  await replay();
  const noticeIds = async () => (await db.collection(`${FYP_ROOT}/notifications`).where('recipientId','==',uid).get())
    .docs.filter(d=>d.data().mode==='workout_backup').map(d=>d.id).sort();
  const before=await noticeIds();
  await replay();
  await replay();
  expect(await noticeIds()).toEqual(before);
  proof.automaticHistoryReplay=true;
},60000);
it('preserves every protected baseline and leaves paid/reward/workout acceptance paths empty',async()=>{
 expect(await protectedSnapshot()).toEqual(proof.protectedBefore);
 for(const col of['transactions','payments','rewardBalances','rewardAwards','memberPrograms','workoutSessions'])expect((await db.collection(`${FYP_ROOT}/${col}`).get()).empty).toBe(true);proof.baselineUnchanged=true;
});

it('bulk Member feed retains legacy history and measures authenticated baseline versus optimized calls',async()=>{
 const uid=dataset.memberIds[3],admin=dataset.adminId;
 const baseline=(actor:string,operation:string,data:unknown)=>rawCall(actor,'fypDatasetBaselineCommand',{schemaVersion:1,operation,data});
 async function oldMember(){
  const inbox=await baseline(uid,'member.inbox',q());
  const records=[];let requests=1;
  for(const notice of inbox.records){
   if(!notice.recommendation)continue;
   records.push(await baseline(uid,'member.recommendation.command',q({recommendationId:notice.recommendation.recommendationId,
    action:'get',commandId:null,expectedRevision:null})));requests++;
  }
  return{records,requests};
 }
 const latest=await call(uid,'member.recommendation.list',q({history:true,afterId:null}));
 const original=await oldMember();
 expect(latest.recommendations.map((r:any)=>r.recommendationId).sort()).toEqual(original.records.map((r:any)=>r.recommendationId).sort());
 expect(latest.recommendations.some((r:any)=>r.mode==='workout_backup')).toBe(true);
 expect(latest.recommendations.some((r:any)=>r.mode==='synthetic_local')).toBe(true);
 await expect(call(dataset.adminId,'member.recommendation.list',q({history:true,afterId:null}))).rejects.toThrow();
 const samples:any[]=[];
 for(let round=0;round<3;round++){
  let start=performance.now();const before=await oldMember();const beforeMillis=performance.now()-start;
  start=performance.now();await call(uid,'member.recommendation.list',q({history:true,afterId:null}));const afterMillis=performance.now()-start;
  start=performance.now();await baseline(admin,'workout.session.access',q());await baseline(admin,'workout.admin.queue.list',q({afterId:null}));const adminBeforeMillis=performance.now()-start;
  start=performance.now();await call(admin,'workout.admin.queue.list',q({afterId:null}));const adminAfterMillis=performance.now()-start;
  samples.push({round,member:{beforeRequests:before.requests,afterRequests:1,beforeMillis,afterMillis},admin:{beforeRequests:2,afterRequests:1,beforeMillis:adminBeforeMillis,afterMillis:adminAfterMillis}});
 }
 proof.optimizationPerformance={environment:'loopback Firebase Emulator; authenticated HTTP; warmed endpoints; same records; no camera or live latency claim',samples};
 mkdirSync('../build/module13-final-optimization',{recursive:true});
 writeFileSync('../build/module13-final-optimization/performance.json',JSON.stringify(proof.optimizationPerformance,null,2));
},120000);

it('ordinary authenticated Member backup event delivers, replays, dismisses and is visible in unified Admin monitoring',async()=>{
 const uid='baseline-member',admin='baseline-admin';
 const gate={schemaVersion:1,organizationId:'gainpath',cohortId:'fyp-v1',rootPath:FYP_ROOT,enabled:true,version:'unified-admin-v1'};
 await db.doc(UNIFIED_ADMIN_GATE).set(gate);
 await db.doc(`${FYP_ROOT}/unifiedSampleOwnership/${fypDigest(UNIFIED_ADMIN_GATE)}`).set({
  schemaVersion:1,seedId:'unified-admin-business-v1',path:UNIFIED_ADMIN_GATE,digest:fypDigest(gate)});
 // Explicit synthetic emulator inputs. This is not a camera or live account acceptance test.
 for(const collection of ['exerciseVideos','content']){
  const rows=await db.collection(`${FYP_ROOT}/${collection}`).get();
  for(const row of rows.docs)await db.doc(`orgs/gainpath/${collection}/${row.id}`).set(row.data());
 }
 const member=(operation:string,data:unknown)=>rawCall(uid,'module13MemberCommand',{schemaVersion:1,operation,data});
 const notice=await member('member.consent.notice',q());
 let consent=await member('member.consent.get',{schemaVersion:2,organizationId:'gainpath'});
 for(const purpose of ['exerciseInsights','recommendationGeneration','recommendationDelivery']){
  await member('member.consent.set',{schemaVersion:2,organizationId:'gainpath',commandId:'ordinary-'+purpose,
   expectedRevision:consent?.revision??0,purpose,action:'grant',noticePolicyId:notice.policyId,
   acceptedNoticeVersion:notice.noticeVersion,acceptedContentVersion:notice.contentVersion});
  consent=await member('member.consent.get',{schemaVersion:2,organizationId:'gainpath'});
 }
 const id='ordinary-unscored',payload=demoWorkoutPayload(uid,id,DEMO_EXERCISES.squat,null,Date.now()-1000);
 const command={schemaVersion:1,organizationId:'gainpath',memberId:uid,consented:true,kind:'session',id,baseDigest:null,payload};
 await rawCall(uid,'workoutBackupCommand',{action:'save',command});
 let rows:any[]=[];
 for(let attempt=0;attempt<40;attempt++){
  rows=(await member('member.recommendation.list',q({history:false,afterId:null}))).recommendations;
  if(rows.length)break;
  await new Promise(resolve=>setTimeout(resolve,500));
 }
 expect(rows).toHaveLength(1);const recommendation=rows[0];
 expect(recommendation).toMatchObject({mode:'workout_backup',kind:'content',state:'available'});
 const saved=await db.doc(`orgs/gainpath/members/${uid}/workoutBackups/session-${id}`).get();expect(saved.exists).toBe(true);
 const inbox=(await db.collection('orgs/gainpath/notifications').where('recipientId','==',uid).get()).docs;
 expect(inbox).toHaveLength(1);expect(inbox[0].data().recommendationId).toBe(recommendation.recommendationId);
 const monitor=await call(admin,'admin.unified.recommendations',q({operation:'admin.queue.list',input:q({afterId:null})}));
 expect(monitor.records.some((r:any)=>r.memberId===uid&&r.id===recommendation.recommendationId)).toBe(true);
 expect(monitor.records.some((r:any)=>dataset.memberIds.includes(r.memberId))).toBe(true);
 const detail=await call(admin,'admin.unified.recommendations',q({operation:'admin.queue.detail',input:q({id:recommendation.recommendationId})}));
 expect(detail.id).toBe(recommendation.recommendationId);
 await expect(call(uid,'admin.unified.recommendations',q({operation:'admin.queue.list',input:q({afterId:null})}))).rejects.toThrow();
 await member('member.history.replay',q({afterId:null}));await member('member.history.replay',q({afterId:null}));
 await rawCall(uid,'workoutBackupCommand',{action:'save',command});
 expect((await db.collection('orgs/gainpath/notifications').where('recipientId','==',uid).get()).size).toBe(1);
 await member('member.recommendation.command',q({recommendationId:recommendation.recommendationId,
  action:'dismiss',commandId:'ordinary-dismiss',expectedRevision:recommendation.revision}));
 expect((await member('member.recommendation.list',q({history:false,afterId:null}))).recommendations).toHaveLength(0);
 expect((await member('member.recommendation.list',q({history:true,afterId:null}))).recommendations[0].state).toBe('dismissed');
 proof.ordinaryWorkoutEventDelivered={id:recommendation.recommendationId,source:'synthetic emulator payload',actualCamera:false,liveFirebase:false};
},120000);
