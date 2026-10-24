const {test}=require('node:test'),assert=require('node:assert/strict');
const {regionalReadSpec,READ_BATCH}=require('./regional-release.cjs');
const fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const {regionalPackageFiles,verifyRegionalPackage}=require('./regional-release.cjs');
const baseline=name=>({name:'projects/gainpath-0619/locations/us-central1/functions/'+name,environment:'GEN_2',state:'ACTIVE',labels:{'deployment-callable':'true'},buildConfig:{runtime:'nodejs22',entryPoint:name,serviceAccount:'projects/879719977530/serviceAccounts/build@example.invalid'},serviceConfig:{service:'old-service',uri:'https://old.example.invalid',revision:'original',allTrafficOnLatestRevision:true,timeoutSeconds:60,availableMemory:'256Mi',maxInstanceRequestConcurrency:80,serviceAccountEmail:'runtime@example.invalid',environmentVariables:{FLAG:'preserve',FUNCTION_TARGET:name,EVENTARC_CLOUD_EVENT_SOURCE:'old-source'}}});
test('same-name regional clone preserves handler, full environment and source input object',()=>{
 for(const name of READ_BATCH){const original=baseline(name),snapshot=structuredClone(original),spec=regionalReadSpec(original,{bucket:'reviewed-upload',object:'reviewed.zip',generation:'1'});
  assert.equal(spec.name,original.name.replace('/us-central1/','/asia-southeast1/'));assert.equal(spec.buildConfig.entryPoint,name);assert.equal(spec.buildConfig.runtime,'nodejs22');assert.equal(spec.serviceConfig.environmentVariables.FLAG,'preserve');assert.equal(spec.serviceConfig.environmentVariables.FUNCTION_TARGET,name);assert(spec.serviceConfig.environmentVariables.EVENTARC_CLOUD_EVENT_SOURCE.includes('/asia-southeast1/'));assert.equal(spec.serviceConfig.serviceAccountEmail,original.serviceConfig.serviceAccountEmail);assert.equal(spec.serviceConfig.timeoutSeconds,60);assert.equal(spec.serviceConfig.maxInstanceRequestConcurrency,80);assert.equal(spec.serviceConfig.maxInstanceCount,20);assert.deepEqual(original,snapshot);
  for(const output of ['service','uri','revision'])assert(!(output in spec.serviceConfig));assert(!('eventTrigger'in spec));assert(!('iam'in spec));
 }
});
test('financial, mutations, schedules, held exports and unknown handlers cannot enter this read deployment',()=>{
 for(const name of ['getBookingPaymentCommand','getMembershipOverviewCommand','getCoachPerformanceCommand','saveCoachRosterCommand','expireBookingHolds','verifiedRewardsCommand','synchronizeGoogleBooking','unknown'])assert.throws(()=>regionalReadSpec(baseline(name),{bucket:'reviewed-upload',object:'reviewed.zip',generation:'1'}));
});
test('reject unexpected identity, event trigger, runtime and secret bindings',()=>{
 for(const change of [m=>m.name=m.name.replace('gainpath-0619','other'),m=>m.name=m.name.replace('us-central1','europe-west1'),m=>m.eventTrigger={eventType:'write'},m=>m.buildConfig.runtime='nodejs18',m=>m.serviceConfig.secretEnvironmentVariables=[{key:'PRIVATE_KEY'}],m=>m.labels={}]){const m=baseline(READ_BATCH[0]);change(m);assert.throws(()=>regionalReadSpec(m,{bucket:'reviewed-upload',object:'reviewed.zip',generation:'1'}));}
});
test('upload seal covers compiled JS, generated entrypoint and dependency inputs',()=>{
 const folder=fs.mkdtempSync(path.join(os.tmpdir(),'gainpath-regional-seal-'));
 for(const sub of ['src','lib'])fs.mkdirSync(path.join(folder,sub));
 for(const file of ['src/index.ts','lib/index.js','package.json','pnpm-lock.yaml','pnpm-workspace.yaml','tsconfig.json'])fs.writeFileSync(path.join(folder,file),'reviewed');
 const sealed=regionalPackageFiles(folder);verifyRegionalPackage(folder,sealed);
 fs.writeFileSync(path.join(folder,'lib/index.js'),'modified handler');assert.throws(()=>verifyRegionalPackage(folder,sealed));
 fs.writeFileSync(path.join(folder,'lib/index.js'),'reviewed');fs.writeFileSync(path.join(folder,'lib/unreviewed.js'),'extra code');assert.throws(()=>verifyRegionalPackage(folder,sealed));
 // Unique small authored fixture is retained in the local temp directory.
});
