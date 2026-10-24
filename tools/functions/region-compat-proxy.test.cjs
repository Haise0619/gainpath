const {test} = require('node:test');
const assert = require('node:assert/strict');
const {httpForwarder, eventForwarder} = require('./region-compat-proxy.cjs');
const target = 'https://asia-southeast1-gainpath-0619.cloudfunctions.net/paymentWebhook';
function response() {
  return {headers: {}, set(k,v) {this.headers[k] = v; return this;}, status(n) {this.code = n; return this;}, send(b) {this.body = b; return this;}};
}
test('signed callback preserves raw bytes, query and provider status with one attempt', async () => {
  const rawBody = Buffer.from('paid=true&x_signature=a%2Bb'); let calls = 0;
  const forward = httpForwarder(target, async (url, opts) => {
    calls++; assert.equal(url, target + '/?attempt=one%2Btwo');
    assert.equal(opts.body, rawBody); assert.equal(opts.headers['x-signature'], 'unchanged');
    assert.equal(opts.headers.host, undefined); assert.equal(opts.redirect, 'manual');
    return new Response('rejected', {status: 403, headers: {'content-type':'text/plain', 'content-encoding':'gzip'}});
  });
  const res = response(); await forward({method:'POST', originalUrl:'/?attempt=one%2Btwo', rawBody, headers:{host:'old', 'x-signature':'unchanged'}}, res);
  assert.equal(calls, 1); assert.equal(res.code, 403); assert.equal(res.body.toString(), 'rejected');
  assert.equal(res.headers['content-encoding'], undefined);
});
test('uncertain callback returns unavailable without an automatic second request', async () => {
  let calls = 0; const res = response();
  await httpForwarder(target, async () => {calls++; throw Error('timeout');})({method:'POST', rawBody:Buffer.from('x'), headers:{}}, res);
  assert.equal(calls,1); assert.equal(res.code,503);
});
test('missing raw financial payload fails closed before network access', async () => {
  let calls = 0; const res = response();
  await httpForwarder(target, async () => {calls++;})({method:'POST', body:{paid:true}, headers:{}}, res);
  assert.equal(calls,0); assert.equal(res.code,503);
});
test('OAuth redirect and return response headers are preserved', async () => {
  const res = response(); await httpForwarder(target, async (_url, opts) => {
    assert.equal(opts.body, undefined); return new Response(null,{status:302,headers:{location:'https://example.invalid/done','cache-control':'no-store'}});
  })({method:'GET', originalUrl:'/?state=opaque', headers:{}},res);
  assert.equal(res.code,302); assert.equal(res.headers.location,'https://example.invalid/done'); assert.equal(res.headers['cache-control'],'no-store');
});
test('untrusted targets are rejected', () => {
  assert.throws(() => httpForwarder('https://example.invalid'));
  assert.throws(() => eventForwarder('http://metadata.google.internal'));
});
test('one CloudEvent is forwarded as unchanged protobuf with scoped identity', async () => {
  const data = Buffer.from([10,1,3]); let sent = 0;
  const forward = eventForwarder('https://synchronizegooglebooking-example-as.a.run.app', async () => 'runtime-id-token', async (url, opts) => {
    sent++; assert.equal(opts.headers.authorization,'Bearer runtime-id-token');
    assert.equal(opts.headers['ce-id'],'stable-id'); assert.equal(opts.headers['ce-document'],'orgs/gainpath/bookings/example');
    assert.equal(opts.headers['content-type'],'application/protobuf'); assert.equal(opts.body,data);
    return new Response(null,{status:204});
  });
  await forward({id:'stable-id',source:'//firestore.googleapis.com/projects/gainpath-0619',type:'google.cloud.firestore.document.v1.updated',specversion:'1.0',document:'orgs/gainpath/bookings/example',datacontenttype:'application/protobuf',data});
  assert.equal(sent,1);
});
test('worker failure is thrown to the existing Eventarc retry policy', async () => {
  let sent = 0; const forward = eventForwarder('https://synchronizegooglebooking-example-as.a.run.app',async () => 'token',async () => {sent++; return new Response(null,{status:503});});
  await assert.rejects(forward({id:'same',source:'source',type:'type',specversion:'1.0',data:Buffer.from([1])}));
  assert.equal(sent,1);
});
test('Functions Framework receives forwarded protobuf and document attributes intact', async () => {
  const path = require('node:path');
  const {getServer} = require(path.resolve(__dirname,'../../functions/node_modules/@google-cloud/functions-framework/build/src/server.js'));
  const bytes = Buffer.from([10,0,18,0]); let seen;
  const server = getServer(async event => {seen = event;}, {signatureType:'cloudevent', timeoutMilliseconds:5000, ignoredRoutes:''});
  await new Promise(resolve => server.listen(0,'127.0.0.1',resolve));
  try {
    const local = 'http://127.0.0.1:' + server.address().port;
    await eventForwarder('https://synchronizegooglebooking-example-as.a.run.app',async () => 'token',(_url,opts) => fetch(local,opts))({id:'event-1',source:'source',type:'google.cloud.firestore.document.v1.updated',specversion:'1.0',document:'orgs/gainpath/bookings/example',data:bytes});
    assert.equal(seen.id,'event-1'); assert.equal(seen.document,'orgs/gainpath/bookings/example');
    assert(Buffer.isBuffer(seen.data)); assert(seen.data.equals(bytes));
  } finally {await new Promise(resolve => server.close(resolve));}
});
