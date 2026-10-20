// Rebuild the existing Admin application. Never registers credentials or deploys Firebase.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{spawn}=require('node:child_process');
const {versionLocalCode}=require('./cache-policy.cjs');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'build/admin-web/current');
(async()=>{
 const fixturePath=process.env.GAINPATH_ADMIN_APP_CHECK_FIXTURE||path.join(root,'build/non-core-crud-sprint/module-8-activation/private/admin-web-app-check.json');
 const fixture=JSON.parse(fs.readFileSync(fixturePath,'utf8'));
 if(!fixture.registered||typeof fixture.token!=='string'||!fixture.token)throw Error('Existing approved local App Check fixture required');
 fs.mkdirSync(path.join(root,'build/admin-web'),{recursive:true});
 const log=fs.createWriteStream(path.join(root,'build/admin-web/build.log'));
 const flutter=process.env.FLUTTER_ROOT||'C:/flutter';
 const args=[path.join(flutter,'bin/cache/flutter_tools.snapshot'),'build','web','--release','--no-pub','--base-href=/','--output='+out,'--dart-define=BACKEND=firebase','--dart-define=APP_CHECK_MODE=debug','--dart-define=APP_CHECK_WEB_DEBUG_TOKEN='+fixture.token];
 const child=spawn(path.join(flutter,'bin/cache/dart-sdk/bin/dart.exe'),args,{cwd:path.join(root,'apps/admin_web'),windowsHide:true,stdio:['ignore','pipe','pipe']});
 const redact=data=>log.write(data.toString().split(fixture.token).join('[REDACTED]'));
 child.stdout.on('data',redact);child.stderr.on('data',redact);
 const code=await new Promise((resolve,reject)=>{child.on('error',reject);child.on('close',resolve);});
 await new Promise(resolve=>log.end(resolve));if(code!==0)throw Error('Admin build failed; see sanitized build/admin-web/build.log');
 const file=path.join(out,'flutter_bootstrap.js'),bootstrap=fs.readFileSync(file,'utf8');
 fs.writeFileSync(file,bootstrap.replace(/_flutter\.loader\.load\(\{\s*serviceWorkerSettings:\s*\{\s*serviceWorkerVersion:\s*"[0-9]+"\s*\}\s*\}\);/,'_flutter.loader.load();'));
 const hash=crypto.createHash('sha256').update(fs.readFileSync(path.join(out,'main.dart.js'))).digest('hex');
 const indexPath=path.join(out,'index.html'),versioned=versionLocalCode(fs.readFileSync(indexPath,'utf8'),fs.readFileSync(file,'utf8'),hash);
 fs.writeFileSync(indexPath,versioned.index);fs.writeFileSync(file,versioned.bootstrap);
 const result={url:'http://localhost:7359/',backend:'firebase',project:'gainpath-0619',baseHref:'/',sha256:hash};
 fs.writeFileSync(path.join(root,'build/admin-web/build-result.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));
})().catch(e=>{console.error(e.message?.includes('Admin build failed')?e.message:'Main Admin build failed; verify existing private build inputs.');process.exitCode=1;});
