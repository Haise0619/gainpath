import {expect,it,vi} from 'vitest';
import {Timestamp} from 'firebase-admin/firestore';
import {FirestoreStore} from '../src/platform/firestore/firestore-store';
import {synchronizeGoogleBooking} from '../src/modules/coaching/automatic-google-worker';
import {googleAutomationConfig} from '../src/modules/coaching/google-automation-config';
it('defaults automation off and declares the dedicated secret/runtime and updated-only trigger',async()=>{
 expect(googleAutomationConfig()).toMatchObject({enabled:false,allowedRecipients:[],testCoachId:'',testBookingId:''});
 const endpoint=synchronizeGoogleBooking.__endpoint;
 expect(endpoint.eventTrigger).toMatchObject({eventType:'google.cloud.firestore.document.v1.updated',retry:true});
 expect(JSON.stringify(endpoint.serviceAccountEmail)).toContain('GOOGLE_GYM_SERVICE_ACCOUNT');
 expect(endpoint.secretEnvironmentVariables).toContainEqual(expect.objectContaining({key:'GOOGLE_GYM_CLIENT_SECRET'}));
 await synchronizeGoogleBooking.run({params:{organizationId:'other',bookingId:'booking'},data:undefined} as any);
});
it('checks exact Firestore update timestamps in the delivery transaction, including getAll',async()=>{
 const old=Timestamp.fromMillis(100),current=Timestamp.fromMillis(101),snapshot={updateTime:current,data:()=>({status:'confirmed'})};
 const tx={get:vi.fn(async()=>snapshot),getAll:vi.fn(async()=>[snapshot]),set:vi.fn(),create:vi.fn()};const db={doc:(p:string)=>p,runTransaction:(f:any)=>f(tx)};
 const stale=new FirestoreStore(db as any,{path:'bookings/b',updateTime:old});
 await expect(stale.transact(t=>t.get('bookings/b'))).rejects.toMatchObject({code:'aborted'});
 await expect(stale.transact(t=>t.getAll!(['bookings/b']))).rejects.toMatchObject({code:'aborted'});
 const matching=new FirestoreStore(db as any,{path:'bookings/b',updateTime:current});expect(await matching.transact(t=>t.get('bookings/b'))).toEqual({status:'confirmed'});expect(tx.set).not.toHaveBeenCalled();
});
