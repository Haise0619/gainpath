import {expect,it} from 'vitest';
import {MemoryStore} from './memory-store';
import {appCheckInCommand} from '../src/modules/gamification/app-check-in-service';
const now=1800000000000,day=86400000,org='gainpath',uid='member';
function fixture(tier='premium',expires=now+day){
 const store=new MemoryStore();
 store.documents.set('users/member',{organizationId:org});
 store.documents.set(`orgs/${org}`,{status:'active'});
 store.documents.set(`orgs/${org}/members/${uid}`,{organizationId:org,userId:uid,status:'active',role:'member',branchIds:[]});
 if(tier!=='free'){
 store.documents.set(`orgs/${org}/membershipAccounts/${uid}`,{organizationId:org,memberId:uid,planId:tier,lastTransactionId:'paid',expiresAtMillis:expires});
 store.documents.set(`orgs/${org}/transactions/paid`,{schemaVersion:1,organizationId:org,memberId:uid,transactionId:'paid',kind:'MembershipPurchase',environment:'sandbox',provider:'billplz',currency:'MYR',planId:tier,planName:'Fixture',benefits:[],billId:'bill',collectionId:'collection',amountMinor:12900,durationDays:30,clearedAtMillis:now-day,expiresAtMillis:expires,paymentStatus:'cleared',fulfilmentStatus:'confirmed'});
 }
 return store;
}
function policy(store:MemoryStore){store.documents.set(`orgs/${org}/settings/premiumCheckInBonus`,{schemaVersion:1,organizationId:org,enabled:true,version:'test-only-17',bonusPoints:17,effectiveFromMillis:now-1,effectiveUntilMillis:now+3*day});}
const claim=(store:MemoryStore,at=now)=>appCheckInCommand(store,{uid,token:{email_verified:true,auth_time:now/1000}},{schemaVersion:1,organizationId:org,action:'claim'},()=>at);
it('configured test-only Premium bonus credits once with separate receipt provenance',async()=>{
 const s=fixture();policy(s);const rows=await Promise.all([claim(s),claim(s)]);
 expect(rows.map(r=>r.snapshot.balance)).toEqual([67,67]);
 expect(rows[0].snapshot.recentClaims[0]).toMatchObject({points:67,basePoints:50,premiumBonusPoints:17,premiumBonusPolicyVersion:'test-only-17'});
});
it.each(['free','basic','elite'])('%s retains base points only',async tier=>{const s=fixture(tier);policy(s);expect((await claim(s)).snapshot.balance).toBe(50);});
it('expired Premium and missing policy never invent a bonus',async()=>{const s=fixture('premium',now);policy(s);expect((await claim(s)).snapshot.balance).toBe(50);expect((await claim(fixture())).snapshot.balance).toBe(50);});
it('configuration changes do not retroactively top up an existing daily receipt',async()=>{const s=fixture();await claim(s);policy(s);expect((await claim(s)).snapshot.balance).toBe(50);});
it('Free accumulates base points across days and upgrading preserves wallet',async()=>{const s=fixture('free');expect((await claim(s)).snapshot.balance).toBe(50);expect((await claim(s,now+day)).snapshot.balance).toBe(100);const paid=fixture('basic',now+5*day);for(const [k,v] of paid.documents)if(k.includes('/membershipAccounts/')||k.includes('/transactions/'))s.documents.set(k,v);expect((await claim(s,now+day)).snapshot.balance).toBe(100);});
