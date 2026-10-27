import {initializeApp,deleteApp,type App} from 'firebase-admin/app';
import {getFirestore,type Firestore} from 'firebase-admin/firestore';
import {beforeAll,beforeEach,afterAll,it,expect} from 'vitest';
import {initializeTestEnvironment,assertFails} from '@firebase/rules-unit-testing';
import {doc,getDoc,setDoc} from 'firebase/firestore';
import {readFileSync} from 'node:fs';
import {FirestoreStore} from '../src/platform/firestore/firestore-store';
import {miniGameRounds} from '../src/modules/gamification/mini-game-rounds';
import {miniGameParticipation} from '../src/modules/gamification/mini-game-participation';
import {seed,org,auth,now} from '../test/reward-journey-fixture';
let app:App,db:Firestore,store:FirestoreStore,at:number,ids:number;
const project='demo-gainpath-mini-game-participation';
beforeAll(()=>{if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:18096')throw Error('Isolated local emulator required');app=initializeApp({projectId:project},'participation');db=getFirestore(app);store=new FirestoreStore(db);});
beforeEach(async()=>{await fetch(`http://127.0.0.1:18096/emulator/v1/projects/${project}/databases/(default)/documents`,{method:'DELETE'});const batch=db.batch();for(const[p,v]of seed().documents)batch.set(db.doc(p),v);await batch.commit();at=now;ids=0;});
afterAll(async()=>{await db?.terminate();if(app)await deleteApp(app);});
const round=(action:string,fields:Record<string,unknown>)=>miniGameRounds(store,auth,{schemaVersion:1,organizationId:org,action,...fields},
 {clock:()=>at,freshAuth:async()=>{},randomId:()=> (++ids).toString(16).padStart(32,'0')});
const claim=(attemptId:string,enabled=true)=>miniGameParticipation(store,auth,{schemaVersion:2,organizationId:org,action:'claimParticipation',attemptId},{clock:()=>at,freshAuth:async()=>{},releaseApproved:enabled});
it('full server-issued round to spendable credit is retry-safe',async()=>{
 const r=await round('begin',{requestId:'a'.repeat(32),gameId:'move-catch-v1'}),bound={attemptId:r.attemptId,challengeToken:r.challengeToken};
 for(let sequence=1;sequence<=20;sequence++){at+=2000;await round('checkpoint',{...bound,sequence,activeMillis:sequence*2000,phase:'active'});}
 await round('finish',{...bound,sequence:21});
 expect((await claim(r.attemptId,false)).result.status).toBe('not-active');
 const results=await Promise.allSettled([claim(r.attemptId),claim(r.attemptId)]);for(const result of results)if(result.status==='rejected')throw result.reason;
 const[a,b]=results.map(v=>(v as PromiseFulfilledResult<Record<string,any>>).value);expect(a.award).toEqual(b.award);
 expect((await db.doc(`orgs/${org}/miniGameParticipationBalances/member`).get()).exists).toBe(false);
 expect((await db.doc(`orgs/${org}/rewardBalances/member`).get()).data()?.points).toBe(1020);
 for(const collection of ['rewardAwards','rewardRedemptions','miniGameVerifiedRounds'])expect((await db.collection(`orgs/${org}/${collection}`).get()).empty).toBe(true);
});
it('simultaneous completed sessions on different devices cannot bypass per-game allowance',async()=>{
 const attempts=['a'.repeat(32),'b'.repeat(32)];const batch=db.batch();
 for(const attemptId of attempts)batch.set(db.doc(`orgs/${org}/miniGameRoundSessions/${attemptId}`),{schemaVersion:1,organizationId:org,memberId:'member',gameId:'move-catch-v1',attemptId,
 status:'awaiting_verification',activeMillis:40000,sequence:21,startedAtMillis:at-45000,lastAtMillis:at-1000,expiresAtMillis:at-45000+900000,physicalVerified:false,pointsAwarded:0});await batch.commit();
 const settled=await Promise.allSettled(attempts.map(id=>claim(id)));for(const r of settled)if(r.status==='rejected')throw r.reason;
 expect(settled.map(v=>(v as PromiseFulfilledResult<Record<string,any>>).value.result.status).sort()).toEqual(['awarded','game-limit']);
 expect((await db.collection(`orgs/${org}/miniGameParticipationAwards`).get()).size).toBe(1);
});
it('existing Rules prohibit client creation or alteration of demo balances awards and shared caps',async()=>{
 const env=await initializeTestEnvironment({projectId:project,firestore:{host:'127.0.0.1',port:18096,rules:readFileSync('../firebase/firestore.rules','utf8')}});
 try{for(const uid of ['member','admin']){const client=env.authenticatedContext(uid,{email_verified:true}).firestore();
  for(const collection of ['miniGameParticipationBalances','miniGameParticipationAwards','miniGameParticipationDailyClaims']){
   const ref=doc(client,`orgs/${org}/${collection}/forged`);await assertFails(getDoc(ref));await assertFails(setDoc(ref,{schemaVersion:1,memberId:uid,demoPoints:999,redeemable:true}));
  }
 }}finally{await env.cleanup();}
});
