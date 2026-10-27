import {beforeEach,expect,it} from 'vitest';
import {readEarnedPointsLeaderboard} from '../src/modules/gamification/earned-points-leaderboard';
import {seed,auth,adminAuth,org,path} from './reward-journey-fixture';
import {miniGameParticipation} from '../src/modules/gamification/mini-game-participation';
let store:ReturnType<typeof seed>;
const at=Date.parse('2026-10-27T08:00:00Z');
beforeEach(()=>{store=seed();});
function member(uid:string,name=uid){store.documents.set(path('members',uid),{organizationId:org,userId:uid,role:'member',status:'active',displayName:name,branchIds:[]});store.documents.set('users/'+uid,{organizationId:org,role:'member'});}
function claim(uid:string,date:string){const t=Date.parse(date+'T08:00:00Z');store.documents.set(path('appCheckInProfiles',uid)+'/claims/'+date,{schemaVersion:1,organizationId:org,memberId:uid,date,source:'app_check_in',policyVersion:'app-check-in-v1',points:50,claimedAtMillis:t});}
function page(root:string,after:string|undefined,limit:number){return [...store.documents].filter(([p])=>p.startsWith(root+'/')&&!p.slice(root.length+1).includes('/')).map(([p,data])=>({id:p.slice(root.length+1),data})).sort((a,b)=>a.id.localeCompare(b.id)).filter(r=>!after||r.id>after).slice(0,limit);}
const reader={members:async(after:string|undefined,limit:number)=>page(`orgs/${org}/members`,after,limit),receipts:async(uid:string,source:string,after:string|undefined,limit:number)=>{
 const root=source==='claims'?path('appCheckInProfiles',uid)+'/claims':`orgs/${org}/${source==='participation'?'miniGameParticipationAwards':'rewardAwards'}`;
 return page(root,after,10000).filter(r=>r.data.memberId===uid).slice(0,limit);
}};
const run=(period='week',actor=auth)=>readEarnedPointsLeaderboard(store,actor,{schemaVersion:1,organizationId:org,action:'leaderboard',period},reader,()=>at);
it('ranks earned points with ties, excludes manual balances and redemptions and uses Malaysia Monday',async()=>{
 member('member','Zheng');member('other','Sam');claim('member','2026-10-26');claim('other','2026-10-26');claim('other','2026-10-20');
 store.documents.set(path('rewardBalances','other'),{points:999999});store.documents.set(path('rewardPointAdjustments','manual'),{memberId:'other',points:10000});
 const week=await run();expect(week).toMatchObject({period:'week',timezone:'Asia/Kuala_Lumpur',periodStartMillis:Date.parse('2026-10-25T16:00:00Z'),totalParticipants:2});
 expect(week.entries.map(e=>e.rank)).toEqual([1,1]);expect(week.you).toMatchObject({rank:1,points:50,isYou:true});
 const all=await run('all_time');expect(all.you).toMatchObject({rank:2,points:50});expect(all.entries[0].points).toBe(100);
 expect(JSON.stringify(week.entries)).not.toContain('memberId');expect(JSON.stringify(week.entries)).not.toContain('organizationId');
});
it('returns own rank outside top20 and handles no earnings',async()=>{
 member('member');claim('member','2026-10-26');for(let i=0;i<22;i++){const uid='p'+String(i).padStart(2,'0');member(uid);claim(uid,'2026-10-26');claim(uid,'2026-10-27');}
 const r=await run();expect(r.entries).toHaveLength(20);expect(r.you).toMatchObject({rank:23,points:50});expect(r.entries.every(e=>!e.isYou)).toBe(true);
 store=seed();const empty=await run();expect(empty.entries).toEqual([]);expect(empty.you).toMatchObject({rank:null,points:0});
});
it('excludes inactive and foreign canonical accounts and safely replaces missing names',async()=>{
 member('member','member@example.test');member('other');claim('member','2026-10-26');claim('other','2026-10-26');store.documents.set('users/other',{organizationId:'foreign'});
 const r=await run();expect(r.totalParticipants).toBe(1);expect(r.entries[0].displayName).toBe('Member');
});
it('rejects non-Member authority, foreign scope and client ranking overrides',async()=>{
 await expect(run('week',adminAuth)).rejects.toMatchObject({code:'permission-denied'});
 for(const fields of [{organizationId:'foreign'},{points:999},{memberId:'other'},{period:'month'},{period:['week']}])await expect(readEarnedPointsLeaderboard(store,auth,{schemaVersion:1,organizationId:org,action:'leaderboard',period:'week',...fields},reader,()=>at)).rejects.toThrow();
});
it('rejects malformed or future receipts and concurrent scope changes',async()=>{
 member('member');claim('member','2026-10-26');const receipt=store.documents.get(path('appCheckInProfiles','member')+'/claims/2026-10-26')!;
 receipt.points=500;await expect(run()).rejects.toThrow();receipt.points=50;receipt.claimedAtMillis=at+1000;await expect(run()).rejects.toThrow();
 receipt.claimedAtMillis=Date.parse('2026-10-26T08:00:00Z');
 await expect(readEarnedPointsLeaderboard(store,auth,{schemaVersion:1,organizationId:org,action:'leaderboard',period:'week'},{...reader,receipts:async(...args)=>{const result=await reader.receipts(...args);store.documents.set('users/member',{organizationId:'foreign'});return result;}},()=>at)).rejects.toThrow();
});
it('includes genuine spendable game receipts and excludes their legacy demo version',async()=>{
 member('member');const attemptId='a'.repeat(32);
 store.documents.set(path('miniGameRoundSessions',attemptId),{schemaVersion:1,organizationId:org,memberId:'member',gameId:'move-catch-v1',attemptId,status:'awaiting_verification',activeMillis:40000,sequence:21,startedAtMillis:at-45000,lastAtMillis:at-1000,expiresAtMillis:at-45000+900000,physicalVerified:false,pointsAwarded:0});
 const award=await miniGameParticipation(store,auth,{schemaVersion:2,organizationId:org,action:'claimParticipation',attemptId},{freshAuth:async()=>{},clock:()=>at,releaseApproved:true});
 expect((await run()).you).toMatchObject({points:20,rank:1});
 store.documents.set(path('miniGameParticipationAwards',award.award.awardId),{...award.award,schemaVersion:1,redeemable:false});
 expect((await run()).you).toMatchObject({points:0,rank:null});
});
it('pages beyond200 earned receipts rather than truncating all-time points',async()=>{
 member('member');for(let i=0;i<205;i++)claim('member',new Date(at-i*86400000).toISOString().slice(0,10));
 expect((await run('all_time')).you.points).toBe(205*50);
});
it('rejects changing balance witnesses',async()=>{
 member('member');claim('member','2026-10-26');
 await expect(readEarnedPointsLeaderboard(store,auth,{schemaVersion:1,organizationId:org,action:'leaderboard',period:'week'},
 {...reader,receipts:async(...args)=>{const rows=await reader.receipts(...args);store.documents.set(path('rewardBalances','member'),{points:999});return rows;}},()=>at)).rejects.toMatchObject({code:'aborted'});
});
it('counts explicitly identified owner demo bonuses while manual credits stay excluded',async()=>{
 member('member');member('other');
 store.documents.set(path('rewardAwards','bonus'),{schemaVersion:1,organizationId:org,memberId:'other',awardId:'bonus',eventId:'owner-demo-bonus-20261027',sourceId:'owner_demo_bonus',producerVersion:'owner-demo-bonus-v1',policyVersion:'owner-demo-bonus-20261027-v1',basePoints:100,points:100,premiumBonus:false,awardedAtMillis:at,reason:'Owner-approved one-time demo bonus'});
 expect((await run()).entries).toEqual([{rank:1,displayName:'other',points:100,isYou:false}]);
 const bonus=store.documents.get(path('rewardAwards','bonus'))!;
 bonus.producerVersion='client';await expect(run()).rejects.toThrow();
});
