// Build/activate the ordinary Admin at its existing private7359 mechanism.
const fs=require('node:fs'),path=require('node:path'),{spawn}=require('node:child_process'),assert=require('node:assert/strict'),p=require('./unified-admin-platform.cjs');
const mode=process.argv[2],web=p.out+'/admin-web',current=p.root+'/build/admin-web/current';
if(process.argv.length!==3||!['build','activate','rollback'].includes(mode))throw Error('Fixed Admin build, activation or rollback only.');
function record(f,x){fs.writeFileSync(p.out+'/'+f,JSON.stringify(x,null,2)+'\n');}
function inventory(dir){return require('./unified-admin-release.cjs').inventory(dir);}
if(mode==='build'){
 const definesFile=p.root+'/build/local-run/admin.firebase.json',defines=JSON.parse(fs.readFileSync(definesFile,'utf8')),registered=p.read('build/non-core-crud-sprint/module-8-activation/private/admin-web-app-check.json');
 assert(registered.registered===true&&defines.APP_CHECK_MODE==='debug'&&defines.APP_CHECK_WEB_DEBUG_TOKEN===registered.token);
 if(!fs.existsSync(p.out+'/admin-before')){fs.cpSync(current,p.out+'/admin-before',{recursive:true});record('admin-before-inventory.json',inventory(current));}
 if(fs.existsSync(p.out+'/admin-activated.json')){
  const prior=p.read('build/unified-admin-20261104/admin-build-result.json'),active=p.read('build/unified-admin-20261104/admin-activated.json');assert.equal(prior.sha256,active.sha256);
  for(const[file,h]of Object.entries(prior.files))assert.equal(p.hash(fs.readFileSync(current+'/'+file)),h,'Preserve concurrent Admin changes');
  const second=fs.existsSync(p.out+'/admin-before-followup'),backup=second?'admin-before-followup-2':'admin-before-followup',version=second?'v2':'v1';assert(!fs.existsSync(p.out+'/'+backup),'The bounded follow-up backup already exists; inspect before another build');
  fs.cpSync(current,p.out+'/'+backup,{recursive:true});fs.cpSync(web,p.out+'/admin-web-'+version,{recursive:true});record(backup+'-inventory.json',inventory(current));record('admin-build-result-'+version+'.json',prior);record('admin-activated-'+version+'.json',active);
 }
 const log=fs.createWriteStream(p.out+'/admin-build-output.txt'),flutter=process.env.FLUTTER_ROOT||'C:/flutter';
 const child=spawn(flutter+'/bin/cache/dart-sdk/bin/dart.exe',[flutter+'/bin/cache/flutter_tools.snapshot','build','web','--release','--no-pub','--base-href=/','--output='+web,'--dart-define-from-file='+definesFile,...require(p.root+'/tools/admin_web/regional-options.cjs').regionalBuildDefines(process.env)],{cwd:p.root+'/apps/admin_web',windowsHide:true,stdio:['ignore','pipe','pipe']});
 for(const stream of [child.stdout,child.stderr])stream.on('data',x=>log.write(String(x).split(registered.token).join('[REDACTED]')));
 child.once('error',()=>{console.error('Ordinary Admin build could not start.');process.exitCode=1;});
 child.once('close',code=>{log.end();process.exitCode=code??1;if(code===0){const bootstrap=web+'/flutter_bootstrap.js',index=web+'/index.html',body=fs.readFileSync(bootstrap,'utf8').replace(/_flutter\.loader\.load\(\{\s*serviceWorkerSettings:\s*\{\s*serviceWorkerVersion:\s*"[0-9]+"\s*\}\s*\}\);/,'_flutter.loader.load();'),hash=p.hash(fs.readFileSync(web+'/main.dart.js')),versioned=require(p.root+'/tools/admin_web/cache-policy.cjs').versionLocalCode(fs.readFileSync(index,'utf8'),body,hash);fs.writeFileSync(index,versioned.index);fs.writeFileSync(bootstrap,versioned.bootstrap);record('admin-build-result.json',{at:new Date().toISOString(),ordinaryMain:true,projectId:p.project,url:'http://localhost:7359/',sha256:hash,privateOnly:true,files:inventory(web)});}console.log(JSON.stringify({ordinaryAdminBuildPassed:code===0,liveActivation:false}));});
}else if(mode==='rollback'){
 const previous=p.out+'/admin-before',expected=p.read('build/unified-admin-20261104/admin-before-inventory.json');assert.deepEqual(inventory(previous),expected);
 const active=p.read('build/unified-admin-20261104/admin-build-result.json');
 assert.equal(path.resolve(current),path.resolve(p.root,'build/admin-web/current'));assert(!fs.lstatSync(current).isSymbolicLink());
 require('./unified-admin-web-files.cjs').restore(current,previous,active.files);
 record('admin-rollback.json',{at:new Date().toISOString(),previousBundleRestored:true,noDeletion:true});console.log('Previous ordinary Admin bundle restored without deleting either build.');
}else{
 (async()=>{const proof=p.read('build/unified-admin-20261104/live-verification.json');assert(proof.passed);const build=p.read('build/unified-admin-20261104/admin-build-result.json');assert.deepEqual(inventory(web),build.files);const baseline=['admin-before-followup-2-inventory.json','admin-before-followup-inventory.json','admin-before-inventory.json'].find(f=>fs.existsSync(p.out+'/'+f));assert.deepEqual(inventory(current),p.read('build/unified-admin-20261104/'+baseline),'Current Admin changed; preserve concurrent work');
  const resolved=path.resolve(current);assert.equal(resolved,path.resolve(p.root,'build/admin-web/current'));assert(!fs.lstatSync(current).isSymbolicLink());
  // Assets first; entrypoint last. No deletion or replacement of sibling builds.
  for(const file of Object.keys(build.files).filter(f=>!['index.html','flutter_bootstrap.js'].includes(f))){const target=path.join(current,file);assert(target.startsWith(resolved+path.sep));fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(path.join(web,file),target);}
  for(const file of ['flutter_bootstrap.js','index.html'])fs.copyFileSync(web+'/'+file,current+'/'+file);
  for(const[file,hash]of Object.entries(build.files))assert.equal(p.hash(fs.readFileSync(current+'/'+file)),hash);
  const r=await fetch('http://localhost:7359/main.dart.js',{signal:AbortSignal.timeout(15000)});assert(r.ok);assert.equal(p.hash(Buffer.from(await r.arrayBuffer())),build.sha256);record('admin-activated.json',{at:new Date().toISOString(),url:build.url,sha256:build.sha256,servedVerified:true,previousBundlePreserved:true});console.log(JSON.stringify({ordinaryAdminActivated:true,url:build.url,servedHashVerified:true}));
 })().catch(()=>{console.error('Ordinary Admin activation stopped. Preserve current/previous bundles and inspect exact inventories.');process.exitCode=1;});
}
