// Ordinary private main Admin bundle; no cloud or user-data writes.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto'),{spawn}=require('node:child_process');
const root=path.resolve(__dirname,'../..'),out=root+'/build/floor-push-up-main-20261106';
const {inventory}=require('../../functions/tools/unified-admin-web-files.cjs');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const current=root+'/build/admin-web/current',web=out+'/admin-web';
const read=n=>JSON.parse(fs.readFileSync(out+'/'+n,'utf8')),write=(n,v)=>fs.writeFileSync(out+'/'+n,JSON.stringify(v,null,2)+'\n');
function sources(){const r={};for(const dir of ['apps/admin_web/lib','packages/gainpath_domain/lib','packages/gainpath_data/lib','packages/gainpath_ui/lib'])for(const[p,h]of Object.entries(inventory(root+'/'+dir)))r[dir+'/'+p]=h;return r;}
async function run(mode){
 if(mode==='build'){
  assert(!fs.existsSync(out+'/admin-before'),'Preserve the existing build baseline');fs.cpSync(current,out+'/admin-before',{recursive:true});write('admin-before-inventory.json',inventory(current));
  const config=root+'/build/local-run/admin.firebase.json',defines=JSON.parse(fs.readFileSync(config)),registered=JSON.parse(fs.readFileSync(root+'/build/non-core-crud-sprint/module-8-activation/private/admin-web-app-check.json'));assert(registered.registered&&defines.APP_CHECK_WEB_DEBUG_TOKEN===registered.token,'Preserve existing registered private App Check transport');
  const before=sources(),log=fs.createWriteStream(out+'/admin-build.log');
  const child=spawn('C:/flutter/bin/cache/dart-sdk/bin/dart.exe',['C:/flutter/bin/cache/flutter_tools.snapshot','build','web','--release','--no-pub','--base-href=/','--output='+web,'--dart-define-from-file='+config,...require('./regional-options.cjs').regionalBuildDefines(process.env)],{cwd:root+'/apps/admin_web',windowsHide:true,stdio:['ignore','pipe','pipe']});
  for(const s of [child.stdout,child.stderr])s.on('data',b=>log.write(String(b).split(registered.token).join('[REDACTED]')));const exit=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('close',resolve);});log.end();assert.equal(exit,0,'Admin build failed; inspect local log');assert.deepEqual(sources(),before,'Source changed during build');
  const mainSha=hash(fs.readFileSync(web+'/main.dart.js')),bootstrap=fs.readFileSync(web+'/flutter_bootstrap.js','utf8').replace(/_flutter\.loader\.load\(\{\s*serviceWorkerSettings:\s*\{\s*serviceWorkerVersion:\s*"[0-9]+"\s*\}\s*\}\);/,'_flutter.loader.load();');
  const versioned=require('./cache-policy.cjs').versionLocalCode(fs.readFileSync(web+'/index.html','utf8'),bootstrap,mainSha);fs.writeFileSync(web+'/index.html',versioned.index);fs.writeFileSync(web+'/flutter_bootstrap.js',versioned.bootstrap);write('admin-build.json',{passed:true,ordinaryMain:true,sources:before,files:inventory(web),mainSha});console.log('Ordinary main Admin bundle built; previous client preserved.');return;
 }
 if(mode==='activate'){
  require('../workouts/floor-main-release.cjs').seal();assert(read('live-verification.json').passed);
  const b=read('admin-build.json');assert(b.passed&&b.ordinaryMain);assert.deepEqual(sources(),b.sources);assert.deepEqual(inventory(web),b.files);assert.deepEqual(inventory(current),read('admin-before-inventory.json'));
  const resolved=path.resolve(current);assert.equal(resolved,path.resolve(root,'build/admin-web/current'));assert(!fs.lstatSync(current).isSymbolicLink());
  for(const p of [...Object.keys(b.files).filter(p=>!['index.html','flutter_bootstrap.js'].includes(p)),'flutter_bootstrap.js','index.html']){const target=path.resolve(current,p);assert(target.startsWith(resolved+path.sep));fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(web+'/'+p,target);}
  for(const[p,h]of Object.entries(b.files))assert.equal(hash(fs.readFileSync(current+'/'+p)),h);
  const r=await fetch('http://localhost:7359/main.dart.js',{signal:AbortSignal.timeout(15000)});assert(r.ok);assert.equal(hash(Buffer.from(await r.arrayBuffer())),b.mainSha);
  write('admin-activated.json',{passed:true,url:'http://localhost:7359/',sha256:b.mainSha,ordinaryMain:true,previousBundlePreserved:true});console.log('Ordinary Admin activated at7359; served hash verified.');return;
 }
 throw Error('Fixed build/activate mode required');
}
run(process.argv[2]).catch(e=>{console.error(e.message);process.exitCode=1;});
