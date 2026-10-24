const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
// Deliberately bounded. Financial commands, mixed read/write handlers and
// background workers require their own reviewed cutover packages.
const READ_BATCH=Object.freeze(['getCoachCertificationsCommand','getCoachAccountSettingsCommand','getCoachPublishedPhotoCommand','getCoachRosterCommand','getMemberBookingOptionsCommand']);
function regionalReadSpec(original,storageSource){
 const id=original.name?.split('/').at(-1);
 assert(READ_BATCH.includes(id),'Handler is outside the non-financial read batch');
 assert.equal(original.name,'projects/gainpath-0619/locations/us-central1/functions/'+id);
 assert.equal(original.environment,'GEN_2');assert.equal(original.state,'ACTIVE');
 assert.equal(original.buildConfig.runtime,'nodejs22');assert.equal(original.buildConfig.entryPoint,id);
 assert.equal(original.labels?.['deployment-callable'],'true');assert(!original.eventTrigger);
 assert(!original.serviceConfig.secretEnvironmentVariables?.length&&!original.serviceConfig.secretVolumes?.length,'Secret-backed handlers need separate approval');
 assert(storageSource&&typeof storageSource.bucket==='string'&&typeof storageSource.object==='string','Reviewed uploaded source required');
 const serviceConfig=structuredClone(original.serviceConfig);
 for(const key of ['service','uri','revision','gcfUri'])delete serviceConfig[key];
 serviceConfig.environmentVariables={...serviceConfig.environmentVariables,EVENTARC_CLOUD_EVENT_SOURCE:'projects/gainpath-0619/locations/asia-southeast1/services/'+id};
 // New replacements have a bounded staging capacity; original US capacity is untouched.
 serviceConfig.maxInstanceCount=original.serviceConfig.maxInstanceCount??20;
 const buildConfig={runtime:original.buildConfig.runtime,entryPoint:id,source:{storageSource:structuredClone(storageSource)},dockerRepository:'projects/gainpath-0619/locations/asia-southeast1/repositories/gcf-artifacts',environmentVariables:{...original.buildConfig.environmentVariables,GOOGLE_NODE_RUN_SCRIPTS:''}};
 if(original.buildConfig.serviceAccount)buildConfig.serviceAccount=original.buildConfig.serviceAccount;
 return {name:'projects/gainpath-0619/locations/asia-southeast1/functions/'+id,environment:'GEN_2',buildConfig,serviceConfig,labels:{'deployment-callable':'true','deployment-tool':'gainpath-isolated-region-copy'}};
}
function regionalPackageFiles(folder){
 const files=[];
 const add=relative=>{
  const absolute=path.resolve(folder,relative);
  assert(absolute.startsWith(path.resolve(folder)+path.sep),'Package path escapes release');
  const stat=fs.lstatSync(absolute);assert(!stat.isSymbolicLink(),'Symlinks cannot enter reviewed upload');
  if(stat.isDirectory()){for(const name of fs.readdirSync(absolute).sort())add(relative+'/'+name);}
  else files.push({path:relative,sha256:crypto.createHash('sha256').update(fs.readFileSync(absolute)).digest('hex')});
 };
 for(const name of ['src','lib','package.json','pnpm-lock.yaml','pnpm-workspace.yaml','tsconfig.json'])add(name);
 return files.sort((a,b)=>a.path.localeCompare(b.path));
}
function verifyRegionalPackage(folder,reviewedFiles){
 assert(Array.isArray(reviewedFiles)&&reviewedFiles.some(f=>f.path==='lib/index.js')&&reviewedFiles.some(f=>f.path==='src/index.ts'),'Complete reviewed artifact seal required');
 assert.deepEqual(regionalPackageFiles(folder),reviewedFiles,'Regional upload differs from reviewed complete artifact');
}
module.exports={READ_BATCH,regionalReadSpec,regionalPackageFiles,verifyRegionalPackage};
