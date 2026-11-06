import {it,expect} from 'vitest';
import {initializeApp,deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {getAuth} from 'firebase-admin/auth';
import {buildModule13DemoDataset} from '../src/modules/recommendation/demo-dataset';
import {guardModule13DemoSeed,describeModule13DemoSeed} from '../src/modules/recommendation/demo-seed';
it('provides bounded exact source-only resource counts without bootstrapping live resources',async()=>{
 const d=await buildModule13DemoDataset({nowMillis:Date.parse('2026-11-03T00:00:00Z')});const p=describeModule13DemoSeed(d);expect(p.authAccounts).toBe(27);expect(p.coaches).toBe(8);expect(p.members).toBe(18);expect(p.storageObjects).toBe(8);expect(p.liveApplyEnabled).toBe(false);expect(p.firestoreDocumentPaths.length).toBeGreaterThan(500);
});
it('refuses foreign projects and nonmatching effective SDK transport before writes',async()=>{
 const app=initializeApp({projectId:'foreign-project'},'demo-seed-guard-test');try{const db=getFirestore(app,'module13-demo');expect(()=>guardModule13DemoSeed({firestore:db,auth:getAuth(app)})).toThrow();await db.terminate();}finally{await deleteApp(app);}
});
