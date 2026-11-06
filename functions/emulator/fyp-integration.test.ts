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
const project='demo-gainpath-fyp',out='../build/fyp-cohort-integration';
let app:App,db:Firestore,auth:Auth,dataset:FypDataset;
const password=randomBytes(24).toString('base64url'),tokens=new Map<string,string>(),proof:Record<string,unknown>={schemaVersion:1,projectId:project,databaseId:'(default)',liveFirebase:false,appCheck:'Functions emulator decoded test token, not production cryptographic attestation'};
let trainer:any,content:any;
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
 const coaches=await directory(dataset.memberIds[0],FYP_ROOT,'coaches',[{field:'status',value:'published'}]);expect(coaches.length).toBe(7);expect(coaches).not.toContain('baseline-coach');
 const tutorials=await directory(dataset.memberIds[0],FYP_ROOT,'content',[{field:'status',value:'published'},{field:'kind',value:'routine'}]);expect(tutorials).toHaveLength(12);
 expect(await directory('baseline-member','orgs/gainpath','coaches',[{field:'status',value:'published'}])).toEqual(['baseline-coach']);
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
it('derives educational needs from the same observations and ranks multiple eligible candidates',async()=>{
 for(const kind of ['trainer','content']){
  let continuation:string|null=null,generated:any;for(let page=0;page<11;page++){generated=await call(dataset.adminId,'admin.queue.refresh',q({kind,commandId:`fyp-${kind}-first`,continuation}));continuation=generated.summary.nextCursor;if(!continuation)break;}proof[`${kind}Generation`]=generated.summary;console.info('FYP generation aggregate',JSON.stringify(generated.summary));expect(generated.summary.status).toBe('complete');expect(generated.summary.generated).toBeGreaterThanOrEqual(5);
  const list=await call(dataset.adminId,'admin.queue.list',q({kind,status:'all',startAtMillis:dataset.anchorMillis-86400000,endAtMillis:Date.now(),exerciseId:null,category:null,specialization:null,afterLeadId:null,limit:25}));
  const lead=list.leads.find((l:any)=>l.memberId===dataset.memberIds[0]);expect(lead).toMatchObject({exerciseId:'F3b8xIr8ynBDd3gEICKX',evidence:{scoredSessions:3,estimatedFormScorePercent:60},ranking:{model:'gainpath-demo-structured-mock-v1'}});
  expect(list.leads.some((l:any)=>l.memberId===dataset.memberIds[6])).toBe(false);expect(list.leads.some((l:any)=>l.memberId===dataset.memberIds[8])).toBe(false);
  if(kind==='trainer')trainer=lead;else content=lead;proof[kind]={generation:generated.summary,lead};
 }
});
it('explicit Admin Send delivers once through existing lifecycle and Member current destination',async()=>{
 for(const lead of[trainer,content]){
  expect(lead).toBeTruthy();const input=q({leadId:lead.leadId,commandId:`fyp-send-${lead.kind}`,expectedRevision:lead.revision,action:'send',reason:null});
  const sent=await call(dataset.adminId,'admin.queue.decide',input);expect(sent.outcome).toBe('prepared');expect(await call(dataset.adminId,'admin.queue.decide',input)).toEqual(sent);
  const recipient=sent.recipientRecommendationId;expect(recipient).toBeTruthy();
  const detail=await call(dataset.memberIds[0],'member.recommendation.command',q({action:'get',commandId:null,expectedRevision:null,recommendationId:recipient}));expect(detail.state).toBe('available');
  await expect(call(dataset.memberIds[1],'member.recommendation.command',q({action:'get',commandId:null,expectedRevision:null,recommendationId:recipient}))).rejects.toMatchObject({code:'PERMISSION_DENIED'});
  const destination=detail.kind==='trainer'?await call(dataset.memberIds[0],'member.coach',q({coachId:detail.target.coachId})):await call(dataset.memberIds[0],'member.routine',q({routineId:detail.target.destination.routineId}));expect(destination.status).toBe('published');
 }
 const inbox=await call(dataset.memberIds[0],'module/module9MemberCommandCallable',q({action:'inbox'}));expect(inbox.records).toHaveLength(2);const others=await call(dataset.memberIds[1],'module/module9MemberCommandCallable',q({action:'inbox'}));expect(others.records).toHaveLength(0);
 expect((await db.collection(`${FYP_ROOT}/recommendationDeliveryReceipts`).get()).size).toBe(2);proof.adminSendMemberDelivery=true;
});
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
it('preserves every protected baseline and leaves paid/reward/workout acceptance paths empty',async()=>{
 expect(await protectedSnapshot()).toEqual(proof.protectedBefore);
 for(const col of['transactions','payments','rewardBalances','rewardAwards','memberPrograms','workoutSessions'])expect((await db.collection(`${FYP_ROOT}/${col}`).get()).empty).toBe(true);proof.baselineUnchanged=true;
});
