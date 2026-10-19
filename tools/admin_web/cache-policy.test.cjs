const {test}=require('node:test'),assert=require('node:assert/strict');
const {versionLocalCode}=require('./cache-policy.cjs');
test('current bootstrap and app bypass a legacy Flutter worker cached-code lookup',()=>{
 const hash='a'.repeat(64),out=versionLocalCode('<base href="/"><script src="flutter_bootstrap.js" async></script>','_flutter.buildConfig={"mainJsPath":"main.dart.js"};\n_flutter.loader.load();',hash);
 const bootstrap=out.index.match(/src="([^"]+)"/)[1],app=out.bootstrap.match(/"mainJsPath":"([^"]+)"/)[1];
 // Legacy Flutter workers strip ?v= and serve known asset keys cache-first.
 const cached=new Set(['flutter_bootstrap.js','main.dart.js']);
 for(const request of[bootstrap,app]){assert.equal(cached.has(request.split('?v=')[0]),false);assert.ok(request.endsWith('?build='+hash));}
 assert.ok(out.index.includes('<base href="/">'));assert.ok(out.bootstrap.includes('_flutter.loader.load();'));
});
