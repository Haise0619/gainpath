#!/usr/bin/env node
// Explicit emulator-only seed CLI. No live apply or credential generation route.
const fs=require('node:fs'),path=require('node:path'),{createRequire}=require('node:module');
const root=path.resolve(__dirname,'..'),req=createRequire(path.join(root,'package.json'));
const args=process.argv.slice(2),commands=['--dry-run','--apply','--validate','--cleanup-dry-run'];
if(args.includes('--live-plan'))throw Error('The named-database live plan is superseded. No live execution or approval applies to it. Use the unified default-database audit and replacement preflight.');
const command=commands.find(v=>args.includes(v));
const livePlan=args.includes('--live-plan');
if(!command||commands.filter(v=>args.includes(v)).length!==1||livePlan===args.includes('--emulator')||livePlan&&command!=='--dry-run')throw Error('Choose --emulator or offline --live-plan --dry-run. Live apply is not authorized.');
if(args.some((a,i)=>!['--emulator','--live-plan',...commands,'--clock','--output'].includes(a)&&args[i-1]!=='--clock'&&args[i-1]!=='--output'))throw Error('Unknown seed option.');
const arg=name=>{const i=args.indexOf(name);return i<0?null:args[i+1];};
const {buildModule13DemoDataset}=req('./lib-module13-demo/modules/recommendation/demo-dataset.js');
const seed=req('./lib-module13-demo/modules/recommendation/demo-seed.js');
(async()=>{
 const time=arg('--clock'),now=time?Number(time):Date.now();if(!Number.isSafeInteger(now)||now<0)throw Error('Use an explicit integer clock in milliseconds.');
 const d=await buildModule13DemoDataset({nowMillis:now,...(livePlan?{projectId:'gainpath-0619',storageBucket:'gainpath-0619-module13-demo-credentials'}:{})});let result;
 if(command==='--dry-run')result=seed.describeModule13DemoSeed(d);
 else{
  for(const[key,value]of Object.entries({GCLOUD_PROJECT:'demo-gainpath-module13-demo',GOOGLE_CLOUD_PROJECT:'demo-gainpath-module13-demo',FIREBASE_AUTH_EMULATOR_HOST:'127.0.0.1:19099',FIRESTORE_EMULATOR_HOST:'127.0.0.1:18119',FIREBASE_STORAGE_EMULATOR_HOST:'127.0.0.1:19119',STORAGE_EMULATOR_HOST:'http://127.0.0.1:19119'})){if(process.env[key]&&process.env[key]!==value)throw Error('Foreign emulator binding refused.');process.env[key]=value;}
  const {initializeApp,deleteApp}=req('firebase-admin/app'),{getFirestore}=req('firebase-admin/firestore'),{getAuth}=req('firebase-admin/auth'),{getStorage}=req('firebase-admin/storage');
  const app=initializeApp({projectId:'demo-gainpath-module13-demo'},'module13-seed-cli'),firestore=getFirestore(app,'module13-demo');
  try{const options={dataset:d,firestore,auth:getAuth(app),bucket:getStorage(app).bucket(d.storageBucket)};
   seed.guardModule13DemoSeed(options);
   if(command==='--apply'){const response=await fetch('http://127.0.0.1:18119/emulator/v1/projects/demo-gainpath-module13-demo/databases/module13-demo:securityRules',{method:'PUT',headers:{'Content-Type':'application/json'},body:JSON.stringify({rules:{files:[{name:'demo.rules',content:fs.readFileSync(path.join(root,'../firebase/module13-demo.firestore.rules'),'utf8')}]}})});if(!response.ok)throw Error('Named-database emulator Rules installation failed.');}
   result=command==='--apply'?await seed.applyModule13DemoSeed(options):command==='--validate'?await seed.validateModule13DemoSeed(options):await seed.cleanupModule13DemoSeedDryRun(options);
   if(command==='--apply')result={manifest:result.manifest,validation:result.validation,createdAuthThisRun:result.createdAuthThisRun};
  }finally{await firestore.terminate();await deleteApp(app);}
 }
 const output=arg('--output');if(output){const target=path.resolve(output),allowed=path.resolve(root,'../build/module13-firebase-demo');if(!target.startsWith(allowed+path.sep)||fs.existsSync(target))throw Error('Use a new output file under build/module13-firebase-demo.');fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,JSON.stringify(result,null,2));}
 console.log(JSON.stringify({command,environment:livePlan?'offline_live_approval_plan':'emulator_only',clockMillis:now,output:output??null,summary:result.integrity??result.validation??{valid:result.valid??null,authAccounts:result.authAccounts??null,firestoreDocuments:result.firestoreDocuments??null,storageObjects:result.storageObjects??null,dryRun:result.dryRun??null}},null,2));
})().catch(()=>{console.error('Module13 seed operation refused or failed; no live fallback exists.');process.exitCode=1;});
