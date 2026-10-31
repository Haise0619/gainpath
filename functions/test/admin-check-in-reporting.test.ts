import {beforeEach, it, expect} from 'vitest';
import {MemoryStore} from './memory-store';
import {appCheckInCommand} from '../src/modules/gamification/app-check-in-service';
import {adminCheckInReport, type CheckInReportReader} from '../src/modules/analytics/admin-check-in-reporting';
const now = Date.UTC(2026, 9, 26, 6), from = Date.UTC(2026, 9, 23, 16), until = Date.UTC(2026, 9, 26, 16);
const actor = {uid: 'admin', token: {email_verified: true, auth_time: 100}}, query = {schemaVersion: 1, organizationId: 'gainpath', startAtMillis: from, endAtMillis: until};
let store: MemoryStore, scans: number;
const members = () => [...store.documents].filter(([p]) => /^orgs\/gainpath\/members\/[^/]+$/.test(p)).map(([p, data]) => ({id: p.split('/').at(-1)!, data})).sort((a, b) => a.id.localeCompare(b.id));
const reader: CheckInReportReader = {
  members: async (after, limit) => members().filter(r => !after || r.id > after).slice(0, limit),
  claims: async (uid, after, limit) => {scans++; const prefix = `orgs/gainpath/appCheckInProfiles/${uid}/claims/`;
    return [...store.documents].filter(([p]) => p.startsWith(prefix) && p.slice(prefix.length).indexOf('/') < 0).map(([p, data]) => ({id: p.slice(prefix.length), data})).sort((a, b) => a.id.localeCompare(b.id)).filter(r => !after || r.id > after).slice(0, limit);},
};
const addMember = (uid: string) => {store.documents.set('users/' + uid, {organizationId: 'gainpath', role: 'member'}); store.documents.set('orgs/gainpath/members/' + uid, {organizationId: 'gainpath', userId: uid, status: 'active', role: 'member', branchIds: []});};
const claim = (uid: string, day: number) => appCheckInCommand(store, {uid, token: actor.token}, {schemaVersion: 1, organizationId: 'gainpath', action: 'claim'}, () => Date.UTC(2026, 9, day, 5));
const run = (r = reader, q = query) => adminCheckInReport(store, actor, q, r, () => now);
beforeEach(() => {scans = 0; store = new MemoryStore(); store.documents.set('users/admin', {organizationId: 'gainpath'}); store.documents.set('orgs/gainpath', {status: 'active'}); store.documents.set('orgs/gainpath/members/admin', {organizationId: 'gainpath', role: 'admin', status: 'active', branchIds: []});});
it('uses immutable confirmed receipts for awarded points, returns aggregates only and never writes balances or claims', async () => {
  addMember('a'); await claim('a', 24); await claim('a', 25); await claim('a', 26);
  const before = JSON.stringify([...store.documents]), r = await run();
  expect(r.totals).toEqual({claims: 3, claimingMembers: 1, pointsAwarded: 150});
  expect(r.coverage).toMatchObject({activeMembers: 1, profiles: 1, claimsScanned: 3});
  expect(JSON.stringify([...store.documents])).toBe(before); expect(JSON.stringify(r)).not.toContain('memberId'); expect(JSON.stringify(r)).not.toContain('recentDays');
  expect(r.policyVersion).toBe('app-check-in-v1'); expect(r.pointsPerClaim).toBe(50);
});
it('weekly and selected-range distinct claimants do not sum repeated daily users', async () => {
  addMember('a'); addMember('b'); for (const day of [24, 25, 26]) await claim('a', day); await claim('b', 25);
  const r = await run(); expect(r.totals.claimingMembers).toBe(2); expect(r.daily.map(d => d.claimingMembers)).toEqual([1, 2, 1]);
  expect(r.weekly.map(w => [w.date, w.claims, w.claimingMembers])).toEqual([['2026-10-19', 3, 2], ['2026-10-26', 1, 1]]);
});
it('Malaysia dates and start-inclusive/end-exclusive filter apply to claim timestamps', async () => {
  addMember('a'); await claim('a', 24); await claim('a', 25);
  const r = await run(reader, {...query, startAtMillis: Date.UTC(2026, 9, 24, 5), endAtMillis: Date.UTC(2026, 9, 25, 5)});
  expect(r.totals.claims).toBe(1); expect(r.daily[0].date).toBe('2026-10-24');
});
it('streaks use all-time receipts as of today, keep grace day and distinguish longest from current', async () => {
  for (const uid of ['a', 'b', 'c']) addMember(uid);
  for (const day of [20, 21, 22, 23, 24, 25]) await claim('a', day);
  for (const day of [20, 21, 22]) await claim('b', day);
  const r = await run(reader, {...query, startAtMillis: Date.UTC(2026, 9, 25, 16)});
  expect(r.totals.claims).toBe(0); expect(r.streaks.asOfDate).toBe('2026-10-26');
  expect(r.streaks.current).toEqual({zero: 2, oneTwo: 0, threeSix: 1, sevenPlus: 0});
  expect(r.streaks.longest).toEqual({zero: 1, oneTwo: 0, threeSix: 2, sevenPlus: 0});
});
it('no-profile Members are genuine zero streaks; no Member cohort gives empty but valid aggregates', async () => {
  expect((await run()).totals.claims).toBe(0); addMember('a');
  const r = await run(); expect(r.coverage.profiles).toBe(0); expect(r.streaks.current.zero).toBe(1);
});
it('foreign/inactive/non-Member accounts do not enter the cohort or trigger claim reads', async () => {
  addMember('a'); store.documents.set('users/a', {organizationId: 'other'});
  expect((await run()).coverage.activeMembers).toBe(0); expect(scans).toBe(0);
});
it('non-Admin or changed canonical authority denies results', async () => {
  store.documents.set('users/admin', {organizationId: 'other'}); await expect(run()).rejects.toMatchObject({code: 'permission-denied'}); expect(scans).toBe(0);
  store.documents.set('users/admin', {organizationId: 'gainpath'}); addMember('a');
  await expect(run({...reader, claims: async () => {store.documents.set('users/admin', {organizationId: 'other'}); return [];}})).rejects.toMatchObject({code: 'permission-denied'});
});
it('wrong points, source, identity or missing ledger rows deny all totals', async () => {
  addMember('a'); await claim('a', 25); const key = 'orgs/gainpath/appCheckInProfiles/a/claims/2026-10-25', original = store.documents.get(key)!;
  for (const change of [{points: 500}, {source: 'gym_attendance'}, {memberId: 'other'}, {policyVersion: 'future'}, {date: '2026-10-24'}]) {
    store.documents.set(key, {...original, ...change}); await expect(run()).rejects.toMatchObject({code: 'failed-precondition'});
  }
  store.documents.delete(key); await expect(run()).rejects.toMatchObject({code: 'failed-precondition'});
});
it('rejects orphan claims and a valid new claim changing a profile during the scan', async () => {
  addMember('a'); await claim('a', 25); store.documents.delete('orgs/gainpath/appCheckInProfiles/a');
  await expect(run()).rejects.toMatchObject({code: 'failed-precondition'});
  store = new MemoryStore(); store.documents.set('users/admin', {organizationId: 'gainpath'}); store.documents.set('orgs/gainpath', {status: 'active'}); store.documents.set('orgs/gainpath/members/admin', {organizationId: 'gainpath', role: 'admin', status: 'active', branchIds: []}); addMember('a'); await claim('a', 25);
  await expect(run({...reader, claims: async (uid, after, limit) => {const rows = await reader.claims(uid, after, limit); await claim('a', 26); return rows;}})).rejects.toMatchObject({code: 'failed-precondition'});
});
it('invalid fields and excessive eligible Member cohorts fail without partial totals', async () => {
  await expect(adminCheckInReport(store, actor, {...query, points: 500}, reader, () => now)).rejects.toBeDefined();
  for (let i = 0; i < 201; i++) addMember('m' + i.toString().padStart(3, '0'));
  await expect(run()).rejects.toMatchObject({code: 'resource-exhausted'});
});
it('profile update chronology must agree with its latest confirmed receipt', async () => {
  addMember('a'); await claim('a', 25); const path = 'orgs/gainpath/appCheckInProfiles/a';
  store.documents.set(path, {...store.documents.get(path), updatedAtMillis: Date.UTC(2026, 9, 24, 5)});
  await expect(run()).rejects.toMatchObject({code: 'failed-precondition'});
});
it('the all-time ledger scan cap never returns partial interval totals', async () => {
  addMember('a');
  const rows = Array.from({length: 2001}, (_, i) => {const claimedAtMillis = Date.UTC(2020, 0, 1, 5) + i * 86400000, date = new Date(claimedAtMillis + 8 * 3600000).toISOString().slice(0, 10);
    return {id: date, data: {schemaVersion: 1, organizationId: 'gainpath', memberId: 'a', date, claimedAtMillis, points: 50, policyVersion: 'app-check-in-v1', source: 'app_check_in'}};});
  await expect(run({...reader, claims: async (_uid, after, limit) => rows.filter(r => !after || r.id > after).slice(0, limit)})).rejects.toMatchObject({code: 'resource-exhausted'});
});
it('schema two negotiates extra read-only sources without changing schema one response',async()=>{
 const q={...query,schemaVersion:2};const data={...reader,page:async()=>[]};
 const result=await adminCheckInReport(store,actor,q,data,()=>now);
 expect(result.schemaVersion).toBe(1);expect((result as unknown as {extensions:unknown}).extensions).toMatchObject({sourceCounts:{redemptions:0,rounds:0,awards:0}});
 expect((await run() as unknown as {extensions?:unknown}).extensions).toBeUndefined();
 await expect(adminCheckInReport(store,actor,q,reader,()=>now)).rejects.toMatchObject({code:'failed-precondition'});
});
it('non Admin schema two never reads extra sources',async()=>{
 let pages=0;await expect(adminCheckInReport(store,{uid:'member',token:actor.token},{...query,schemaVersion:2},{...reader,page:async()=>{pages++;return[];}},()=>now)).rejects.toMatchObject({code:'permission-denied'});expect(pages).toBe(0);
});
