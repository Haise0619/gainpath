import {keyOf} from '../../platform/idempotency';
import type {DocumentData} from '../../platform/firestore/store';
import type {SandboxBill} from './billplz-sandbox';

// New direct bills only. Legacy invoices and membership references stay intact.
export function bookingBillReferences(org:string,id:string,gatewayCode?:string) {
  return gatewayCode ? {reference1:gatewayCode,reference2:keyOf('booking-direct-v2',org,id)} : {reference1:id,reference2:org};
}
export function matchesBookingBillReferences(bill:SandboxBill,d:DocumentData,org:string,id:string) {
  if (d.providerReferenceVersion !== undefined && d.providerReferenceVersion !== 2) return false;
  if (d.providerReferenceVersion === 2 && (typeof d.gatewayCode !== 'string' || !/^[A-Za-z0-9_-]{1,64}$/.test(d.gatewayCode))) return false;
  const refs=bookingBillReferences(org,id,d.providerReferenceVersion===2?String(d.gatewayCode):undefined);
  return bill.reference_1===refs.reference1 && bill.reference_2===refs.reference2;
}
export function directBookingCheckoutUrl(url:string,d:DocumentData) {
  if(d.providerReferenceVersion!==2)return url;
  const parsed=new URL(url);parsed.searchParams.set('auto_submit','true');return parsed.toString();
}
