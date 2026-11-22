import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall, onRequest, type HttpsFunction } from 'firebase-functions/v2/https';
import { defineSecret, defineString } from 'firebase-functions/params';
import { createHash, timingSafeEqual } from 'node:crypto';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { DomainError } from '../../platform/errors';
import { coachCommandError } from '../coaching/coach-profile-callables';
import { readCoachIdentity } from '../coaching/coach-identity-reader';
import { BillplzSandboxGateway, verifyBillplzCallback } from './billplz-sandbox';
import { BookingQuoteChangedError, BookingPaymentMethodUnavailableError, createBookingPayment, getBookingPaymentMethods, getBookingPaymentQuote, readBookingPayment, settleBookingPayment } from './booking-payment-service';
import { XenditBookingGateway } from './xendit-booking';
import { settleMembershipPayment } from './membership-payment-service';

const apiKey = defineSecret('BILLPLZ_SANDBOX_API_KEY');
const signatureKey = defineSecret('BILLPLZ_SANDBOX_X_SIGNATURE_KEY');
const collection = defineString('BILLPLZ_SANDBOX_COLLECTION_ID', { default: '' });
const organization = defineString('BILLPLZ_SANDBOX_ORGANIZATION_ID', { default: 'gainpath' });
const enabled = defineString('BILLPLZ_SANDBOX_ENABLED', { default: 'false' });
const xenditKey = defineSecret('XENDIT_TEST_API_KEY');
const xenditToken = defineSecret('XENDIT_TEST_WEBHOOK_TOKEN');
const xenditEnabled = defineString('XENDIT_BOOKING_ENABLED', { default: 'false' });
const xenditChannels = defineString('XENDIT_BOOKING_CHANNELS', { default: 'CIMB_FPX,TOUCHNGO,CARDS' });
const prefersXendit = (data: { supportsXendit?: unknown } | undefined) =>
  data?.supportsXendit === true && xenditEnabled.value() === 'true';

function xenditGateway() {
  const project = process.env.GCLOUD_PROJECT ?? process.env.GOOGLE_CLOUD_PROJECT;
  if (!project || !/^[a-z0-9-]+$/.test(project)) {
    throw new DomainError('unavailable', 'Payment is temporarily unavailable.');
  }
  return new XenditBookingGateway(xenditKey.value(),
    `https://us-central1-${project}.cloudfunctions.net/billplzSandboxReturn`,
    new Set(xenditChannels.value().split(',').map(channel => channel.trim())));
}

function configured(raw?: unknown, booking = false) {
  if (!(booking && xenditEnabled.value() === 'true') && (enabled.value() !== 'true' || !/^[A-Za-z0-9_-]{1,128}$/.test(collection.value()))) throw new DomainError('unavailable','Sandbox checkout is not enabled.');
  if (raw && (raw as Record<string,unknown>).organizationId !== organization.value()) throw new DomainError('permission-denied','Sandbox organization unavailable.');
}
function gateway() {
  const project=process.env.GCLOUD_PROJECT ?? process.env.GOOGLE_CLOUD_PROJECT;
  if (!project || !/^[a-z0-9-]+$/.test(project)) throw new DomainError('unavailable','Sandbox callback configuration unavailable.');
  return new BillplzSandboxGateway({apiKey:apiKey.value(),collectionId:collection.value(),callbackUrl:`https://us-central1-${project}.cloudfunctions.net/paymentWebhook`,redirectUrl:`https://us-central1-${project}.cloudfunctions.net/billplzSandboxReturn`});
}
export function bookingPaymentCommandError(error:unknown) {
  return error instanceof BookingQuoteChangedError || error instanceof BookingPaymentMethodUnavailableError ? new HttpsError(error.code,error.message,{reason:error.reason,checkoutCreated:false}) : coachCommandError(error);
}
const store=()=>new FirestoreStore(getFirestore());
export const getBookingPaymentQuoteCommand=onCall({enforceAppCheck:true},async r=>{
  try { configured(r.data, true); return await getBookingPaymentQuote(store(),r.auth,r.data,Date.now,readCoachIdentity); } catch(e) {throw bookingPaymentCommandError(e);}
});
export const createBookingPaymentCommand=onCall({enforceAppCheck:true,secrets:[apiKey,xenditKey]},async r=>{
  try { configured(r.data, true); return await createBookingPayment(store(),r.auth,r.data,prefersXendit(r.data) ? xenditGateway() : gateway(),readCoachIdentity); } catch(e) {throw bookingPaymentCommandError(e);}
});
export const getBookingPaymentMethodsCommand=onCall({enforceAppCheck:true,secrets:[apiKey,xenditKey]},async r=>{
  try {configured(r.data, true);return await getBookingPaymentMethods(store(),r.auth,r.data,prefersXendit(r.data) && r.data?.includeSelectionMethods === true ? xenditGateway() : gateway());}catch(e){throw bookingPaymentCommandError(e);}
});
export const getBookingPaymentCommand=onCall({enforceAppCheck:true,secrets:[apiKey,xenditKey]},async r=>{
  try { configured(r.data, true); return r.data?.includeSelectionMethods===true
    ? await getBookingPaymentMethods(store(),r.auth,r.data,prefersXendit(r.data) ? xenditGateway() : gateway())
    : await readBookingPayment(store(),r.auth,r.data,{ get: id => gateway().get(id) },readCoachIdentity,Date.now,
      { get: id => xenditGateway().get(id) }); } catch(e) {throw bookingPaymentCommandError(e);}
});

export const paymentWebhook=onRequest({secrets:[apiKey,signatureKey,xenditKey,xenditToken]},async(req,res)=>{
  if(req.method!=='POST'){res.set('Allow','POST').status(405).send('POST required');return;}
  if (req.is('application/json')) { await xenditBookingWebhook(req, res); return; }
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
    if (['MembershipPurchase', 'MembershipRenewal'].includes(String(record.kind))) {
      await settleMembershipPayment(store(),organization.value(),row.id,bill,Date.now,readCoachIdentity);
    } else {
      await settleBookingPayment(store(),organization.value(),row.id,bill,readCoachIdentity);
    }
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
export async function xenditBookingWebhook(...[req, res]: Parameters<HttpsFunction>) {
  if (req.method !== 'POST') { res.set('Allow', 'POST').sendStatus(405); return; }
  const expected = Buffer.from(xenditToken.value());
  const received = Buffer.from(req.get('x-callback-token') ?? '');
  if (!expected.length || expected.length !== received.length || !timingSafeEqual(expected, received)) {
    res.sendStatus(401); return;
  }
  if (req.body?.event !== 'payment_session.completed') { res.sendStatus(204); return; }
  const reference = req.body?.data?.reference_id;
  if (typeof reference === 'string' && !/^[a-f0-9]{64}$/.test(reference)) {
    res.sendStatus(204); return; // Other Xendit sessions do not belong to GainPath bookings.
  }
  const id = req.body?.data?.payment_session_id;
  if (typeof id !== 'string' || !/^ps-[a-f0-9]{24}$/.test(id)) { res.sendStatus(204); return; }
  try {
    const org = organization.value();
    const rows = await getFirestore().collection(`orgs/${org}/transactions`).where('billId', '==', id).limit(2).get();
    if (rows.size !== 1 || rows.docs[0].data().provider !== 'xendit') { res.sendStatus(503); return; }
    const payment = await xenditGateway().get(id);
    if (!payment.paid) { res.sendStatus(503); return; }
    await settleBookingPayment(store(), org, rows.docs[0].id, payment, readCoachIdentity);
    res.sendStatus(204);
  } catch { res.sendStatus(503); }
}

export const billplzSandboxReturn=onRequest((_req,res)=>{
  res.set('Cache-Control','no-store').set('Content-Security-Policy',"default-src 'none'; style-src 'unsafe-inline'")
    .status(200).type('html').send('<!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"><title>Return to GainPath</title></head><body style="font-family:system-ui;padding:32px"><h1>Return to GainPath</h1><p>Open GainPath to check your payment. This page does not confirm payment or activation.</p></body></html>');
});
