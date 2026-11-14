// Explicit owner approval: reset these two existing, verified FYP accounts only.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{spawnSync}=require('node:child_process'),assert=require('node:assert/strict');
const p=require('./fyp-live-platform.cjs'),core=require('./module13-presentation-core.cjs'),{connect}=require('./module13-presentation.cjs'),{dpapi}=require('./fyp-live-vault.cjs');
const UIDS=['demo-m13-admin','demo-m13-member-01'];
function location(){assert.equal(process.platform,'win32');assert(path.isAbsolute(process.env.LOCALAPPDATA));return path.join(process.env.LOCALAPPDATA,'GainPath','Module13Presentation','login.dpapi');}
function open(){const file=location();assert(fs.existsSync(file),'Approved credential reset has not been performed.');assert(!fs.lstatSync(file).isSymbolicLink());const state=JSON.parse(dpapi('unprotect',fs.readFileSync(file,'utf8')));assert.equal(state.schemaVersion,1);assert.equal(state.projectId,core.PROJECT);assert.deepEqual(Object.keys(state.entries).sort(),[...UIDS].sort());return state;}
function save(state){const file=location(),dir=path.dirname(file);fs.mkdirSync(dir,{recursive:true});assert(!fs.lstatSync(dir).isSymbolicLink());
 const acl="$ErrorActionPreference='Stop'; $p=[Console]::In.ReadToEnd(); $sid=[Security.Principal.WindowsIdentity]::GetCurrent().User; $acl=New-Object Security.AccessControl.DirectorySecurity; $acl.SetOwner($sid); $acl.SetAccessRuleProtection($true,$false); $rule=New-Object Security.AccessControl.FileSystemAccessRule($sid,'FullControl','ContainerInherit,ObjectInherit','None','Allow'); $acl.AddAccessRule($rule); [IO.Directory]::SetAccessControl($p,$acl)";
 const r=spawnSync('powershell.exe',['-NoProfile','-NonInteractive','-Command',acl],{input:dir,encoding:'utf8',windowsHide:true});assert.equal(r.status,0,'Private credential ACL required');const tmp=file+'.tmp';fs.writeFileSync(tmp,dpapi('protect',JSON.stringify(state)),{flag:'wx'});fs.renameSync(tmp,file);
}
async function reset(){assert.equal(process.argv[2],'reset-approved-two');assert.equal(process.argv.length,3);assert(process.version.startsWith('v22.'));const c=await connect();try{
 const manifest=p.read('docs/integration/gainpath-fyp-cohort-preflight.json'),saved=p.read('build/module13-presentation/plan.json'),plan=core.buildPlan(manifest,p.read('build/fyp-cohort-integration/proposed-source-records.json'),saved.anchorMillis);assert.equal(plan.digest,saved.digest);await core.execute(c.db,c.auth,plan,{validate:true});
 let state=fs.existsSync(location())?open():{schemaVersion:1,projectId:core.PROJECT,entries:{}};
 if(!Object.keys(state.entries).length){for(const uid of UIDS){const i=manifest.identities.find(i=>i.uid===uid),u=await c.auth.getUser(uid);assert(i&&u.email===i.email);state.entries[uid]={email:i.email,authCreatedAtMillis:Date.parse(u.metadata.creationTime),password:crypto.randomBytes(36).toString('base64url'),resetComplete:false};}save(state);}
 for(const uid of UIDS){const entry=state.entries[uid],u=await c.auth.getUser(uid);assert.equal(u.email,entry.email);assert.equal(Date.parse(u.metadata.creationTime),entry.authCreatedAtMillis);if(entry.resetComplete)continue;await c.auth.updateUser(uid,{password:entry.password});entry.resetComplete=true;save(state);}
 console.log(JSON.stringify({approvedAccounts:UIDS,resetComplete:true,passwordsLogged:false,credentialStorage:'Windows CurrentUser DPAPI; user-only ACL',otherAccountsChanged:0}));
 }finally{await c.close();}}
if(require.main===module)reset().catch(()=>{console.error('Approved two-account reset stopped; credentials omitted.');process.exitCode=1;});
module.exports={open,location,UIDS};
