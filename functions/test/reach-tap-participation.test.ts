import {beforeEach,it,expect} from 'vitest';
import {createHash} from 'node:crypto';
import {readPointsHistory} from '../src/modules/gamification/points-history';
import {miniGameParticipation,validateParticipationHistoryReceipt} from '../src/modules/gamification/mini-game-participation';
import {seed,auth,org,now} from './reward-journey-fixture';
let store:ReturnType<typeof seed>,at:number;
beforeEach(()=>{store=seed();at=now;});
const call=(gameId:string,action='participationOverview',fields={})=>miniGameParticipation(store,auth,{schemaVersion:3,organizationId:org,gameId,action,...fields},{clock:()=>at,freshAuth:async()=>{}});
function completed(id:string,gameId:string,memberId='member'){store.documents.set(`orgs/${org}/miniGameRoundSessions/${id}`,{schemaVersion:1,organizationId:org,memberId,gameId,attemptId:id,status:'awaiting_verification',activeMillis:40000,sequence:21,startedAtMillis:at-45000,lastAtMillis:at-1000,expiresAtMillis:at-45000+900000,physicalVerified:false,pointsAwarded:0});}
it('explicit Reach overview and owned completion earn20 once with immutable actual game receipt',async()=>{
 const id='a'.repeat(32);expect(await call('reach-tap-v1')).toMatchObject({schemaVersion:3,gameId:'reach-tap-v1',overview:{claimsToday:0,issuanceActive:true,remainingToday:60,policy:{version:'reach-tap-participation-v1',games:[{gameId:'reach-tap-v1',points:20,dailyClaimLimit:1}]}}});
 completed(id,'reach-tap-v1');const r=await call('reach-tap-v1','claimParticipation',{attemptId:id});expect(r).toMatchObject({result:{status:'awarded'},overview:{balance:1020,claimsToday:1},award:{gameId:'reach-tap-v1',points:20,physicalVerified:false}});
 expect(await call('reach-tap-v1','claimParticipation',{attemptId:id})).toMatchObject({result:{status:'already-awarded'},award:r.award});
 expect(()=>validateParticipationHistoryReceipt(r.award,org,'member',r.award.awardId)).not.toThrow();
 completed('b'.repeat(32),'reach-tap-v1');expect(await call('reach-tap-v1','claimParticipation',{attemptId:'b'.repeat(32)})).toMatchObject({result:{status:'game-limit'}});
});
it('concurrent both games credit40 atomically without sharing their onegame allowances',async()=>{
 completed('a'.repeat(32),'move-catch-v1');completed('b'.repeat(32),'reach-tap-v1');const r=await Promise.all([call('move-catch-v1','claimParticipation',{attemptId:'a'.repeat(32)}),call('reach-tap-v1','claimParticipation',{attemptId:'b'.repeat(32)})]);expect(r.every(x=>x.result.status==='awarded')).toBe(true);expect(store.documents.get(`orgs/${org}/rewardBalances/member`)?.points).toBe(1040);expect((await call('reach-tap-v1')).overview).toMatchObject({earnedToday:40,remainingToday:20,claimsToday:1});
});
it('shared cap lower bound, wrong game/account, prior day and incomplete rounds cannot credit',async()=>{
 const id='a'.repeat(32);completed(id,'reach-tap-v1','foreign');expect((await call('reach-tap-v1','claimParticipation',{attemptId:id})).result.status).toBe('not-completed');
 completed(id,'move-catch-v1');expect((await call('reach-tap-v1','claimParticipation',{attemptId:id})).result.status).toBe('not-completed');
 completed(id,'reach-tap-v1');const round=store.documents.get(`orgs/${org}/miniGameRoundSessions/${id}`)!;store.documents.set(`orgs/${org}/miniGameRoundSessions/${id}`,{...round,activeMillis:39999});expect((await call('reach-tap-v1','claimParticipation',{attemptId:id})).result.status).toBe('not-completed');
 completed(id,'reach-tap-v1');at+=86400000;expect((await call('reach-tap-v1','claimParticipation',{attemptId:id})).result.status).toBe('not-completed');
 completed(id,'reach-tap-v1');const date=new Date(at+8*3600000).toISOString().slice(0,10),key=createHash('sha256').update(JSON.stringify([org,'member',date])).digest('hex');store.documents.set(`orgs/${org}/miniGameParticipationDailyClaims/${key}`,{schemaVersion:1,organizationId:org,memberId:'member',timezone:'Asia/Kuala_Lumpur',date,points:50,claimsByGame:{'old-game':1}});expect((await call('reach-tap-v1','claimParticipation',{attemptId:id})).result.status).toBe('daily-limit');
});
it('legacy Move clients cannot claim a Reach attempt and pergame receipt retry cannot cross game',async()=>{
 completed('a'.repeat(32),'reach-tap-v1');const legacy=await miniGameParticipation(store,auth,{schemaVersion:2,organizationId:org,action:'claimParticipation',attemptId:'a'.repeat(32)},{clock:()=>at,freshAuth:async()=>{}});expect(legacy.result.status).toBe('not-completed');
 await call('reach-tap-v1','claimParticipation',{attemptId:'a'.repeat(32)});await expect(call('move-catch-v1','claimParticipation',{attemptId:'a'.repeat(32)})).rejects.toMatchObject({code:'failed-precondition'});
});

it('Reach cap respects lower configured cap and never expands above60',async()=>{
 for(const cap of [10,100]){
  store=seed();store.documents.set(`orgs/${org}/miniGameRewardPolicies/current`,{schemaVersion:1,organizationId:org,revision:1,version:'mini-game-rewards-v1',enabled:false,timezone:'Asia/Kuala_Lumpur',dailyPointsCap:cap,games:[{gameId:'move-catch-v1',points:20,dailyClaimLimit:1}],updatedAtMillis:at});
  expect((await call('reach-tap-v1')).overview.policy.dailyPointsCap).toBe(Math.min(60,cap));completed('a'.repeat(32),'reach-tap-v1');
  expect((await call('reach-tap-v1','claimParticipation',{attemptId:'a'.repeat(32)})).result.status).toBe(cap===10?'daily-limit':'awarded');
 }
});
it('Reach retries after spending recover same receipt and reject tampered snapshot',async()=>{
 completed('a'.repeat(32),'reach-tap-v1');const first=await call('reach-tap-v1','claimParticipation',{attemptId:'a'.repeat(32)});
 store.documents.set(`orgs/${org}/rewardBalances/member`,{schemaVersion:1,organizationId:org,memberId:'member',points:0,recentRedemptionIds:['spent']});
 expect(await call('reach-tap-v1','claimParticipation',{attemptId:'a'.repeat(32)})).toMatchObject({overview:{balance:0},award:first.award});
 for(const delta of [{points:21},{policySnapshot:{...first.award.policySnapshot,dailyPointsCap:61}},{policySnapshot:{...first.award.policySnapshot,extra:true}}])expect(()=>validateParticipationHistoryReceipt({...first.award,...delta},org,'member',first.award.awardId)).toThrow();
});
it('new Malaysia day refreshes Reach allowance while old receipt retry never credits again',async()=>{
 completed('a'.repeat(32),'reach-tap-v1');const first=await call('reach-tap-v1','claimParticipation',{attemptId:'a'.repeat(32)});at+=86400000;
 expect((await call('reach-tap-v1')).overview).toMatchObject({claimsToday:0,earnedToday:0,remainingToday:60});
 expect((await call('reach-tap-v1','claimParticipation',{attemptId:'a'.repeat(32)})).award).toEqual(first.award);
 completed('b'.repeat(32),'reach-tap-v1');expect((await call('reach-tap-v1','claimParticipation',{attemptId:'b'.repeat(32)})).overview.balance).toBe(1040);
});

it('Reach receipts reconcile into existing spendable history with game-specific title',async()=>{
 completed('a'.repeat(32),'reach-tap-v1');const r=await call('reach-tap-v1','claimParticipation',{attemptId:'a'.repeat(32)});
 // Seed an empty owned wallet to isolate receipt reconciliation without the fixture opening credit.
 store.documents.set(`orgs/${org}/rewardBalances/member`,{schemaVersion:1,organizationId:org,memberId:'member',points:20,recentRedemptionIds:[]});
 const history=await readPointsHistory(store,auth,org,async()=>({claims:[],awards:[],adjustments:[],redemptions:[],participation:[{id:r.award.awardId,data:r.award}]}),()=>at);
 expect(history.reconciled).toBe(true);expect(history.entries).toHaveLength(1);expect(history.entries[0]).toMatchObject({title:'Reach & Tap participation',points:20,wallet:'spendable'});
});
