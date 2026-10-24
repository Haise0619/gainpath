const assert = require('node:assert/strict');
const excluded = new Set(['host','connection','content-length','transfer-encoding','keep-alive','proxy-authenticate','proxy-authorization','te','trailer','upgrade']);
function destination(value) {
  const url = new URL(value);
  assert.equal(url.protocol,'https:'); assert(!url.username && !url.password && !url.port && !url.search && !url.hash);
  assert(url.hostname === 'asia-southeast1-gainpath-0619.cloudfunctions.net' || /^synchronizegooglebooking-[a-z0-9-]+\.a\.run\.app$/.test(url.hostname), 'Only fixed Singapore release destinations are allowed');
  return url;
}
/** Compatibility transport only: never interprets or settles financial payloads. */
function httpForwarder(target, send = fetch) {
  const fixed = destination(target).href.replace(/\/$/,'');
  return async (req,res) => {
    try {
      const method = req.method, hasBody = method !== 'GET' && method !== 'HEAD';
      if (hasBody && !Buffer.isBuffer(req.rawBody)) throw Error('Raw payload unavailable');
      const incoming = new URL(req.originalUrl || '/', 'https://compat.invalid');
      const headers = {};
      const blocked = new Set([...excluded, ...String(req.headers.connection || '').toLowerCase().split(',').map(s => s.trim())]);
      for (const [name,value] of Object.entries(req.headers)) if (!blocked.has(name.toLowerCase()) && value !== undefined) headers[name] = value;
      const response = await send(fixed + incoming.pathname + incoming.search, {method,headers,
        ...(hasBody ? {body:req.rawBody} : {}),redirect:'manual',signal:AbortSignal.timeout(55000)});
      const bytes = Buffer.from(await response.arrayBuffer());
      for (const [name,value] of response.headers) if (!excluded.has(name) && name !== 'content-encoding') res.set(name,value);
      res.status(response.status).send(bytes);
    } catch {
      // One request only. A timeout can follow successful settlement: reconciliation
      // and provider retries must reach the unchanged idempotent Singapore handler.
      res.set('content-type','application/json').set('cache-control','no-store').status(503).send('{"accepted":false,"code":"unavailable"}');
    }
  };
}
async function runtimeIdentity(audience) {
  const response = await fetch('http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity?format=full&audience=' + encodeURIComponent(audience), {
    headers:{'Metadata-Flavor':'Google'},signal:AbortSignal.timeout(5000)});
  if (!response.ok) throw Error('Runtime identity unavailable');
  return response.text();
}
/** Reuses the sole existing Eventarc trigger and its retry/queue ownership. */
function eventForwarder(target, identity = runtimeIdentity, send = fetch) {
  const fixed = destination(target).href.replace(/\/$/,'');
  return async event => {
    for (const key of ['id','source','type','specversion']) assert.equal(typeof event[key],'string');
    const binary = Buffer.isBuffer(event.data) || event.data instanceof Uint8Array;
    const headers = {'content-type':binary ? 'application/protobuf' : 'application/json', authorization:'Bearer ' + await identity(fixed)};
    for (const [key,value] of Object.entries(event)) if (key !== 'data' && typeof value === 'string') headers['ce-' + key] = value;
    const response = await send(fixed,{method:'POST',headers,body:binary ? event.data : JSON.stringify(event.data),redirect:'manual',signal:AbortSignal.timeout(110000)});
    if (!response.ok) throw Error('Singapore delivery unavailable; retain original event retry');
  };
}
module.exports = {httpForwarder,eventForwarder};
