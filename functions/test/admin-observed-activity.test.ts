import {it,expect} from 'vitest';
import {observedActivity,type ObservationEvent,type ObservationReader} from '../src/modules/analytics/admin-observed-activity';
import {payload} from './workout-backup-fixture';
import {digestOf} from '../src/modules/workouts/workout-backup-validation';
const day=86400000,from=Date.UTC(2026,9,24,16),until=from+2*day,now=until+day;
const reader:ObservationReader={page:async()=>[],backups:async()=>[]};
const event=(memberId:string,at:number):ObservationEvent=>({memberId,at,source:'checkIns'});
it('uses observed cohort distinct returning members and no-activity is unknown, not inactive',async()=>{
 const r=await observedActivity('gainpath',from,until,now,['a','b','c'],[event('a',from-day),event('a',from),event('a',from+1),event('b',from+day),event('foreign',from)],reader,async()=>{});
 expect(r.returning).toEqual({available:true,previousMembers:1,currentMembers:2,returningMembers:1,ratePercent:100});expect(r.sourceCounts.checkIns).toBe(3);expect(r.daily[0].uniqueMembers).toBe(1);expect(r.recency.noObservedActivity).toBe(1);expect(JSON.stringify(r)).not.toContain('memberId');
});
it('Malaysia inclusive start/exclusive end, historical recency excludes later records',async()=>{
 const r=await observedActivity('gainpath',from,until,now,['a','b'],[event('a',from-1),event('a',from),event('b',until),event('b',now)],reader,async()=>{});expect(r.sourceCounts.checkIns).toBe(1);expect(r.daily[0].date).toBe('2026-10-25');expect(r.recency.noObservedActivity).toBe(1);
});
it('uses camera end time and validated backup digest; no routine capture duplication',async()=>{
 const p={...payload,userId:'a'},b={schemaVersion:1,classification:'provisional_member_backup',kind:'session',id:'s1',key:'session-s1',payloadJson:JSON.stringify(p),digest:digestOf(p)};
 const r=await observedActivity('gainpath',from,until,now,['a'],[],{...reader,backups:async()=>[{id:'session-s1',data:b}]},async()=>{});expect(r.sourceCounts.workoutBackups).toBe(1);
 await expect(observedActivity('gainpath',from,until,now,['a'],[],{...reader,backups:async()=>[{id:'session-s1',data:{...b,digest:'bad'}}]},async()=>{})).rejects.toMatchObject({code:'failed-precondition'});
});
it('counts booking creation and game starts separately from completions and excludes foreign cohort',async()=>{
 const r=await observedActivity('gainpath',from,until,now,['a'],[],{...reader,page:async(kind)=>kind==='bookings'?[{id:'b',data:{schemaVersion:1,organizationId:'gainpath',memberId:'a',createdAtMillis:from,status:'confirmed'}}]:[{id:'a'.repeat(32),data:{schemaVersion:1,organizationId:'gainpath',attemptId:'a'.repeat(32),lastAtMillis:from,activeMillis:0,physicalVerified:false,pointsAwarded:0,expiresAtMillis:from+900000,sequence:0,memberId:'a',startedAtMillis:from,gameId:'reach-tap-v1',status:'open'}}]},async()=>{});expect(r.sourceCounts).toEqual({checkIns:0,bookings:1,games:1,workoutBackups:0});expect(r.daily[0].uniqueMembers).toBe(1);
});
it('incomplete comparison and zero denominator return no percentage',async()=>{
 const r=await observedActivity('gainpath',from,until,from+1,['a'],[],reader,async()=>{});expect(r.returning.available).toBe(false);expect(r.returning.ratePercent).toBeNull();const empty=await observedActivity('gainpath',from,until,now,[],[],reader,async()=>{});expect(empty.returning.ratePercent).toBeNull();
});
it('bounded scans, foreign data, and authorization drift fail without partial totals',async()=>{
 await expect(observedActivity('gainpath',from,until,now,[],[],{...reader,page:async()=>[{id:'b',data:{organizationId:'other'}}]},async()=>{})).rejects.toMatchObject({code:'failed-precondition'});
 await expect(observedActivity('gainpath',from,until,now,[],[],reader,async()=>{throw Error('revoked');})).rejects.toThrow('revoked');
 await expect(observedActivity('gainpath',from,until,now,[],[],{...reader,page:async()=>Array.from({length:101},(_,i)=>({id:String(i),data:{}}))},async()=>{})).rejects.toMatchObject({code:'failed-precondition'});
});

it('recency bins use Malaysia calendar ages 0-6, 7-29 and 30+ without off-by-one',async()=>{
 const asOf=until-1,ids=['six','seven','twentynine','thirty'];const r=await observedActivity('gainpath',from,until,now,ids,[event('six',asOf-6*day),event('seven',asOf-7*day),event('twentynine',asOf-29*day),event('thirty',asOf-30*day)],reader,async()=>{});expect(r.recency).toEqual({within7Days:1,days8To30:2,over30Days:1,noObservedActivity:0});
});
it('rejects malformed observed round evidence independently of the earlier engagement scan',async()=>{
 await expect(observedActivity('gainpath',from,until,now,['a'],[],{...reader,page:async(kind)=>kind==='bookings'?[]:[{id:'a'.repeat(32),data:{schemaVersion:1,organizationId:'gainpath',attemptId:'a'.repeat(32),gameId:'reach-tap-v1',memberId:'a',startedAtMillis:from,status:'awaiting_verification',lastAtMillis:from+1,activeMillis:40000,pointsAwarded:0,physicalVerified:false,expiresAtMillis:from+900000,sequence:10}}]},async()=>{})).rejects.toMatchObject({code:'failed-precondition'});
});
