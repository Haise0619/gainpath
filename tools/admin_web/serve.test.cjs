const {test}=require('node:test'),assert=require('node:assert/strict'),http=require('node:http');
const {handler}=require('./serve.cjs');
test('old module and commit entries redirect to the same main Admin',async()=>{
 const server=http.createServer(handler);await new Promise(r=>server.listen(0,'127.0.0.1',r));
 try {const origin='http://127.0.0.1:'+server.address().port;
  for(const entry of ['/builds/module8/','/builds/7df26ea/']){const r=await fetch(origin+entry,{redirect:'manual'});assert.equal(r.status,302);assert.equal(r.headers.get('location'),'/');assert.equal(r.headers.get('cache-control'),'no-store');}
  assert.equal((await fetch(origin+'/',{method:'POST'})).status,405);
  assert.equal((await fetch(origin+'/private/fixture.json')).status,404);
 }finally{await new Promise(r=>server.close(r));}
});
