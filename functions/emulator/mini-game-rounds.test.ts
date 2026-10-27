import {initializeApp,deleteApp,type App} from 'firebase-admin/app';
import {getFirestore,type Firestore} from 'firebase-admin/firestore';
import {beforeAll,beforeEach,afterAll,it,expect} from 'vitest';
import {initializeTestEnvironment,assertFails} from '@firebase/rules-unit-testing';
import {doc,getDoc,setDoc} from 'firebase/firestore';
import {readFileSync} from 'node:fs';
import {FirestoreStore} from '../src/platform/firestore/firestore-store';
import {miniGameRounds} from '../src/modules/gamification/mini-game-rounds';
import {seed,org,auth,now} from '../test/reward-journey-fixture';
let app:App,db:Firestore,store:FirestoreStore,at:number,ids:number;
const project='demo-gainpath-mini-game-rounds';
beforeAll(()=>{if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:18092')throw Error('Isolated emulator required');app=initializeApp({projectId:project},'mini-game-rounds');db=getFirestore(app);store=new FirestoreStore(db);});
beforeEach(async()=>{await fetch(`http://127.0.0.1:18092/emulator/v1/projects/${project}/databases/(default)/documents`,{method:'DELETE'});const batch=db.batch();for(const[p,v]of seed().documents)batch.set(db.doc(p),v);await batch.commit();at=now;ids=0;});
afterAll(async()=>{await db?.terminate();if(app)await deleteApp(app);});
const call=(action:string,fields:Record<string,unknown>)=>miniGameRounds(store,auth,{schemaVersion:1,organizationId:org,action,...fields},{freshAuth:async()=>{},clock:()=>at,randomId:()=> (++ids).toString(16).padStart(32,'0')});
it('real transactions enforce one active Member round across concurrent device starts',async()=>{
 const results=await Promise.allSettled(['a','b'].map(v=>call('begin',{requestId:v.repeat(32),gameId:'move-catch-v1'})));
 expect(results.filter(r=>r.status==='fulfilled')).toHaveLength(1);
 expect((results.find(r=>r.status==='rejected') as PromiseRejectedResult).reason.code).toBe('resource-exhausted');
 expect((await db.collection(`orgs/${org}/miniGameRoundSessions`).get()).size).toBe(1);
});
it('real concurrent checkpoints and finish retries create one pending receipt and never reward evidence',async()=>{
 const r=await call('begin',{requestId:'a'.repeat(32),gameId:'move-catch-v1'}),bound={attemptId:r.attemptId,challengeToken:r.challengeToken};
 async function duplicates(action:string,fields:Record<string,unknown>){
  // Fully settle concurrent requests before making assertions or clearing data.
  // Exercise duplicate first/final checkpoints rather than hammering every
  // checkpoint with artificial contention unlike the serialized mobile client.
  const results=await Promise.allSettled([call(action,fields),call(action,fields)]);
  for(const result of results)if(result.status==='rejected')throw result.reason;
  const values=results.map(r=>(r as PromiseFulfilledResult<Awaited<ReturnType<typeof call>>>).value);
  expect(values[0]).toEqual(values[1]);return values[0];
 }
 for(let sequence=1;sequence<=20;sequence++){at+=2000;const fields={...bound,sequence,activeMillis:sequence*2000,phase:'active'};
  if(sequence===1||sequence===20)await duplicates('checkpoint',fields);else await call('checkpoint',fields);}
 const a=await duplicates('finish',{...bound,sequence:21});expect(a.status).toBe('awaiting_verification');
 expect((await db.doc(`orgs/${org}/rewardBalances/member`).get()).data()?.points).toBe(1000);
 for(const collection of ['miniGameVerifiedRounds','rewardAwards','miniGameRewardDailyClaims'])expect((await db.collection(`orgs/${org}/${collection}`).get()).empty).toBe(true);
});
it('existing Rules deny client reads/writes of timing leases, sessions and immutable command receipts',async()=>{
 const env=await initializeTestEnvironment({projectId:project,firestore:{host:'127.0.0.1',port:18092,rules:readFileSync('../firebase/firestore.rules','utf8')}});
 try{for(const uid of ['member','admin']){const client=env.authenticatedContext(uid,{email_verified:true}).firestore();
  for(const suffix of ['miniGameRoundSessions/forged','miniGameRoundSessions/forged/commands/1','miniGameRoundRequests/forged','miniGameRoundLeases/forged']){
   const ref=doc(client,`orgs/${org}/${suffix}`);await assertFails(getDoc(ref));await assertFails(setDoc(ref,{schemaVersion:1,memberId:uid,status:'verified'}));
  }
 }}finally{await env.cleanup();}
});
