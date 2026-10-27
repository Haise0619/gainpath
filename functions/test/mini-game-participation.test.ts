import {beforeEach,expect,it} from 'vitest';
import {createHash} from 'node:crypto';
import {miniGameParticipation} from '../src/modules/gamification/mini-game-participation';
import {auth,adminAuth,seed,now,org,identity} from './reward-journey-fixture';
import {appCheckInCommand} from '../src/modules/gamification/app-check-in-service';
import {rewardCatalogCommand} from '../src/modules/gamification/reward-catalog-service';
import {rewardsCommand} from '../src/modules/gamification/verified-rewards-service';
import {readPointsHistory} from '../src/modules/gamification/points-history';
import {defaultMiniGameRewardPolicy,miniGameRewardDate} from '../src/modules/gamification/mini-game-reward-policy';
let store:ReturnType<typeof seed>,at:number;
const attempt='a'.repeat(32),digest=(...p:unknown[])=>createHash('sha256').update(JSON.stringify(p)).digest('hex');
const path=(c:string,id:string)=>`orgs/${org}/${c}/${id}`;
beforeEach(()=>{store=seed();at=now;});
const run=(action='participationOverview',fields={},enabled=false,actor=auth)=>miniGameParticipation(store,actor,
 {schemaVersion:2,organizationId:org,action,...fields},{clock:()=>at,freshAuth:async()=>{},releaseApproved:enabled});
function completed(id=attempt,memberId='member'){
 store.documents.set(path('miniGameRoundSessions',id),{schemaVersion:1,organizationId:org,memberId,gameId:'move-catch-v1',attemptId:id,
  status:'awaiting_verification',activeMillis:40000,sequence:21,startedAtMillis:at-45000,lastAtMillis:at-1000,
  expiresAtMillis:at-45000+900000,physicalVerified:false,pointsAwarded:0});
}
it('default gate returns participation/nonredeemable overview without writes or fake credit',async()=>{
 const before=[...store.documents];const r=await run();expect(r.overview).toMatchObject({balance:1000,earnedToday:0,remainingToday:60,issuanceActive:false});
 expect(r).toMatchObject({mode:'participation',redeemable:true,physicalVerified:false,award:null,result:{status:'overview'}});
 expect([...store.documents]).toEqual(before);
 completed();const n=[...store.documents];expect((await run('claimParticipation',{attemptId:attempt})).result.status).toBe('not-active');expect([...store.documents]).toEqual(n);
});
it('completed participation credits the same spendable balance and preserves wallet fields',async()=>{
 completed();const r=await run('claimParticipation',{attemptId:attempt},true);
 expect(r).toMatchObject({result:{status:'awarded'},overview:{balance:1020,earnedToday:20,remainingToday:40},award:{points:20,verification:'participation',redeemable:true,physicalVerified:false,premiumBonus:false}});
 expect(store.documents.get(path('rewardBalances','member'))).toMatchObject({points:1020,recentRedemptionIds:[]});
 expect([...store.documents.keys()].some(p=>/rewardAwards|rewardRedemptions|miniGameVerifiedRounds|appCheckInProfiles/.test(p))).toBe(false);
});
it('concurrent retries across devices create one stable award',async()=>{
 completed();const a=await Promise.all([run('claimParticipation',{attemptId:attempt},true),run('claimParticipation',{attemptId:attempt},true)]);
 expect(a[0].award).toEqual(a[1].award);expect(a.map(v=>v.result.status).sort()).toEqual(['already-awarded','awarded']);
 expect([...store.documents.keys()].filter(p=>p.includes('/miniGameParticipationAwards/'))).toHaveLength(1);
});
it('retry after spending points recovers the original receipt without re-crediting',async()=>{
 completed();const first=await run('claimParticipation',{attemptId:attempt},true);
 store.documents.set(path('rewardBalances','member'),{schemaVersion:1,organizationId:org,memberId:'member',points:0,recentRedemptionIds:['spent']});
 const retry=await run('claimParticipation',{attemptId:attempt},true);
 expect(retry.award).toEqual(first.award);expect(retry.overview.balance).toBe(0);
 expect(store.documents.get(path('rewardBalances','member'))?.points).toBe(0);
});
it('old demo clients cannot start spendable issuance even when the release is approved',async()=>{
 completed();const response=await run('claimParticipation',{schemaVersion:1,attemptId:attempt},true);
 expect(response).toMatchObject({schemaVersion:1,redeemable:false,result:{status:'not-active'}});
 expect(store.documents.get(path('rewardBalances','member'))?.points).toBe(1000);
});
it('check-in and game earnings share one redeemable balance without sharing daily limits',async()=>{
 store.documents.set(path('rewardBalances','member'),{schemaVersion:1,organizationId:org,memberId:'member',points:0,recentRedemptionIds:[]});
 completed();
 await Promise.all([run('claimParticipation',{attemptId:attempt},true),appCheckInCommand(store,auth,{schemaVersion:1,organizationId:org,action:'claim'},()=>at)]);
 expect(store.documents.get(path('rewardBalances','member'))?.points).toBe(70);
 await rewardCatalogCommand(store,adminAuth,{schemaVersion:1,organizationId:org,action:'savePoints',requestId:'create',itemId:'bottle',baseItemRevision:0,title:'Training bottle',description:'Bottle',category:'Merchandise',imageUrl:'',pointCost:60,stockToAdd:1,validityDays:10,conditions:'Collect at gym',collectionInstructions:'Reception'},()=>at);
 const redemption=await rewardsCommand(store,auth,{schemaVersion:1,organizationId:org,action:'redeem',itemId:'bottle',requestId:'spend',expectedPointCost:60,expectedItemRevision:1},identity,()=>at);
 expect(redemption.redemption.points).toBe(60);expect(store.documents.get(path('rewardBalances','member'))?.points).toBe(10);
 expect((await run()).overview).toMatchObject({balance:10,earnedToday:20,remainingToday:40,claimsToday:1});
 const rows=(root:string)=>[...store.documents].filter(([p])=>p.startsWith(root+'/')).map(([p,data])=>({id:p.slice(root.length+1),data}));
 const history=await readPointsHistory(store,auth,org,async()=>({claims:rows(path('appCheckInProfiles','member')+'/claims'),awards:[],adjustments:[],redemptions:rows(`orgs/${org}/rewardRedemptions`),participation:rows(`orgs/${org}/miniGameParticipationAwards`)}),()=>at);
 expect(history.balance).toBe(10);expect(history.reconciled).toBe(true);
 expect(history.entries.map(e=>e.points).sort((a,b)=>a-b)).toEqual([-60,20,50]);
});
it('a first game creates a wallet that check-in and the reward shop can read',async()=>{
 store.documents.delete(path('rewardBalances','member'));completed();
 await run('claimParticipation',{attemptId:attempt},true);
 expect((await appCheckInCommand(store,auth,{schemaVersion:1,organizationId:org,action:'overview'},()=>at)).snapshot.balance).toBe(20);
 expect(store.documents.get(path('rewardBalances','member'))?.recentRedemptionIds).toEqual([]);
});
it('receipt recovery tolerates Firestore map field ordering',async()=>{
 completed();const first=await run('claimParticipation',{attemptId:attempt},true);
 const stored=[...store.documents.entries()].find(([p])=>p.includes('/miniGameParticipationAwards/'))![1];
 (stored.policySnapshot as Record<string,unknown>).games=[{dailyClaimLimit:1,points:20,gameId:'move-catch-v1'}];
 const recovered=await run('claimParticipation',{attemptId:attempt},true);expect(recovered.award).toEqual(first.award);
});
it('different completed attempts cannot bypass one rewarded game per Malaysia day',async()=>{
 completed();completed('b'.repeat(32));const results=await Promise.all([run('claimParticipation',{attemptId:attempt},true),run('claimParticipation',{attemptId:'b'.repeat(32)},true)]);
 expect(results.map(v=>v.result.status).sort()).toEqual(['awarded','game-limit']);expect(results[1].overview.balance).toBe(1020);
});
it('shared cap counts all game counters and refuses a partial award',async()=>{
 completed();store.documents.set(path('miniGameParticipationDailyClaims',digest(org,'member',miniGameRewardDate(at))),{
 schemaVersion:1,organizationId:org,memberId:'member',timezone:'Asia/Kuala_Lumpur',date:miniGameRewardDate(at),points:50,claimsByGame:{'future-game-v1':1}});
 const r=await run('claimParticipation',{attemptId:attempt},true);expect(r.result.status).toBe('daily-limit');expect(r.overview.remainingToday).toBe(10);expect(r.award).toBeNull();
});
it('malaysia midnight resets allowance but never recycles yesterday completed round',async()=>{
 at=Date.parse('2026-10-27T15:59:59Z');completed();const r=await run('claimParticipation',{attemptId:attempt},true);
 at=Date.parse('2026-10-27T16:00:01Z');expect((await run()).overview).toMatchObject({today:'2026-10-28',balance:1020,earnedToday:0,remainingToday:60});
 expect((await run('claimParticipation',{attemptId:attempt},true)).award).toEqual(r.award);
 const old='b'.repeat(32);completed(old);store.documents.get(path('miniGameRoundSessions',old))!.lastAtMillis=at-10000;
 expect((await run('claimParticipation',{attemptId:old},true)).result.status).toBe('not-completed');
});
it.each(['memberId','status','activeMillis','sequence','physicalVerified','gameId'])('invalid completion %s cannot earn',async field=>{
 completed();const invalid:Record<string,unknown>={memberId:'other',status:'open',activeMillis:39999,sequence:1,physicalVerified:true,gameId:'fake'};
 store.documents.get(path('miniGameRoundSessions',attempt))![field]=invalid[field];
 expect((await run('claimParticipation',{attemptId:attempt},true)).result.status).toBe('not-completed');
});
it('scores, amounts, dates and release overrides are rejected request fields',async()=>{
 for(const field of ['score','points','date','releaseApproved','memberId'])await expect(run('claimParticipation',{attemptId:attempt,[field]:20},true)).rejects.toMatchObject({code:'invalid-argument'});
});
it('Admin cannot claim Member demo points and canonical suspension is enforced',async()=>{
 await expect(run('participationOverview',{},true,adminAuth)).rejects.toMatchObject({code:'permission-denied'});
 store.documents.get(path('members','member'))!.status='suspended';await expect(run()).rejects.toMatchObject({code:'permission-denied'});
});
it('policy editing preserves historical receipts and daily consumption',async()=>{
 completed();const first=await run('claimParticipation',{attemptId:attempt},true);
 store.documents.set(path('miniGameRewardPolicies','current'),{...defaultMiniGameRewardPolicy(),organizationId:org,revision:1,version:'mini-game-rewards-v1',updatedAtMillis:at,
  games:[{gameId:'move-catch-v1',points:30,dailyClaimLimit:1}],dailyPointsCap:100});
 expect((await run('claimParticipation',{attemptId:attempt},true)).award).toEqual(first.award);
 completed('b'.repeat(32));expect((await run('claimParticipation',{attemptId:'b'.repeat(32)},true)).result.status).toBe('game-limit');
});
