import { beforeEach, expect, it, vi } from 'vitest';
import { createHmac } from 'node:crypto';
import { MemoryStore } from './memory-store';
import { seeds, command, now, eligibleCoach } from './booking-fixture';
import { createBookingHoldService } from '../src/modules/coaching/booking-service';
import { createBookingPayment } from '../src/modules/commerce/booking-payment-service';
import { BillplzSandboxGateway, type SandboxBill } from '../src/modules/commerce/billplz-sandbox';
import { paymentWebhook } from '../src/modules/commerce/booking-payment-callables';

vi.mock('firebase-functions/v2/https',()=>({onCall:(_opts:unknown,handler:unknown)=>handler,onRequest:(opts:unknown,handler:unknown)=>typeof opts==='function'?opts:handler,HttpsError:class extends Error{}}));
vi.mock('firebase-functions/params',()=>({defineSecret:(key:string)=>({value:()=>key.includes('X_SIGNATURE')?'synthetic-signing-key':'synthetic-api-key'}),defineString:(key:string)=>({value:()=>key.endsWith('ENABLED')?'true':key.endsWith('COLLECTION_ID')?'sandbox-collection':'org-1'})}));
vi.mock('firebase-admin/firestore',()=>({getFirestore:()=>db}));
vi.mock('../src/modules/coaching/coach-identity-reader',()=>({readCoachIdentity:async()=>({exists:true,disabled:false,emailVerified:true})}));
let memory:MemoryStore,id:string;
const db={
  doc:(path:string)=>({path}),
  runTransaction:<T>(work:(tx:unknown)=>Promise<T>)=>memory.transact(tx=>work({
    get:async(ref:{path:string})=>{const value=await tx.get(ref.path);return {data:()=>value};},
    getAll:async(...refs:{path:string}[])=>Promise.all(refs.map(async ref=>{const value=await tx.get(ref.path);return {data:()=>value};})),
    create:(ref:{path:string},data:object)=>tx.create(ref.path,data),
    set:(ref:{path:string},data:object)=>tx.set(ref.path,data),
  })),
  collection:(path:string)=>({where:(field:string,_op:string,value:string)=>({limit:(limit:number)=>({get:async()=>{
    const docs=[...memory.documents].filter(([p,d])=>p.startsWith(path+'/')&&p.split('/').length===path.split('/').length+1&&d[field]===value).slice(0,limit).map(([p,d])=>({id:p.split('/').pop()!,data:()=>d}));return {docs,size:docs.length};
  }})})}),
};
const bill=(paid=true):SandboxBill=>({id:'bill-1',collection_id:'sandbox-collection',amount:12000,paid,paid_amount:paid?12000:0,state:paid?'paid':'due',url:'https://www.billplz-sandbox.com/bills/bill-1',reference_1:id,reference_2:'org-1'});
beforeEach(async()=>{
  vi.restoreAllMocks();memory=new MemoryStore();process.env.GCLOUD_PROJECT='demo-gainpath';
  Object.entries(seeds).forEach(([p,d])=>memory.documents.set(p,structuredClone(d)));
  Object.assign(memory.documents.get('orgs/org-1/coaches/coach-1')!,{displayName:'Fixture Coach',consultationFeeMinor:12000,certificationVerified:true});
  memory.documents.set('orgs/org-1/coachProfiles/coach-1/certificationState/current',{certificationVerified:true,approvedCount:1});
  Object.assign(memory.documents.get('users/member-1')!,{email:'fixture@example.invalid',displayName:'Fixture Member'});
  id=(await createBookingHoldService(memory,'member-1',command,eligibleCoach,()=>now)).bookingId;
  await createBookingPayment(memory,{uid:'member-1',token:{email_verified:true}},{schemaVersion:1,organizationId:'org-1',bookingId:id},{create:async()=>bill(false),get:async()=>bill()},eligibleCoach,()=>now);
  vi.spyOn(Date,'now').mockReturnValue(now+1000);
});
function signed(paid='true') {
  const fields:Record<string,string>={id:'bill-1',collection_id:'sandbox-collection',amount:'12000',paid,state:paid==='true'?'paid':'due',paid_amount:paid==='true'?'12000':'0'};
  const source=Object.entries(fields).map(([k,v])=>k+v).sort((a,b)=>a.toLowerCase()<b.toLowerCase()?-1:1).join('|');
  return new URLSearchParams({...fields,x_signature:createHmac('sha256','synthetic-signing-key').update(source).digest('hex')}).toString();
}
async function invoke(raw:string) {
  let status=200,result:unknown;
  const response={set:()=>response,status:(code:number)=>{status=code;return response;},send:(body:unknown)=>{result=body;return response;},json:(body:unknown)=>{result=body;return response;}};
  const req={method:'POST',is:(type:string)=>type==='application/x-www-form-urlencoded',rawBody:Buffer.from(raw)};
  await paymentWebhook(req as never,response as never);return {status,result};
}
it('rejects tampering before provider lookup or ingress writes',async()=>{
  const get=vi.spyOn(BillplzSandboxGateway.prototype,'get').mockResolvedValue(bill());
  expect((await invoke(signed().replace('amount=12000','amount=1'))).status).toBe(401);
  expect(get).not.toHaveBeenCalled();expect([...memory.documents.keys()].some(p=>p.startsWith('system/paymentIngress/'))).toBe(false);
});
it('signed callback independently verifies provider status and replay never repeats lookup/confirmation',async()=>{
  const get=vi.spyOn(BillplzSandboxGateway.prototype,'get').mockResolvedValue(bill());
  expect((await invoke(signed())).status).toBe(200);
  expect((await invoke(signed().split('&').reverse().join('&'))).status).toBe(200);
  expect(get).toHaveBeenCalledTimes(1);
  expect(memory.documents.get(`orgs/org-1/bookings/${id}`)?.status).toBe('confirmed');
  expect([...memory.documents.values()].filter(d=>d.event==='payment_cleared')).toHaveLength(1);
});
it('does not acknowledge paid notification ahead of authoritative provider status',async()=>{
  vi.spyOn(BillplzSandboxGateway.prototype,'get').mockResolvedValue(bill(false));
  expect((await invoke(signed())).status).toBe(503);
  expect(memory.documents.get(`orgs/org-1/bookings/${id}`)?.status).toBe('pending_hold');
});
