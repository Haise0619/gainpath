import {expect,it} from 'vitest';
import {buildPointsHistory,readPointsHistory} from '../src/modules/gamification/points-history';
import {seed,auth,adminAuth,org,now,path} from './reward-journey-fixture';
import {miniGameParticipation} from '../src/modules/gamification/mini-game-participation';
const base={schemaVersion:1,organizationId:'o',memberId:'m'};
it('combines confirmed earnings/manual credits/spending newest first without inventing balance adjustments',()=>{
 const result=buildPointsHistory('o','m',100,2000,{claims:[{id:'1970-01-01',data:{...base,date:'1970-01-01',source:'app_check_in',policyVersion:'app-check-in-v1',points:50,claimedAtMillis:1000}}],awards:[],adjustments:[{id:'credit',data:{...base,requestId:'credit',source:'owner_manual_adjustment',points:10000,balanceBefore:50,balanceAfter:10050,awardedAtMillis:1500}}],redemptions:[{id:'voucher',data:{...base,redemptionId:'voucher',itemId:'bottle',title:'Bottle',points:500,status:'issued',issuedAtMillis:1800,requestId:'r',policyVersion:'v',exchangeRateVersion:'points-only-v1'}}]});
 expect(result.entries.map(e=>e.points)).toEqual([-500,10000,50]);expect(result.balance).toBe(100);expect(result.reconciled).toBe(false);
});
it('history rejects non-Member authority before scanning and concurrent balance changes after scanning',async()=>{
 const store=seed();let reads=0;const empty={claims:[],awards:[],adjustments:[],redemptions:[]};
 await expect(readPointsHistory(store,adminAuth,org,async()=>{reads++;return empty;},()=>now)).rejects.toThrow();expect(reads).toBe(0);
 await expect(readPointsHistory(store,auth,org,async()=>{store.documents.set(path('rewardBalances','member'),{...store.documents.get(path('rewardBalances','member')),points:999});return empty;},()=>now)).rejects.toMatchObject({code:'aborted'});
});
it('rejects foreign, corrupt, future and incomplete source scans',()=>{
 const rows={claims:[],awards:[],adjustments:[],redemptions:[]};
 expect(()=>buildPointsHistory('o','m',0,2000,{...rows,adjustments:[{id:'x',data:{...base,memberId:'other'}}]})).toThrow();
 expect(()=>buildPointsHistory('o','m',0,2000,{...rows,claims:Array(201).fill({id:'x',data:base})})).toThrow();
});
it('labels an owner demo bonus honestly without presenting it as a workout or check-in',()=>{
 const award={...base,awardId:'bonus',eventId:'owner-demo-bonus-20261027',sourceId:'owner_demo_bonus',producerVersion:'owner-demo-bonus-v1',policyVersion:'owner-demo-bonus-20261027-v1',basePoints:100,points:100,premiumBonus:false,awardedAtMillis:1000,reason:'Owner-approved one-time demo bonus'};
 const r=buildPointsHistory('o','m',100,2000,{claims:[],awards:[{id:'bonus',data:award}],adjustments:[],redemptions:[]});
 expect(r.entries[0]).toMatchObject({title:'Demo bonus',source:'activity_reward',points:100});expect(r.reconciled).toBe(true);
});

it('merges participation into one history but reconciles each wallet independently',async()=>{
 const store=seed(),attemptId='a'.repeat(32);
 store.documents.set(path('miniGameRoundSessions',attemptId),{schemaVersion:1,organizationId:org,memberId:auth.uid,gameId:'move-catch-v1',attemptId,
 status:'awaiting_verification',activeMillis:40000,sequence:21,startedAtMillis:now-45000,lastAtMillis:now-1000,expiresAtMillis:now-45000+900000,physicalVerified:false,pointsAwarded:0});
 const earned=await miniGameParticipation(store,auth,{schemaVersion:2,organizationId:org,action:'claimParticipation',attemptId},
 {freshAuth:async()=>{},clock:()=>now,releaseApproved:true});
 const participation=[{id:earned.award.awardId,data:earned.award}];
 const rows={claims:[],awards:[],adjustments:[],redemptions:[],participation};
 const result=await readPointsHistory(store,auth,org,async()=>rows,()=>now);
 expect(result).toMatchObject({schemaVersion:2,balance:1020,demoBalance:0,demoReconciled:true});
 expect(result.entries).toEqual([expect.objectContaining({source:'mini_game_participation',wallet:'spendable',points:20,redemptionId:null})]);
 for(const patch of [{memberId:'other'},{redeemable:false},{physicalVerified:true},{points:40},{policyVersion:'forged'}]){
  await expect(readPointsHistory(store,auth,org,async()=>({...rows,participation:[{...participation[0],data:{...earned.award,...patch}}]}),()=>now)).rejects.toThrow();
 }
 await expect(readPointsHistory(store,auth,org,async()=>{
  store.documents.set(path('miniGameParticipationBalances',auth.uid),{schemaVersion:1,organizationId:org,memberId:auth.uid,mode:'participation_demo',redeemable:false,demoPoints:40});return rows;
 },()=>now)).rejects.toMatchObject({code:'aborted'});
});
