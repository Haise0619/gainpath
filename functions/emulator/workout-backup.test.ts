import { readFileSync } from 'node:fs';
import { initializeApp,deleteApp,type App } from 'firebase-admin/app';
import { getFirestore,FieldPath,type Firestore } from 'firebase-admin/firestore';
import { initializeTestEnvironment,assertFails,type RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { doc,getDoc,setDoc } from 'firebase/firestore';
import { beforeAll,afterAll,beforeEach,it,expect } from 'vitest';
import { FirestoreStore } from '../src/platform/firestore/firestore-store';
import { backupWorkout,listWorkoutBackups,type BackupStore } from '../src/modules/workouts/workout-backup';
import { actor,command,payload } from '../test/workout-backup-fixture';
let app:App,db:Firestore,env:RulesTestEnvironment,store:BackupStore;
beforeAll(async()=>{
 if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:18086')throw Error('Dedicated loopback backup emulator required; never target production.');
 app=initializeApp({projectId:'demo-gainpath-backup'},'backup-emulator');db=getFirestore(app);
 env=await initializeTestEnvironment({projectId:'demo-gainpath-backup',firestore:{host:'127.0.0.1',port:18086,rules:readFileSync('../firebase/firestore.rules','utf8')}});
 const base=new FirestoreStore(db);store={transact:work=>base.transact(work),list:async(prefix,after,limit,kind)=>{let q=db.collection(prefix).orderBy(FieldPath.documentId()).endAt(kind+'-\uf8ff').limit(limit);if(after)q=q.startAfter(after);else q=q.startAt(kind+'-');return(await q.get()).docs.map(d=>d.data());}};
});
afterAll(async()=>{await env?.cleanup();await db?.terminate();if(app)await deleteApp(app);});
beforeEach(async()=>{await env.clearFirestore();const batch=db.batch();batch.set(db.doc('users/member'),{organizationId:'gainpath'});batch.set(db.doc('orgs/gainpath'),{status:'active'});batch.set(db.doc('orgs/gainpath/members/member'),{organizationId:'gainpath',role:'member',status:'active',branchIds:[]});await batch.commit();});
it('concurrent retries store one head and one immutable revision without acceptance',async()=>{
 const results=await Promise.all([backupWorkout(store,actor,command),backupWorkout(store,actor,command),backupWorkout(store,actor,command)]);expect(results[0]).toEqual(results[1]);const path='orgs/gainpath/members/member/workoutBackups';expect((await db.collection(path).get()).size).toBe(1);expect((await db.collection(path+'/session-s1/revisions').get()).size).toBe(1);expect((await db.collection('orgs/gainpath/workoutSessions').get()).empty).toBe(true);
});
it('competing payloads cannot silently replace a saved session',async()=>{const results=await Promise.allSettled([backupWorkout(store,actor,command),backupWorkout(store,actor,{...command,payload:{...payload,repetitions:3}})]);expect(results.filter(r=>r.status==='fulfilled')).toHaveLength(1);expect(results.filter(r=>r.status==='rejected')).toHaveLength(1);});
it('pagination restores all records with stable IDs and excludes other owners',async()=>{for(let i=0;i<5;i++)await backupWorkout(store,actor,{...command,id:'s'+i,payload:{...payload,sessionId:'s'+i}});const first=await listWorkoutBackups(store,actor,{schemaVersion:1,organizationId:'gainpath',memberId:'member',consented:true,after:null});expect(first.records).toHaveLength(3);const last=await listWorkoutBackups(store,actor,{schemaVersion:1,organizationId:'gainpath',memberId:'member',consented:true,after:first.nextCursor});expect(last.records).toHaveLength(2);expect(new Set([...first.records,...last.records].map(r=>r.id)).size).toBe(5);await expect(listWorkoutBackups(store,{uid:'other',token:actor.token},{schemaVersion:1,organizationId:'gainpath',memberId:'member',consented:true,after:null})).rejects.toMatchObject({code:'permission-denied'});});
it('unchanged Rules deny direct client backup reads and writes including the owner',async()=>{await backupWorkout(store,actor,command);for(const uid of ['member','other']){const client=env.authenticatedContext(uid,{email_verified:true}).firestore(),path='orgs/gainpath/members/member/workoutBackups/session-s1';await assertFails(getDoc(doc(client,path)));await assertFails(setDoc(doc(client,path),{injected:true}));}});
it('pages sessions before routines without a composite index or descending scan',async()=>{const {routinePayload}=await import('../test/workout-backup-fixture');await backupWorkout(store,actor,{...command,kind:'routine',id:'r1',payload:routinePayload});const empty=await listWorkoutBackups(store,actor,{schemaVersion:1,organizationId:'gainpath',memberId:'member',consented:true,after:null});expect(empty.records).toHaveLength(0);expect(empty.nextCursor).toBe('routines');const routines=await listWorkoutBackups(store,actor,{schemaVersion:1,organizationId:'gainpath',memberId:'member',consented:true,after:empty.nextCursor});expect(routines.records[0].kind).toBe('routine');expect(routines.nextCursor).toBeNull();});
