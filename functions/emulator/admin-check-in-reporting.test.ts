import {initializeApp, deleteApp, type App} from 'firebase-admin/app';
import {getFirestore, FieldPath, type Firestore} from 'firebase-admin/firestore';
import {beforeAll, afterAll, beforeEach, it, expect} from 'vitest';
import {FirestoreStore} from '../src/platform/firestore/firestore-store';
import {appCheckInCommand} from '../src/modules/gamification/app-check-in-service';
import {adminCheckInReport, type CheckInReportReader} from '../src/modules/analytics/admin-check-in-reporting';
let app: App, db: Firestore;
const project = 'demo-gainpath-check-in-reporting', now = Date.UTC(2026, 9, 26, 6), actor = {uid: 'admin', token: {email_verified: true, auth_time: 100}};
const query = {schemaVersion: 1, organizationId: 'gainpath', startAtMillis: Date.UTC(2026, 9, 24, 16), endAtMillis: Date.UTC(2026, 9, 26, 16)};
beforeAll(() => {if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:18088') throw Error('Dedicated loopback emulator required'); app = initializeApp({projectId: project}, 'check-in-reporting'); db = getFirestore(app);});
afterAll(async () => {await db?.terminate(); if (app) await deleteApp(app);});
beforeEach(async () => {
  await fetch(`http://127.0.0.1:18088/emulator/v1/projects/${project}/databases/(default)/documents`, {method: 'DELETE'});
  const batch = db.batch(); batch.set(db.doc('users/admin'), {organizationId: 'gainpath'}); batch.set(db.doc('orgs/gainpath'), {status: 'active'});
  batch.set(db.doc('orgs/gainpath/members/admin'), {organizationId: 'gainpath', role: 'admin', status: 'active', branchIds: []});
  batch.set(db.doc('orgs/gainpath/members/member'), {organizationId: 'gainpath', role: 'member', status: 'active', branchIds: []});
  batch.set(db.doc('users/member'), {organizationId: 'gainpath', role: 'member'}); await batch.commit();
});
const page = async (path: string, after: string | undefined, limit: number) => {
  let q = db.collection(path).orderBy(FieldPath.documentId()).limit(limit); if (after) q = q.startAfter(after);
  return (await q.get()).docs.map(d => ({id: d.id, data: d.data()}));
};
const reader: CheckInReportReader = {members: (after, limit) => page('orgs/gainpath/members', after, limit), claims: (uid, after, limit) => page(`orgs/gainpath/appCheckInProfiles/${uid}/claims`, after, limit)};
const claim = (at: number) => appCheckInCommand(new FirestoreStore(db), {uid: 'member', token: actor.token}, {schemaVersion: 1, organizationId: 'gainpath', action: 'claim'}, () => at);
it('uses actual immutable receipts and profiles without touching wallet balances or source versions', async () => {
  await claim(Date.UTC(2026, 9, 25, 6)); await claim(Date.UTC(2026, 9, 26, 5));
  const ref = db.doc('orgs/gainpath/rewardBalances/member'), before = await ref.get();
  const r = await adminCheckInReport(new FirestoreStore(db), actor, query, reader, () => now);
  expect(r.totals).toEqual({claims: 2, claimingMembers: 1, pointsAwarded: 100}); expect(r.streaks.current.oneTwo).toBe(1);
  expect((await ref.get()).updateTime?.isEqual(before.updateTime!)).toBe(true); expect((await db.collection('orgs/gainpath/analytics').get()).empty).toBe(true);
});
it('reads complete real document-id pages and reconciles more than 100 claim days', async () => {
  // Produce the complete immutable schema via the existing earning service.
  const first = Date.UTC(2026, 6, 1, 5);
  for (let i = 0; i < 102; i++) await claim(first + i * 86400000);
  const r = await adminCheckInReport(new FirestoreStore(db), actor, {...query, startAtMillis: 0}, reader, () => now);
  expect(r.coverage.claimsScanned).toBe(102); expect(r.totals.pointsAwarded).toBe(5100); expect(r.streaks.longest.sevenPlus).toBe(1);
});
it('a valid concurrent claim fails closed instead of mixing profile and receipt revisions', async () => {
  await claim(Date.UTC(2026, 9, 25, 6));
  await expect(adminCheckInReport(new FirestoreStore(db), actor, query, {...reader, claims: async (uid, after, limit) => {
    const rows = await reader.claims(uid, after, limit); await claim(Date.UTC(2026, 9, 26, 5)); return rows;
  }}, () => now)).rejects.toMatchObject({code: 'failed-precondition'});
});
it('schema two aggregates real redemption and game documents while leaving wallets and receipts unchanged',async()=>{
 const redemption=db.doc(`orgs/gainpath/rewardRedemptions/${'b'.repeat(64)}`),roundId='a'.repeat(32),round=db.doc(`orgs/gainpath/miniGameRoundSessions/${roundId}`);
 await redemption.set({schemaVersion:1,organizationId:'gainpath',redemptionId:redemption.id,memberId:'previous-member',itemId:'shirt',title:'Gym shirt',points:100,status:'fulfilled',issuedAtMillis:query.startAtMillis-1000,fulfilledAtMillis:query.startAtMillis,fulfilledBy:'admin',policyVersion:'points-only-v1',exchangeRateVersion:'points-only-v1'});
 await round.set({schemaVersion:1,organizationId:'gainpath',memberId:'previous-member',attemptId:roundId,gameId:'reach-tap-v1',status:'awaiting_verification',startedAtMillis:query.startAtMillis,lastAtMillis:query.startAtMillis+40000,activeMillis:40000,expiresAtMillis:query.startAtMillis+900000,sequence:10,physicalVerified:false,pointsAwarded:0});
 const before=await redemption.get(),r=await adminCheckInReport(new FirestoreStore(db),actor,{...query,schemaVersion:2},{...reader,page:(kind,after,limit)=>page(`orgs/gainpath/${kind}`,after,limit)},()=>now);
 const extension=(r as unknown as {extensions:{redemptions:{issued:number;collected:number};games:{gameId:string;completed:number;pointsAwarded:number}[]}}).extensions;
 expect(extension.redemptions).toMatchObject({issued:0,collected:1});expect(extension.games.find(g=>g.gameId==='reach-tap-v1')).toMatchObject({completed:1,pointsAwarded:0});expect((await redemption.get()).updateTime?.isEqual(before.updateTime!)).toBe(true);expect((await db.collection('orgs/gainpath/rewardBalances').get()).empty).toBe(true);expect(JSON.stringify(r)).not.toContain('previous-member');
});
it('schema two rejects a foreign source and authority drift during actual extended reads',async()=>{
 await db.doc('orgs/gainpath/rewardRedemptions/bad').set({schemaVersion:1,organizationId:'other'});
 await expect(adminCheckInReport(new FirestoreStore(db),actor,{...query,schemaVersion:2},{...reader,page:(kind,after,limit)=>page(`orgs/gainpath/${kind}`,after,limit)},()=>now)).rejects.toMatchObject({code:'failed-precondition'});
 await db.doc('orgs/gainpath/rewardRedemptions/bad').delete();
 await expect(adminCheckInReport(new FirestoreStore(db),actor,{...query,schemaVersion:2},{...reader,page:async(kind,after,limit)=>{const rows=await page(`orgs/gainpath/${kind}`,after,limit);if(kind==='miniGameParticipationAwards')await db.doc('users/admin').update({organizationId:'other'});return rows;}},()=>now)).rejects.toMatchObject({code:'permission-denied'});
});
it('schema three reports real observable events, distinct Members and historical recency without writes',async()=>{
 await claim(Date.UTC(2026,9,25,6));
 const ref=db.doc('orgs/gainpath/bookings/observed');await ref.set({schemaVersion:1,organizationId:'gainpath',memberId:'member',createdAtMillis:query.startAtMillis,status:'confirmed'});const before=await ref.get();
 const r=await adminCheckInReport(new FirestoreStore(db),actor,{...query,schemaVersion:3},{...reader,page:(kind,a,l)=>page(`orgs/gainpath/${kind}`,a,l),observations:{page:(kind,a,l)=>page(`orgs/gainpath/${kind}`,a,l),backups:(uid,a,l)=>page(`orgs/gainpath/members/${uid}/workoutBackups`,a,l)}},()=>now);
 const observations=(r as unknown as {observations:{sourceCounts:{checkIns:number;bookings:number};cohortMembers:number;daily:{uniqueMembers:number}[]}}).observations;
 expect(observations.sourceCounts).toMatchObject({checkIns:1,bookings:1});expect(observations.cohortMembers).toBe(1);expect(observations.daily[0].uniqueMembers).toBe(1);expect(JSON.stringify(observations)).not.toContain('memberId');expect((await ref.get()).updateTime?.isEqual(before.updateTime!)).toBe(true);
});
