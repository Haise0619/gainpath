import {initializeApp, deleteApp, type App} from 'firebase-admin/app';
import {getFirestore, FieldPath, type Firestore} from 'firebase-admin/firestore';
import {beforeAll, beforeEach, afterAll, it, expect} from 'vitest';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment, assertFails} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc} from 'firebase/firestore';
import {FirestoreStore} from '../src/platform/firestore/firestore-store';
import {rewardCatalogCommand} from '../src/modules/gamification/reward-catalog-service';
import {rewardsCommand, type RewardsHistoryReader} from '../src/modules/gamification/verified-rewards-service';
import {appCheckInCommand} from '../src/modules/gamification/app-check-in-service';
import {readPointsHistory} from '../src/modules/gamification/points-history';
const project = 'demo-gainpath-reward-journey', org = 'gainpath', now = Date.UTC(2026, 9, 26, 8), DAY = 86400000;
const actor = (uid: string) => ({uid, token: {email_verified: true, auth_time: 100}}), identity = async () => ({exists: true, disabled: false, emailVerified: true});
let app: App, db: Firestore;
const path = (collection: string, id: string) => `orgs/${org}/${collection}/${id}`;
const reader: RewardsHistoryReader = {page: async (uid, after, limit) => {let q = db.collection(`orgs/${org}/rewardRedemptions`).where('memberId', '==', uid).orderBy(FieldPath.documentId()).limit(limit); if (after) q = q.startAfter(after); return (await q.get()).docs.map(d => ({id: d.id, data: d.data()}));}};
const command = (uid: string, action: string, fields = {}, at = now) => rewardsCommand(new FirestoreStore(db), actor(uid), {schemaVersion: 1, organizationId: org, action, ...(action === 'redeem' ? {expectedPointCost: 50, expectedItemRevision: 1} : {}), ...fields}, identity, () => at, reader);
const publish = (action: string, fields = {}) => rewardCatalogCommand(new FirestoreStore(db), actor('admin'), {schemaVersion: 1, organizationId: org, action, ...fields}, () => now);
beforeAll(() => {if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:18088') throw Error('Dedicated loopback emulator required'); app = initializeApp({projectId: project}, 'reward-journey'); db = getFirestore(app);});
afterAll(async () => {await db?.terminate(); if (app) await deleteApp(app);});
beforeEach(async () => {
  await fetch(`http://127.0.0.1:18088/emulator/v1/projects/${project}/databases/(default)/documents`, {method: 'DELETE'});
  const b = db.batch(); b.set(db.doc('orgs/' + org), {status: 'active'});
  for (const uid of ['member', 'other', 'admin']) {
    b.set(db.doc('users/' + uid), {organizationId: org}); b.set(db.doc(path('members', uid)), {organizationId: org, userId: uid, status: 'active', role: uid === 'admin' ? 'admin' : 'member', branchIds: []});
    if (uid !== 'admin') {
      b.set(db.doc(path('membershipAccounts', uid)), {organizationId: org, memberId: uid, planId: 'basic', expiresAtMillis: now + 30 * DAY, lastTransactionId: uid});
      b.set(db.doc(path('transactions', uid)), {schemaVersion: 1, organizationId: org, memberId: uid, transactionId: uid, kind: 'MembershipPurchase', planId: 'basic', environment: 'sandbox', provider: 'billplz', currency: 'MYR', paymentStatus: 'cleared', fulfilmentStatus: 'confirmed', billId: uid, collectionId: 'synthetic', amountMinor: 8900, durationDays: 30, clearedAtMillis: now - 1, expiresAtMillis: now + 30 * DAY, planName: 'Synthetic Basic', benefits: []});
    }
  }
  b.set(db.doc(path('rewardCatalog', 'bottle')), {schemaVersion: 1, revision: 1, title: 'Training bottle', description: 'Reusable bottle', imageUrl: '', category: 'Merchandise', status: 'draft'}); await b.commit();
  await publish('configure', {requestId: 'setup', pointsPerUnit: 50, unitValueMinor: 100, enabled: true});
  await publish('publish', {requestId: 'publish', itemId: 'bottle', draftRevision: 1, baseItemRevision: 0, pointCost: 50, valueMinor: 100, stockToAdd: 1, validityDays: 1, conditions: 'Collect in person', collectionInstructions: 'Reception desk'});
});
it('actual daily claim → wallet → redemption → My Rewards → Admin inspection → once-only collection', async () => {
  const claimed = await appCheckInCommand(new FirestoreStore(db), actor('member'), {schemaVersion: 1, organizationId: org, action: 'claim'}, () => now);
  expect(claimed.snapshot.balance).toBe(50);
  const issued = (await command('member', 'redeem', {itemId: 'bottle', requestId: 'one'})).redemption;
  expect((await command('member', 'history', {afterId: null})).redemptions[0].redemptionId).toBe(issued.redemptionId);
  expect((await command('admin', 'inspect', {redemptionId: issued.redemptionId})).redemption.status).toBe('issued');
  await Promise.all([command('admin', 'fulfil', {redemptionId: issued.redemptionId}), command('admin', 'fulfil', {redemptionId: issued.redemptionId})]);
  expect((await command('member', 'voucher', {redemptionId: issued.redemptionId})).redemption.status).toBe('fulfilled');
  expect((await db.doc(path('rewardBalances', 'member')).get()).data()?.points).toBe(0);
  const history=await readPointsHistory(new FirestoreStore(db),actor('member'),org,async()=>{
    const claims=await db.collection(path('appCheckInProfiles','member')+'/claims').get(),redemptions=await db.collection(`orgs/${org}/rewardRedemptions`).where('memberId','==','member').get();
    return {claims:claims.docs.map(d=>({id:d.id,data:d.data()})),redemptions:redemptions.docs.map(d=>({id:d.id,data:d.data()})),awards:[],adjustments:[]};
  },()=>now);
  expect(history.reconciled).toBe(true);expect(history.entries.map(e=>e.points).sort((a,b)=>a-b)).toEqual([-50,50]);
});
it('expired vouchers remain spent and stock stays reserved; neither points nor collection can be forged', async () => {
  await appCheckInCommand(new FirestoreStore(db), actor('member'), {schemaVersion: 1, organizationId: org, action: 'claim'}, () => now);
  const issued = (await command('member', 'redeem', {itemId: 'bottle', requestId: 'one'})).redemption;
  expect((await command('member', 'voucher', {redemptionId: issued.redemptionId}, now + DAY)).redemption.status).toBe('expired');
  await expect(command('admin', 'fulfil', {redemptionId: issued.redemptionId}, now + DAY)).rejects.toMatchObject({code: 'failed-precondition'});
  expect((await db.doc(path('rewardItems', 'bottle')).get()).data()?.stock).toBe(0); expect((await db.doc(path('rewardBalances', 'member')).get()).data()?.points).toBe(0);
  const env = await initializeTestEnvironment({projectId: project, firestore: {host: '127.0.0.1', port: 18088, rules: readFileSync('../firebase/firestore.rules', 'utf8')}});
  try {for (const uid of ['member', 'admin']) for (const kind of ['rewardItems', 'rewardBalances', 'rewardRedemptions', 'rewardCatalogOperations']) {
    const client = env.authenticatedContext(uid, {email_verified: true}).firestore(), ref = doc(client, path(kind, issued.redemptionId));
    await assertFails(getDoc(ref)); await assertFails(setDoc(ref, {points: 9999, status: 'fulfilled'}));
  }} finally {await env.cleanup();}
});
it('competing last-stock requests and retried publisher stock additions stay atomic', async () => {
  for (const uid of ['member', 'other']) await appCheckInCommand(new FirestoreStore(db), actor(uid), {schemaVersion: 1, organizationId: org, action: 'claim'}, () => now);
  const outcomes = await Promise.allSettled(['member', 'other'].map(uid => command(uid, 'redeem', {itemId: 'bottle', requestId: 'last'})));
  expect(outcomes.filter(r => r.status === 'fulfilled')).toHaveLength(1);
  const fields = {requestId: 'add', itemId: 'bottle', draftRevision: 1, baseItemRevision: 1, pointCost: 50, valueMinor: 100, stockToAdd: 3, validityDays: 1, conditions: 'Collect in person', collectionInstructions: 'Reception'};
  await Promise.all([publish('publish', fields), publish('publish', fields)]);
  expect((await db.doc(path('rewardItems', 'bottle')).get()).data()?.stock).toBe(3);
});
it('one direct save creates a redeemable reward without an intermediate draft and rejected fields leave no partial item', async () => {
  const input = {requestId: 'direct', itemId: 'direct', baseItemRevision: 0, title: 'Training towel', description: 'Soft towel', category: 'Merchandise', imageUrl: '', pointCost: 50, valueMinor: 100, stockToAdd: 2, validityDays: 10, conditions: 'Collect in person', collectionInstructions: 'Reception'};
  await Promise.all([publish('save', input), publish('save', input)]);
  expect((await db.doc(path('rewardCatalog', 'direct')).get()).exists).toBe(false);
  expect((await db.doc(path('rewardItems', 'direct')).get()).data()).toMatchObject({title: 'Training towel', stock: 2, revision: 1, active: true});
  await appCheckInCommand(new FirestoreStore(db), actor('member'), {schemaVersion: 1, organizationId: org, action: 'claim'}, () => now);
  const issued = await command('member', 'redeem', {itemId: 'direct', requestId: 'direct-member'});
  expect(issued.redemption.title).toBe('Training towel');
  await expect(publish('save', {...input, requestId: 'invalid', itemId: 'invalid', conditions: ''})).rejects.toBeDefined();
  expect((await db.doc(path('rewardItems', 'invalid')).get()).exists).toBe(false);
});
it('points-only save needs no conversion policy; concurrent last-stock redemption stays once-only and client catalog writes are denied', async () => {
  await db.doc(path('rewardPolicies','current')).delete();
  const input={requestId:'points-create',itemId:'points-item',baseItemRevision:0,title:'Points reward',description:'Direct points',category:'Merchandise',imageUrl:'',pointCost:37,stockToAdd:1,validityDays:10,conditions:'Collect in person',collectionInstructions:'Reception'};
  await Promise.all([publish('savePoints',input),publish('savePoints',input)]);
  expect((await db.doc(path('rewardPolicies','current')).get()).exists).toBe(false);
  const record=(await db.doc(path('rewardItems','points-item')).get()).data();expect(record).toMatchObject({pointCost:37,stock:1,pricingMode:'points_only'});expect(record).not.toHaveProperty('valueMinor');
  for(const uid of ['member','other'])await appCheckInCommand(new FirestoreStore(db),actor(uid),{schemaVersion:1,organizationId:org,action:'claim'},()=>now);
  const results=await Promise.allSettled(['member','other'].map(uid=>command(uid,'redeem',{itemId:'points-item',requestId:'points-redeem',expectedPointCost:37})));
  expect(results.filter(r=>r.status==='fulfilled')).toHaveLength(1);
  expect((await db.doc(path('rewardItems','points-item')).get()).data()?.stock).toBe(0);
  const winner=results.findIndex(r=>r.status==='fulfilled'),uid=['member','other'][winner];
  const issued=(results[winner] as PromiseFulfilledResult<any>).value.redemption;
  expect((await command(uid,'redeem',{itemId:'points-item',requestId:'points-redeem',expectedPointCost:37})).redemption.redemptionId).toBe(issued.redemptionId);
  expect((await db.doc(path('rewardBalances',uid)).get()).data()?.points).toBe(13);
  await publish('retirePoints',{requestId:'remove-points',itemId:'points-item',baseItemRevision:1});
  expect((await command(uid,'voucher',{redemptionId:issued.redemptionId})).redemption.status).toBe('issued');
  const env=await initializeTestEnvironment({projectId:project,firestore:{host:'127.0.0.1',port:18088,rules:readFileSync('../firebase/firestore.rules','utf8')}});
  try{for(const actorId of ['member','admin']){const client=env.authenticatedContext(actorId,{email_verified:true}).firestore();await assertFails(setDoc(doc(client,path('rewardShops','current')),{itemIds:['forged']}));await assertFails(getDoc(doc(client,path('rewardShops','current'))));}}finally{await env.cleanup();}
});
