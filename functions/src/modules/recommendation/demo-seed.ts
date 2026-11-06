/** Bounded Auth/Firestore/Storage EMULATOR seeder. No live apply mode exists here. */
import {createHash} from 'node:crypto';
import {Firestore} from 'firebase-admin/firestore';
import type {Auth,UserRecord} from 'firebase-admin/auth';
import type {getStorage} from 'firebase-admin/storage';
import {DomainError} from '../../platform/errors';
import {FirestoreStore} from '../../platform/firestore/firestore-store';
import type {DocumentData} from '../../platform/firestore/store';
import {digestOf} from '../workouts/workout-backup-validation';
import {evaluateTrainerCandidates} from './trainer-candidate-eligibility';
import {evaluateContentCandidates} from './content-candidate-eligibility';
import {createRecommendationConsentV2Command,parseRecommendationConsentV2} from './recommendation-consent-v2';
import {MODULE13_DEMO_DATABASE,MODULE13_DEMO_PROJECT,MODULE13_DEMO_ROOT,validateModule13DemoDataset,type Module13DemoDataset,type DemoStorageAsset,type DemoAuthUser} from './demo-dataset';

type DemoBucket=ReturnType<ReturnType<typeof getStorage>['bucket']>;
export interface DemoSeedClients {firestore:Firestore;auth:Auth;bucket?:DemoBucket}
export interface DemoSeedOptions extends DemoSeedClients {dataset:Module13DemoDataset}
const fail=(message='Dedicated Module13 demo emulators are required.')=>new DomainError('failed-precondition',message);
const bytesHash=(bytes:Buffer)=>createHash('sha256').update(bytes).digest('hex');
const owner=(path:string)=>`module13DemoOwnership/${digestOf(path)}`;
const authOwner=(uid:string)=>`module13DemoAuthOwnership/${uid}`;
const isConsent=(path:string)=>path.startsWith(`${MODULE13_DEMO_ROOT}/recommendationConsent`);
const isNotFound=(error:unknown)=>!!error&&typeof error==='object'&&'code'in error&&['auth/user-not-found',404,'404'].includes((error as {code:any}).code);
const record=(value:unknown):DocumentData=>value as DocumentData;

export function guardModule13DemoSeed(clients:DemoSeedClients):void{
 const db=clients.firestore,b=db as unknown as {projectId?:unknown;databaseId?:unknown;_settings?:{servicePath?:unknown;port?:unknown;ssl?:unknown}};
 if(!(db instanceof Firestore)||process.env.GCLOUD_PROJECT!==MODULE13_DEMO_PROJECT||process.env.GOOGLE_CLOUD_PROJECT!==MODULE13_DEMO_PROJECT||process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:18119'||process.env.FIREBASE_AUTH_EMULATOR_HOST!=='127.0.0.1:19099'||b.projectId!==MODULE13_DEMO_PROJECT||b.databaseId!==MODULE13_DEMO_DATABASE||b._settings?.servicePath!=='127.0.0.1'||b._settings?.port!==18119||b._settings?.ssl!==false||clients.auth.app.options.projectId!==MODULE13_DEMO_PROJECT)throw fail();
 if(clients.bucket){const endpoint=new URL(clients.bucket.storage.apiEndpoint);if(process.env.FIREBASE_STORAGE_EMULATOR_HOST!=='127.0.0.1:19119'||process.env.STORAGE_EMULATOR_HOST!=='http://127.0.0.1:19119'||endpoint.protocol!=='http:'||endpoint.hostname!=='127.0.0.1'||endpoint.port!=='19119'||clients.bucket.name!==`${MODULE13_DEMO_PROJECT}-credentials`)throw fail('Dedicated credential Storage emulator is required.');}
}

function runPath(d:Module13DemoDataset){return`module13DemoSeedRuns/${d.seedId}`;}
export function describeModule13DemoSeed(d:Module13DemoDataset){
 const integrity=validateModule13DemoDataset(d),paths=[...Object.keys(d.documents),...d.authUsers.map(u=>authOwner(u.uid)),runPath(d)].sort();
 const counts:Record<string,number>={};for(const p of paths){const col=p.split('/').slice(0,-1).join('/');counts[col]=(counts[col]??0)+1;}
 return{schemaVersion:1,seedId:d.seedId,projectId:d.manifest.projectId,databaseId:d.manifest.databaseId,organizationId:'gainpath',branchIds:['main','demo-other'],clockMillis:d.clockMillis,bookingDate:d.bookingDate,coaches:8,members:18,demoAdmins:1,authAccounts:d.authUsers.length,authUids:d.authUsers.map(u=>u.uid),firestoreDocuments:paths.length,firestoreDocumentPaths:paths,firestoreCounts:counts,storageObjects:d.storageAssets.length,storageBucket:d.storageBucket,storagePaths:d.storageAssets.map(a=>({path:a.path,sha256:a.sha256,size:Buffer.from(a.bytesBase64,'base64').length,contentType:a.contentType})),integrity,liveApplyEnabled:false,noRecommendationOutcomesSeeded:true};
}
function planIdentity(d:Module13DemoDataset):string{
 const docs=structuredClone(d.documents);delete docs['module13Demo/current'];for(const p of Object.keys(docs)){if(p.startsWith('module13DemoOwnership/'))delete docs[p];else if(p.includes('/certifications/'))delete docs[p].upload;else if(p.startsWith('module13DemoStorageOwnership/'))docs[p].generation=null;}
 return digestOf({seedId:d.seedId,clock:d.clockMillis,docs,auth:d.authUsers,assets:d.storageAssets.map(a=>({path:a.path,sha256:a.sha256}))});
}
function refreshManifest(d:Module13DemoDataset){for(const p of d.manifest.recordPaths)d.manifest.recordDigests[p]=digestOf(d.documents[p]);d.documents['module13Demo/current']=structuredClone(d.manifest) as unknown as DocumentData;}
function authMatches(user:UserRecord,spec:DemoAuthUser){return user.uid===spec.uid&&user.email===spec.email&&user.displayName===spec.displayName&&user.emailVerified===spec.emailVerified&&user.disabled===spec.disabled;}
async function getUser(auth:Auth,uid:string):Promise<UserRecord|undefined>{try{return await auth.getUser(uid);}catch(e){if(isNotFound(e))return undefined;throw new DomainError('unavailable','Could not verify the designated demo identity.');}}
async function storageMetadata(clients:DemoSeedClients,d:Module13DemoDataset,a:DemoStorageAsset,allowCreate:boolean):Promise<{generation:string;contentType:string;size:number}|null>{
 if(!clients.bucket)throw fail('Eight original credential assets require the dedicated Storage emulator.');guardModule13DemoSeed(clients);
 const file=clients.bucket.file(a.path),bytes=Buffer.from(a.bytesBase64,'base64');let metadata:any;
 try{[metadata]=await file.getMetadata();}catch(e){if(!isNotFound(e))throw new DomainError('unavailable','Could not verify demo asset ownership.');if(!allowCreate)return null;
  await file.save(bytes,{resumable:false,metadata:{contentType:a.contentType,metadata:{module13SeedId:d.seedId,sha256:a.sha256}},preconditionOpts:{ifGenerationMatch:0}});[metadata]=await file.getMetadata();
 }
 if(metadata.metadata?.module13SeedId!==d.seedId||metadata.metadata?.sha256!==a.sha256||metadata.contentType!==a.contentType||Number(metadata.size)!==bytes.length||typeof metadata.generation!=='string'||!/^\d+$/.test(metadata.generation))throw fail('A demo credential object collides or has changed.');
 const [stored]=await file.download({validation:false});if(bytesHash(stored)!==a.sha256)throw fail('Demo credential asset bytes have changed.');
 return{generation:metadata.generation,contentType:metadata.contentType,size:Number(metadata.size)};
}
function bindAsset(d:Module13DemoDataset,a:DemoStorageAsset,upload:{generation:string;contentType:string;size:number}){
 d.documents[a.credentialPath].upload={...upload};d.documents[`${a.credentialPath}/history/2`].upload={...upload};d.documents[`module13DemoStorageOwnership/${digestOf(a.path)}`].generation=upload.generation;
}
async function preflight(clients:DemoSeedClients,d:Module13DemoDataset,identity:string){
 const db=clients.firestore,run=await db.doc(runPath(d)).get();if(run.exists&&(run.data()?.seedId!==d.seedId||run.data()?.planIdentity!==identity))throw fail('A different demo plan already owns this seed identity.');
 // Resolve existing objects before comparing exact records, preserving actual SDK generations.
 for(const a of d.storageAssets){const meta=await storageMetadata(clients,d,a,false);if(meta)bindAsset(d,a,meta);}refreshManifest(d);
 const paths=Object.keys(d.documents).sort();for(let i=0;i<paths.length;i+=100){const part=paths.slice(i,i+100),snapshots=await db.getAll(...part.map(p=>db.doc(p)));for(const[n,s]of snapshots.entries())if(s.exists){const p=part[n],actual=s.data()!;
   if(p==='module13Demo/current'){if(actual.seedId!==d.seedId||actual.projectId!==MODULE13_DEMO_PROJECT||actual.databaseId!==MODULE13_DEMO_DATABASE||actual.createdAtMillis!==d.clockMillis)throw fail('Demo access manifest collision.');continue;}
   if(p.startsWith('module13DemoOwnership/')){if(digestOf(actual)!==digestOf(d.documents[p]))throw fail('Demo ownership registry collision.');continue;}
   const proof=await db.doc(owner(p)).get();if(!proof.exists||proof.data()?.seedId!==d.seedId||proof.data()?.path!==p)throw fail('A non-demo record occupies an intended seed path.');
   if(!d.manifest.mutablePaths.includes(p)&&digestOf(actual)!==digestOf(d.documents[p]))throw fail('An existing immutable demo record differs; no overwrite is permitted.');
  }}
 for(const spec of d.authUsers){const u=await getUser(clients.auth,spec.uid),o=await db.doc(authOwner(spec.uid)).get();if(u){if(!o.exists||o.data()?.seedId!==d.seedId||o.data()?.uid!==spec.uid||o.data()?.creationTime!==u.metadata.creationTime||!authMatches(u,spec))throw fail('A designated Auth identity is not proven seed-owned or has changed.');}else if(o.exists)throw fail('Seed-owned Auth identity is missing; no automatic replacement.');
  try{const byEmail=await clients.auth.getUserByEmail(spec.email);if(byEmail.uid!==spec.uid)throw fail('A fictional email is already owned by another account.');}catch(e){if(!isNotFound(e))throw e;}
 }
}
async function writeOwned(clients:DemoSeedClients,d:Module13DemoDataset,entries:[string,DocumentData][]){
 const db=clients.firestore;for(let offset=0;offset<entries.length;offset+=50){const selected=entries.slice(offset,offset+50);await db.runTransaction(async tx=>{
   const reads=await tx.getAll(...selected.flatMap(([p])=>[db.doc(p),db.doc(owner(p))]));
   for(const[i,[p,value]]of selected.entries()){const old=reads[2*i],proof=reads[2*i+1];if(old.exists){if(!proof.exists||proof.data()?.seedId!==d.seedId||proof.data()?.path!==p)throw fail('Record ownership changed during seed.');if(!d.manifest.mutablePaths.includes(p)&&digestOf(old.data())!==digestOf(value))throw fail('Record changed during seed.');}
   }
   for(const[i,[p,value]]of selected.entries()){if(!reads[2*i].exists)tx.create(db.doc(p),value);if(!reads[2*i+1].exists)tx.create(db.doc(owner(p)),{schemaVersion:1,seedId:d.seedId,path:p});}
  });}
}

export async function applyModule13DemoSeed(options:DemoSeedOptions){
 guardModule13DemoSeed(options);validateModule13DemoDataset(options.dataset);const clients=options,d=structuredClone(options.dataset),identity=planIdentity(d),db=clients.firestore;
 if(d.manifest.projectId!==MODULE13_DEMO_PROJECT||d.storageBucket!==clients.bucket?.name)throw fail('Seed plan project or bucket does not match effective clients.');
 await preflight(clients,d,identity);const priorRun=await db.doc(runPath(d)).get();if(!priorRun.exists)await db.doc(runPath(d)).create({schemaVersion:1,seedId:d.seedId,planIdentity:identity,status:'preparing',createdAtMillis:Date.now(),intendedAuthUids:d.authUsers.map(u=>u.uid),intendedDocumentPaths:Object.keys(d.documents).sort(),intendedStorageObjects:d.storageAssets.map(a=>({bucket:d.storageBucket,path:a.path,sha256:a.sha256}))});
 const priorManifest=await db.doc('module13Demo/current').get();if(!priorManifest.exists)await db.doc('module13Demo/current').create({...d.manifest,enabled:false});
 let createdAuth=0;for(const spec of d.authUsers){guardModule13DemoSeed(clients);const old=await getUser(clients.auth,spec.uid);if(!old){const user=await clients.auth.createUser(spec);await db.doc(authOwner(spec.uid)).create({schemaVersion:1,seedId:d.seedId,uid:spec.uid,email:spec.email,creationTime:user.metadata.creationTime});createdAuth++;}}
 for(const a of d.storageAssets){const meta=await storageMetadata(clients,d,a,true);if(!meta)throw fail('Credential upload was not confirmed.');bindAsset(d,a,meta);}refreshManifest(d);
 const base=Object.entries(d.documents).filter(([p])=>p!=='module13Demo/current'&&!p.startsWith('module13DemoOwnership/')&&!isConsent(p));await writeOwned(clients,d,base);
 const store=new FirestoreStore(db);for(const c of d.consentCommands){guardModule13DemoSeed(clients);const authUser=await clients.auth.getUser(c.uid);await createRecommendationConsentV2Command({store,clock:()=>c.nowMillis,noticePolicies:d.noticePolicies,readAuthIdentity:async uid=>{const u=await clients.auth.getUser(uid);return{uid:u.uid,email:u.email!,emailVerified:u.emailVerified,disabled:u.disabled,tokensValidAfterMillis:u.tokensValidAfterTime?Date.parse(u.tokensValidAfterTime):0};}})({app:{appId:'explicit-server-owned-demo-seed-command'},auth:{uid:c.uid,token:{email_verified:authUser.emailVerified,email:authUser.email,auth_time:Math.floor(Date.now()/1000)}},data:c.data});}
 // The command above owns consent transitions/receipts; establish separate immutable seed ownership.
 for(const p of Object.keys(d.documents).filter(isConsent)){const existing=await db.doc(p).get();if(!existing.exists)throw fail('A consent command did not persist its expected record.');const o=db.doc(owner(p)),proof=await o.get();if(!proof.exists)await o.create({schemaVersion:1,seedId:d.seedId,path:p});else if(proof.data()?.seedId!==d.seedId)throw fail('Consent record ownership changed.');}
 const manifestOwner=db.doc(owner('module13Demo/current'));if(!(await manifestOwner.get()).exists)await manifestOwner.create({schemaVersion:1,seedId:d.seedId,path:'module13Demo/current'});
 await db.doc('module13Demo/current').set({...d.manifest,enabled:false});
 const validation=await validateModule13DemoSeed({...clients,dataset:d},true);
 await db.doc('module13Demo/current').set(d.manifest);await db.doc(runPath(d)).update({status:'complete',completedAtMillis:Date.now(),createdAuthUids:d.authUsers.map(u=>u.uid),createdFirestorePaths:describeModule13DemoSeed(d).firestoreDocumentPaths,createdStorageObjects:d.storageAssets.map(a=>({bucket:d.storageBucket,path:a.path,sha256:a.sha256,generation:(d.documents[`module13DemoStorageOwnership/${digestOf(a.path)}`]).generation}))});
 return{schemaVersion:1,mode:'firebase_emulator_only',createdAuthThisRun:createdAuth,dataset:d,validation,manifest:describeModule13DemoSeed(d)};
}

export async function validateModule13DemoSeed(options:DemoSeedOptions,allowInactive=false){
 guardModule13DemoSeed(options);const{firestore:db,auth}=options,d=structuredClone(options.dataset),manifest=(await db.doc('module13Demo/current').get()).data();if(!manifest||manifest.seedId!==d.seedId||manifest.projectId!==MODULE13_DEMO_PROJECT||manifest.databaseId!==MODULE13_DEMO_DATABASE||!allowInactive&&manifest.enabled!==true)throw fail('Current demo seed manifest is not available.');
 const actualDocs:Record<string,DocumentData>={};for(const p of Object.keys(d.documents)){const s=await db.doc(p).get();if(!s.exists)throw fail('A manifest source record is missing.');actualDocs[p]=s.data()!;if(p!=='module13Demo/current'&&!p.startsWith('module13DemoOwnership/')&&!d.manifest.mutablePaths.includes(p)&&digestOf(actualDocs[p])!==(manifest.recordDigests as Record<string,string>)[p])throw fail('An immutable source record no longer matches the current seed manifest.');}
 for(const spec of d.authUsers){const u=await getUser(auth,spec.uid),o=(await db.doc(authOwner(spec.uid)).get()).data();if(!u||!o||o.seedId!==d.seedId||o.creationTime!==u.metadata.creationTime||!authMatches(u,spec))throw fail('A demo Auth account failed integrity validation.');}
 for(const m of d.memberScenarios){const c=actualDocs[`${MODULE13_DEMO_ROOT}/recommendationConsent/${m.memberId}`];if(c)parseRecommendationConsentV2(c,{organizationId:'gainpath',memberId:m.memberId},d.clockMillis);}
 let storageBytes=0;for(const a of d.storageAssets){const metadata=await storageMetadata(options,d,a,false);if(!metadata||record(actualDocs[a.credentialPath].upload).generation!==metadata.generation)throw fail('Credential Storage generation and approval record disagree.');storageBytes+=metadata.size;}
 const store=new FirestoreStore(db),first=d.memberScenarios[0],trainers=await evaluateTrainerCandidates({schemaVersion:1,organizationId:'gainpath',memberId:first.memberId,exerciseId:first.exerciseId,learningObjective:first.objective,level:first.level,localDate:d.bookingDate,durationMinutes:60},{repository:{transact:work=>store.transact(work),listCoachIds:async()=>d.coachIds},trustedExpertise:d.expertise,clock:()=>d.clockMillis,readIdentity:async uid=>{const u=await getUser(auth,uid);return{exists:!!u,disabled:u?.disabled??true,emailVerified:u?.emailVerified??false};}});
 if(trainers.candidates.length<3)throw fail('The demo does not contain three genuinely bookable Squat Coaches.');
 const contents=evaluateContentCandidates({organizationId:'gainpath',exerciseId:first.exerciseId,objective:first.objective,level:first.level},{...d.contentSource,catalog:d.contentSource.catalog.map(r=>({id:r.id,data:actualDocs[`${MODULE13_DEMO_ROOT}/exerciseVideos/${r.id}`]})),publications:d.publicationIds.map(id=>({id,data:actualDocs[`${MODULE13_DEMO_ROOT}/content/${id}`]}))});
 if(contents.candidates.length<3)throw fail('The demo lacks multiple valid published instructional tutorials.');
 return{valid:true,environment:'auth_firestore_storage_emulator',authIdentities:27,coaches:8,members:18,eligibleSquatCoaches:trainers.candidates.map(c=>({id:c.coachId,availableOptions:c.availableOptions.length})),rejectedSquatCoaches:trainers.rejected,eligibleSquatTutorials:contents.candidates.map(c=>c.destination),sourceDocuments:Object.keys(actualDocs).length,workout:validateModule13DemoDataset(d),storageObjects:8,storageBytes,normalEmailVerificationJourneyTested:false};
}

/** Read-only cleanup plan. No broad delete or live cleanup operation is implemented. */
export async function cleanupModule13DemoSeedDryRun(options:DemoSeedOptions){
 guardModule13DemoSeed(options);const d=options.dataset,run=(await options.firestore.doc(runPath(d)).get()).data();if(!run||run.seedId!==d.seedId||run.planIdentity!==planIdentity(d))throw fail('Exact seed ownership is required for cleanup planning.');
 const confirmedPaths:string[]=[];for(const p of Object.keys(d.documents)){const existing=await options.firestore.doc(p).get();if(!existing.exists)continue;if(p.startsWith('module13DemoOwnership/')){if(existing.data()?.seedId!==d.seedId)throw fail('Cleanup ownership collision.');}else if(p==='module13Demo/current'){if(existing.data()?.seedId!==d.seedId)throw fail('Cleanup manifest collision.');}else{const o=(await options.firestore.doc(owner(p)).get()).data();if(o?.seedId!==d.seedId||o.path!==p)throw fail('Cleanup cannot prove record ownership.');}confirmedPaths.push(p);}
 const authUids:string[]=[];for(const spec of d.authUsers){const u=await getUser(options.auth,spec.uid),o=(await options.firestore.doc(authOwner(spec.uid)).get()).data();if(u){if(o?.seedId!==d.seedId||o.creationTime!==u.metadata.creationTime)throw fail('Cleanup cannot prove Auth ownership.');authUids.push(u.uid);}}
 const objects=[];for(const a of d.storageAssets){const m=await storageMetadata(options,d,a,false);if(m)objects.push({bucket:d.storageBucket,path:a.path,generation:m.generation});}
 // Runtime transactions register their exact paths atomically. Inventory only
 // this seed's sidecars, with a hard bound; never discover via broad data scans.
 const runtimeOwners=await options.firestore.collection('module13DemoOwnership').where('seedId','==',d.seedId).limit(2001).get();
 if(runtimeOwners.size>2000)throw fail('Cleanup ownership inventory exceeds its reviewed bound.');
 for(const snapshot of runtimeOwners.docs){const o=snapshot.data(),p=o.path;if(o.schemaVersion!==1||typeof p!=='string'||snapshot.id!==digestOf(p)||p.split('/').length%2!==0||(!p.startsWith('orgs/gainpath/')&&!['orgs/gainpath','module13Demo/current','module13DemoSource/current'].includes(p)&&!p.startsWith('users/')&&!p.startsWith('module13DemoNegative')&&!p.startsWith('module13DemoStorageOwnership/')))throw fail('Invalid cleanup ownership path.');const existing=await options.firestore.doc(p).get();if(existing.exists){confirmedPaths.push(p,snapshot.ref.path);}}
 return{schemaVersion:1,dryRun:true,seedId:d.seedId,projectId:MODULE13_DEMO_PROJECT,databaseId:MODULE13_DEMO_DATABASE,firestorePaths:[...new Set([...confirmedPaths,...authUids.map(authOwner),runPath(d)])].sort(),authUids,storageObjects:objects,willDelete:false,reason:'Exact source and runtime ownership inventory only. Review generations, Auth creation times and revisions again before any separately authorized cleanup.'};
}
