import {initializeApp,deleteApp,type App} from 'firebase-admin/app';
import {getFirestore,type Firestore} from 'firebase-admin/firestore';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment,assertFails,type RulesTestEnvironment} from '@firebase/rules-unit-testing';
import {doc,getDoc,setDoc} from 'firebase/firestore';
import {beforeAll,afterAll,beforeEach,it,expect} from 'vitest';
import {FirestoreStore} from '../src/platform/firestore/firestore-store';
import {appCheckInCommand} from '../src/modules/gamification/app-check-in-service';
import {memberAchievements} from '../src/modules/gamification/member-achievements';
import {firestoreAchievementsStore} from '../src/modules/gamification/firestore-achievements-store';
import {backupWorkout} from '../src/modules/workouts/workout-backup';
import {completedStandaloneBackup} from '../test/workout-backup-fixture';
let app:App,db:Firestore,env:RulesTestEnvironment;
const actor={uid:'member',token:{email_verified:true,auth_time:100}},command={schemaVersion:1,organizationId:'gainpath',action:'claim'},time=Date.UTC(2026,9,26,4);
beforeAll(async()=>{if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:18087')throw Error('Dedicated loopback check-in emulator required.');app=initializeApp({projectId:'demo-gainpath-checkin'},'check-in-tests');db=getFirestore(app);env=await initializeTestEnvironment({projectId:'demo-gainpath-checkin',firestore:{host:'127.0.0.1',port:18087,rules:readFileSync('../firebase/firestore.rules','utf8')}});});
afterAll(async()=>{await env?.cleanup();await db?.terminate();if(app)await deleteApp(app);});
beforeEach(async()=>{await env.clearFirestore();const batch=db.batch();batch.set(db.doc('users/member'),{organizationId:'gainpath'});batch.set(db.doc('orgs/gainpath'),{status:'active'});batch.set(db.doc('orgs/gainpath/members/member'),{organizationId:'gainpath',userId:'member',role:'member',status:'active',branchIds:[]});await batch.commit();});
it('real concurrent retries issue one receipt and one 50-point shared balance credit',async()=>{const store=new FirestoreStore(db);const rows=await Promise.all([appCheckInCommand(store,actor,command,()=>time),appCheckInCommand(store,actor,command,()=>time),appCheckInCommand(store,actor,command,()=>time)]);expect(rows.filter(r=>r.awarded)).toHaveLength(1);expect((await db.doc('orgs/gainpath/rewardBalances/member').get()).data()?.points).toBe(50);expect((await db.collection('orgs/gainpath/appCheckInProfiles/member/claims').get()).size).toBe(1);});
it('server-date boundary permits exactly one award on each Malaysia day',async()=>{const store=new FirestoreStore(db);await appCheckInCommand(store,actor,command,()=>Date.UTC(2026,9,25,15,59,59));const next=await appCheckInCommand(store,actor,command,()=>Date.UTC(2026,9,25,16));expect(next.snapshot.balance).toBe(100);expect(next.snapshot.currentStreak).toBe(2);expect(next.snapshot.today).toBe('2026-10-26');});
it('unauthorized account cannot claim or read another account state',async()=>{await expect(appCheckInCommand(new FirestoreStore(db),{uid:'other',token:actor.token},command,()=>time)).rejects.toMatchObject({code:'permission-denied'});expect((await db.collection('orgs/gainpath/rewardBalances').get()).empty).toBe(true);});
it('unchanged Rules reject direct profile/receipt/balance reads and writes',async()=>{await appCheckInCommand(new FirestoreStore(db),actor,command,()=>time);for(const uid of ['member','other']){const client=env.authenticatedContext(uid,{email_verified:true}).firestore();for(const path of ['orgs/gainpath/appCheckInProfiles/member','orgs/gainpath/appCheckInProfiles/member/claims/2026-10-26','orgs/gainpath/rewardBalances/member']){await assertFails(getDoc(doc(client,path)));await assertFails(setDoc(doc(client,path),{points:999999}));}}});

it('projects legacy claims and an owned idempotent workout backup without exposing progress writes', async () => {
  const store = firestoreAchievementsStore(db);
  const input = { ...command, action: 'achievements' };
  for (let day = 13; day <= 26; day++) {
    const result = await appCheckInCommand(store, actor, command, () => Date.UTC(2026, 9, day, 4));
    expect(result.snapshot.badges).toHaveLength(3);
  }
  const backupStore = { ...store, list: async () => [] };
  const workout = completedStandaloneBackup('s1', 2);
  await backupWorkout(backupStore, actor, workout);
  await backupWorkout(backupStore, actor, workout);
  const [a, b] = await Promise.all([
    memberAchievements(store, actor, input, () => time),
    memberAchievements(store, actor, input, () => time),
  ]);
  expect(a).toEqual(b);
  expect(a.badges).toHaveLength(8);
  expect(a.badges[3].unlockedAtMillis).toBe(time);
  expect(a.badges[5].progress).toBe(1);
  expect(a.badges[6].progress).toBe(2);
  expect((await db.doc('orgs/gainpath/rewardBalances/member').get()).data()?.points).toBe(700);
  const path = 'orgs/gainpath/members/member/achievementProgress/v1';
  for (const uid of ['member', 'other']) {
    const client = env.authenticatedContext(uid, { email_verified: true }).firestore();
    await assertFails(getDoc(doc(client, path)));
    await assertFails(setDoc(doc(client, path), { unlocked: {} }));
  }
});
