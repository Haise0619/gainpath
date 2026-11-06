// Complete source-data demo through isolated real Auth/Functions/Firestore/Storage emulators.
const fs=require('node:fs'),path=require('node:path'),{spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'..'),repository=path.resolve(root,'..'),stage=path.join(repository,'build/module13-firebase-demo/functions');
const project='demo-gainpath-module13-demo';
for(const[name,expected]of Object.entries({FIRESTORE_EMULATOR_HOST:'127.0.0.1:18119',FIREBASE_AUTH_EMULATOR_HOST:'127.0.0.1:19099',FIREBASE_STORAGE_EMULATOR_HOST:'127.0.0.1:19119'}))if(process.env[name]&&process.env[name]!==expected)throw Error('Refusing a foreign emulator binding.');
const downloadable=require('firebase-tools/lib/emulator/downloadableEmulators');for(const name of ['firestore','storage'])if(!fs.existsSync(downloadable.getDownloadDetails(name).downloadPath))throw Error('Existing cached emulator required; no downloads authorized.');
const compile=spawnSync(process.execPath,[require.resolve('typescript/bin/tsc'),'-p','tsconfig.module13-demo.json'],{cwd:root,stdio:'inherit'});if(compile.status!==0)process.exit(compile.status??1);
fs.mkdirSync(stage,{recursive:true});fs.cpSync(path.join(root,'lib-module13-demo'),path.join(stage,'lib'),{recursive:true});fs.copyFileSync(path.join(root,'module13-demo.package.json'),path.join(stage,'package.json'));
const modules=path.join(stage,'node_modules'),target=path.join(root,'node_modules');
if(!fs.existsSync(modules))fs.symlinkSync(target,modules,'junction');
if(fs.realpathSync(modules)!==fs.realpathSync(target))throw Error('Refusing a foreign dependency binding.');
const cache=path.join(repository,'build/module13-firebase-demo/emulator-cli-config');fs.mkdirSync(cache,{recursive:true});
const childEnv={...process.env,CI:'true',FIREBASE_CLI_DISABLE_USAGE:'1',XDG_CONFIG_HOME:cache,GCE_METADATA_HOST:'127.0.0.1:9',GCLOUD_PROJECT:project,GOOGLE_CLOUD_PROJECT:project,MODULE13_DEMO_CLIENT_UI:process.argv.includes('--with-clients')?'1':'0'};
for(const key of ['GOOGLE_APPLICATION_CREDENTIALS','FIREBASE_TOKEN','GEMINI_API_KEY','GOOGLE_API_KEY','GOOGLE_GENERATIVE_AI_API_KEY'])delete childEnv[key];
const java='C:/Program Files/Android/Android Studio/jbr/bin/java.exe';if(process.platform==='win32'){if(!fs.existsSync(java))throw Error('Installed Java required.');const key=Object.keys(childEnv).find(k=>k.toUpperCase()==='PATH')||'PATH';childEnv[key]=path.dirname(java)+path.delimiter+(childEnv[key]||'');}
const firebase=require.resolve('firebase-tools/lib/bin/firebase.js'),vitest=require.resolve('vitest/vitest.mjs');
const result=spawnSync(process.execPath,[firebase,'emulators:exec','--project',project,'--config',path.join(repository,'firebase/module13-demo.emulator.test.json'),'--only','auth,firestore,functions,storage',`"${process.execPath}" "${vitest}" run --config vitest.module13-demo.emulator.config.ts`],{cwd:root,env:childEnv,stdio:'inherit',windowsHide:true});
if(result.error)throw result.error;process.exitCode=result.status??1;
