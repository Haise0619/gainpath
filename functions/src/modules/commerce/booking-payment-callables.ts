import { getFirestore } from 'firebase-admin/firestore';
import { onCall, onRequest } from 'firebase-functions/v2/https';
import { defineSecret, defineString } from 'firebase-functions/params';
import { createHash } from 'node:crypto';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { DomainError } from '../../platform/errors';
import { coachCommandError } from '../coaching/coach-profile-callables';
import { readCoachIdentity } from '../coaching/coach-identity-reader';
import { BillplzSandboxGateway, verifyBillplzCallback } from './billplz-sandbox';
import { createBookingPayment, getBookingPaymentQuote, readBookingPayment, settleBookingPayment } from './booking-payment-service';

const apiKey = defineSecret('BILLPLZ_SANDBOX_API_KEY');
const signatureKey = defineSecret('BILLPLZ_SANDBOX_X_SIGNATURE_KEY');
const collection = defineString('BILLPLZ_SANDBOX_COLLECTION_ID', { default: '' });
const organization = defineString('BILLPLZ_SANDBOX_ORGANIZATION_ID', { default: 'gainpath' });
const enabled = defineString('BILLPLZ_SANDBOX_ENABLED', { default: 'false' });
function configured(raw?: unknown) {
  if (enabled.value() !== 'true' || !/^[A-Za-z0-9_-]{1,128}$/.test(collection.value())) throw new DomainError('unavailable','Sandbox checkout is not enabled.');
  if (raw && (raw as Record<string,unknown>).organizationId !== organization.value()) throw new DomainError('permission-denied','Sandbox organization unavailable.');
}
function gateway() {
  const project=process.env.GCLOUD_PROJECT ?? process.env.GOOGLE_CLOUD_PROJECT;
  if (!project || !/^[a-z0-9-]+$/.test(project)) throw new DomainError('unavailable','Sandbox callback configuration unavailable.');
  return new BillplzSandboxGateway({apiKey:apiKey.value(),collectionId:collection.value(),callbackUrl:`https://us-central1-${project}.cloudfunctions.net/paymentWebhook`,redirectUrl:`https://us-central1-${project}.cloudfunctions.net/billplzSandboxReturn`});
}
const store=()=>new FirestoreStore(getFirestore());
export const getBookingPaymentQuoteCommand=onCall({enforceAppCheck:true},async r=>{
  try { configured(r.data); return await getBookingPaymentQuote(store(),r.auth,r.data); } catch(e) {throw coachCommandError(e);}
});
export const createBookingPaymentCommand=onCall({enforceAppCheck:true,secrets:[apiKey]},async r=>{
  try { configured(r.data); return await createBookingPayment(store(),r.auth,r.data,gateway(),readCoachIdentity); } catch(e) {throw coachCommandError(e);}
});
export const getBookingPaymentCommand=onCall({enforceAppCheck:true,secrets:[apiKey]},async r=>{
  try { configured(r.data); return await readBookingPayment(store(),r.auth,r.data,gateway(),readCoachIdentity); } catch(e) {throw coachCommandError(e);}
});

export const paymentWebhook=onRequest({secrets:[apiKey,signatureKey]},async(req,res)=>{
  if(req.method!=='POST'){res.set('Allow','POST').status(405).send('POST required');return;}
  try {
    configured();
    if(!req.is('application/x-www-form-urlencoded')) throw new DomainError('invalid-argument','Unsupported callback format.');
    const fields=verifyBillplzCallback(req.rawBody,signatureKey.value());
    if(!/^[A-Za-z0-9_-]{1,128}$/.test(fields.id??'') || fields.collection_id!==collection.value() || !['true','false'].includes(fields.paid) || !['paid','due','deleted'].includes(fields.state)) throw new DomainError('unauthenticated','Invalid callback identity.');
    const canonical=Object.keys(fields).sort().map(k=>[k,fields[k]]);
    const eventId=createHash('sha256').update(JSON.stringify(canonical)).digest('hex');
    const db=getFirestore(), ingress=db.doc(`system/paymentIngress/events/${eventId}`);
    const claim=await db.runTransaction(async tx=>{
      const old=(await tx.get(ingress)).data(),now=Date.now();
      if(old?.status==='processed')return 'processed';
      if(Number(old?.processingUntilMillis??0)>now)return 'busy';
      tx.set(ingress,{schemaVersion:1,environment:'sandbox',provider:'billplz',billId:fields.id,collectionId:fields.collection_id,callbackDigest:eventId,claimedPaid:fields.paid==='true',status:'received',createdAtMillis:old?.createdAtMillis??now,processingUntilMillis:now+30000});
      return 'claimed';
    });
    if(claim==='processed'){res.status(200).json({accepted:true});return;}
    if(claim==='busy'){res.status(503).json({accepted:false});return;}
    const rows=await db.collection(`orgs/${organization.value()}/transactions`).where('billId','==',fields.id).limit(2).get();
    if(rows.size!==1)throw new DomainError('unavailable','Callback mapping is not ready.');
    const row=rows.docs[0],record=row.data();
    if(record.environment!=='sandbox'||record.provider!=='billplz'||record.collectionId!==collection.value())throw new DomainError('failed-precondition','Payment mapping unavailable.');
    const bill=await gateway().get(fields.id); // Independent provider verification, never client status.
    if(bill.collection_id!==fields.collection_id || String(bill.amount)!==fields.amount)throw new DomainError('failed-precondition','Callback amount mismatch.');
    if(fields.paid==='true' && (!bill.paid || bill.state!=='paid'))throw new DomainError('unavailable','Provider status is not yet consistent.');
    await settleBookingPayment(store(),organization.value(),row.id,bill,readCoachIdentity);
    await db.runTransaction(async tx=>{
      const current=(await tx.get(ingress)).data();
      if(current?.status!=='processed')tx.set(ingress,{...current,status:'processed',processedAtMillis:Date.now(),processingUntilMillis:0});
    });
    res.status(200).json({accepted:true});
  } catch(e) {
    const code=e instanceof DomainError?e.code:'unavailable';
    const status=code==='unauthenticated'?401:code==='invalid-argument'?400:503;
    res.status(status).json({accepted:false,code}); // No provider responses, keys or payer data in logs.
  }
});
export const billplzSandboxReturn=onRequest((_req,res)=>{
  res.set('Cache-Control','no-store').set('Content-Security-Policy',"default-src 'none'; style-src 'unsafe-inline'")
    .status(200).type('html').send('<!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"><title>Return to GainPath</title></head><body style="font-family:system-ui;padding:32px"><h1>Return to GainPath</h1><p>Open GainPath to check your booking payment. This page does not confirm payment or a booking.</p></body></html>');
});
