// Exact, fixed-project operator. No deletion, arbitrary project, force or provider modes.
const fs=require('node:fs'),path=require('node:path');
const p=require('./fyp-live-platform.cjs');
const modes=new Set(['prepare-vault','dry-run','apply','validate','activate','disable','recover','cleanup-dry-run']);
async function infrastructure(c){
 const proof=JSON.parse(fs.readFileSync(path.join(p.out,'infrastructure-verified.json'),'utf8'));
 const names=['fypDatasetSessionCommand','fypDatasetCommand','provisionMemberRegistration'],exactKeys=v=>v&&typeof v==='object'&&!Array.isArray(v)&&Object.keys(v).sort().join(',')===[...names].sort().join(',')&&Object.values(v).every(x=>typeof x==='string'&&/^[a-f0-9]{64}$/.test(x));
 if(proof.schemaVersion!==1||proof.projectId!==p.project||proof.databaseId!=='(default)'||proof.passed!==true||proof.functionNames?.join(',')!==names.join(',')||!exactKeys(proof.currentFunctionDigests)||!exactKeys(proof.currentIamDigests)||!Number.isFinite(Date.parse(proof.at))||Date.now()-Date.parse(proof.at)>1800000||Date.parse(proof.at)>Date.now()+5000)throw Error('Fresh complete exact infrastructure proof required.');
 const review=JSON.parse(fs.readFileSync(path.join(p.out,'package-review.json'),'utf8'));if(review.passed!==true||p.hash(review)!==proof.packageReviewSha256||proof.rulesSha256!==review.rulesSha256)throw Error('Infrastructure package binding changed.');
 for(const name of names){const digest=proof.currentFunctionDigests[name],current=await c.request('GET',`https://cloudfunctions.googleapis.com/v2/projects/${p.project}/locations/asia-southeast1/functions/${name}`);if(current.state!=='ACTIVE'||p.hash(current)!==digest)throw Error('Deployed Function changed after verification.');const iam=await c.request('GET',`https://run.googleapis.com/v1/${current.serviceConfig.service}:getIamPolicy`);if(p.hash(iam)!==proof.currentIamDigests[name])throw Error('Function IAM changed after verification.');}
 const release=await c.request('GET',`https://firebaserules.googleapis.com/v1/projects/${p.project}/releases/cloud.firestore`);if(release.rulesetName!==proof.rulesetName)throw Error('Deployed Rules changed after verification.');
 const a=await p.appCheck(c);if(!a.appId)throw Error('Real App Check verification required.');
}
async function main(){
 const mode=process.argv[2];if(process.argv.length!==3||!modes.has(mode)||!process.version.startsWith('v22.'))throw Error('Use Node22 and exactly one documented FYP operator mode.');
 const modules=path.join(p.out,'compiled/node_modules'),dependencies=path.join(p.root,'functions/node_modules');
 if(!fs.existsSync(modules))fs.symlinkSync(dependencies,modules,'junction');
 if(fs.realpathSync(modules)!==fs.realpathSync(dependencies))throw Error('Existing exact operator dependencies required.');
 const m=await require(path.join(p.out,'compiled/modules/dataset/fyp-live-manifest.js')).loadFypLiveManifest(fs.readFileSync(path.join(p.root,'docs/integration/gainpath-fyp-cohort-preflight.json'),'utf8'),fs.readFileSync(path.join(p.root,'build/fyp-cohort-integration/proposed-source-records.json'),'utf8'));
 if(mode!=='disable')p.checkSource();const vault=require('./fyp-live-vault.cjs').openVault(m.dataset.identities,{create:mode==='prepare-vault'});
 if(mode==='prepare-vault'){console.log(JSON.stringify({mode,encrypted:true,provider:'Windows CurrentUser DPAPI',credentialLocation:vault.location,entries:27,passwordsLogged:false,cloudWrites:0}));return;}
 const c=await p.connect({quarantineOnly:mode==='disable'});try{
  const operator=require(path.join(p.out,'compiled/modules/dataset/fyp-live-executor.js')).createFypLiveExecutor({firestore:c.db,auth:c.auth,manifest:m,vault,audit:async event=>fs.appendFileSync(path.join(p.out,'executor-audit.jsonl'),JSON.stringify(event)+'\n'),activationCheck:()=>infrastructure(c)});
  if(mode==='apply')await infrastructure(c);
  const action={'dry-run':'dryRun','cleanup-dry-run':'cleanupDryRun'}[mode]??mode;
  const result=await operator[action]();const record={at:new Date().toISOString(),mode,projectId:p.project,databaseId:'(default)',manifestSha256:m.manifestSha256,result};
  fs.writeFileSync(path.join(p.out,`executor-${mode}-${Date.now()}.json`),JSON.stringify(record,null,2)+'\n');
  console.log(JSON.stringify(mode==='cleanup-dry-run'?{mode,dryRun:true,willDelete:false,ownedFirestoreRecords:result.firestorePaths.length,authBindings:result.authBindings.length,preservedCount:result.preserved.length}:record));
 }finally{await c.close();}
}
if(require.main===module)main().catch(()=>{console.error(JSON.stringify({status:'fyp_operator_stopped',message:'Fixed-scope operation failed. Inspect audit and preserved resource evidence; no credentials or provider errors logged.'}));process.exitCode=1;});
module.exports={infrastructure};
