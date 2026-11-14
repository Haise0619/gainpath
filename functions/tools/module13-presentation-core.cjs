// Fixed-project, append-only fictional presentation refresh. No callable, provider or Auth writes.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const ROOT='orgs/gainpath/cohorts/fyp-v1',PROJECT='gainpath-0619',SEED='gainpath-fyp-v1',VERSION='module13-presentation-v1';
function canonical(v){if(v instanceof Date)return {$timestampMillis:v.getTime()};if(v&&typeof v.toMillis==='function')return {$timestampMillis:v.toMillis()};if(Array.isArray(v))return v.map(canonical);if(v&&typeof v==='object')return Object.fromEntries(Object.entries(v).sort(([a],[b])=>a.localeCompare(b)).map(([k,x])=>[k,canonical(x)]));return v;}
const hash=v=>crypto.createHash('sha256').update(JSON.stringify(canonical(v))).digest('hex');
function payloadCanonical(v){if(Array.isArray(v))return '['+v.map(payloadCanonical).join(',')+']';if(v&&typeof v==='object')return '{'+Object.entries(v).sort(([a],[b])=>a<b?-1:a>b?1:0).map(([k,x])=>JSON.stringify(k)+':'+payloadCanonical(x)).join(',')+'}';if(typeof v==='number'){check(Number.isFinite(v));const b=Buffer.alloc(8);b.writeDoubleBE(v===0?0:v);return 'n'+b.toString('hex');}return JSON.stringify(v);}
const payloadHash=v=>crypto.createHash('sha256').update(payloadCanonical(v)).digest('hex');
const owner=p=>`${ROOT}/seedOwnership/${hash(p)}`,proof=(p,d)=>({schemaVersion:1,seedId:SEED,path:p,digest:hash(d)});
function check(ok,code='scope_or_ownership_drift'){if(!ok){const e=Error('Presentation operation stopped.');e.presentationCode=code;throw e;}}
function buildPlan(manifest,records,anchor){
 check(manifest.projectId===PROJECT&&manifest.databaseId==='(default)'&&manifest.rootPath===ROOT&&manifest.seedId===SEED&&Number.isSafeInteger(anchor)&&anchor>=1794614400000&&anchor<1797206400000);
 const identities=manifest.identities;check(identities.length===27&&new Set(identities.map(i=>i.uid)).size===27&&identities.every(i=>/^demo-m13-(admin|coach-0[1-8]|member-(0[1-9]|1[0-8]))$/.test(i.uid)&&i.email===`${i.uid}@gainpath-demo.invalid`));
 const baseline=Object.fromEntries(records.records.map(r=>{check(hash(r.data)===r.digest);return [r.path,r.data];})),sourcePath=`${ROOT}/module13DemoSource/current`,before=baseline[sourcePath],source=structuredClone(before),entries={};check(before&&before.rootPath===ROOT);
 const tag=new Date(anchor).toISOString().slice(0,10).replaceAll('-','');
 for(const uid of identities.filter(i=>i.role==='member').map(i=>i.uid)){
  const templates=records.records.filter(r=>r.path.startsWith(`${ROOT}/members/${uid}/syntheticObservations/`)).slice(0,3);
  for(const [n,t] of templates.entries()){
   const d=structuredClone(t.data),old=d.observedAtMillis,at=anchor-(n+1)*86400000,id=`m13p-${tag}-${uid.slice(-2)}-${n+1}`,delta=at-old;
   function shift(v){if(Array.isArray(v))return v.map(shift);if(v&&typeof v==='object')return Object.fromEntries(Object.entries(v).map(([k,x])=>[k,shift(x)]));if(typeof v==='string'&&/^\d{4}-\d\d-\d\dT/.test(v)&&Number.isFinite(Date.parse(v)))return new Date(Date.parse(v)+delta).toISOString();return v;}
   d.payload=shift(d.payload);d.payload.sessionId=id;d.observationId=id;d.observedAtMillis=at;d.digest=payloadHash(d.payload);const p=`${ROOT}/members/${uid}/syntheticObservations/${id}`;entries[p]=d;source.observationPaths.push(p);source.observationPathsByMember[uid].push(p);source.observationTimesByPath[p]=at;
  }
  check(source.observationPathsByMember[uid].length<=100);
 }
 // Only add free future fixture days; never replace a Coach-edited day or create bookings.
 for(const uid of identities.filter(i=>i.role==='coach').map(i=>i.uid)){
  const template=records.records.find(r=>r.path.startsWith(`${ROOT}/coachAvailability/${uid}/days/`));check(template);
  for(let n=1;n<=3;n++){const date=new Date(anchor+n*86400000).toISOString().slice(0,10),start=Date.parse(`${date}T02:00:00Z`),d=structuredClone(template.data);d.createdAtMillis=anchor;d.updatedAtMillis=anchor;d.revision=1;d.windows=d.windows.length?[{branchId:'main',startAtMillis:start,endAtMillis:start+4*3600000}]:[];entries[`${ROOT}/coachAvailability/${uid}/days/${date}`]=d;}
 }
 // Extend only the fictional decision window; prior pending evidence can become stale.
 // Consent start, actual policies, accepted workout release and successful deliveries are untouched.
 check(anchor>source.window.endAtMillis&&anchor-source.window.startAtMillis<=90*86400000,'window_bound');
 source.window.endAtMillis=anchor;
 source.bookingDate=new Date(anchor+86400000).toISOString().slice(0,10);
 const plan={schemaVersion:1,version:VERSION,projectId:PROJECT,databaseId:'(default)',anchorMillis:anchor,identities,sourcePath,sourceBefore:before,sourceAfter:source,entries,baselineDigest:hash(records),manifestDigest:hash(manifest),sourceManifestDigest:manifest.sourceManifestDigest};
 return {...plan,digest:hash(plan)};
}
async function execute(db,auth,plan,{write=false,validate=false}={}){
 const {digest,...body}=plan;check(digest===hash(body)&&plan.version===VERSION&&plan.projectId===PROJECT&&db.projectId===PROJECT&&db.databaseId==='(default)'&&auth.app.options.projectId===PROJECT);
 const auditPath=`${ROOT}/presentationSeeds/${VERSION}-${plan.anchorMillis}`;
 const authBindings=[];for(const i of plan.identities){const u=await auth.getUser(i.uid),created=Date.parse(u.metadata.creationTime);check(u.email===i.email&&u.displayName===i.displayName&&u.emailVerified===true&&!u.disabled&&u.customClaims?.fypAuthCreatedAtMillis===created&&Object.keys(u.customClaims).length===1);authBindings.push({i,created});}
 return db.runTransaction(async tx=>{
  const guards=authBindings.flatMap(({i})=>[`datasetAssignments/${i.uid}`,`${ROOT}/seedAuthOwnership/${i.uid}`]);
  const paths=[ROOT,`${ROOT}/seedRuns/${SEED}`,'datasetRuntimeReleases/fyp-v1',plan.sourcePath,owner(plan.sourcePath),auditPath,...guards,...Object.keys(plan.entries).flatMap(p=>[p,owner(p)])];
  const snaps=await tx.getAll(...paths.map(p=>db.doc(p))),rows=Object.fromEntries(paths.map((p,n)=>[p,snaps[n].data()])),audit=rows[auditPath],done=!!audit;
  const release=rows['datasetRuntimeReleases/fyp-v1'],run=rows[`${ROOT}/seedRuns/${SEED}`];check(rows[ROOT]?.enabled===true&&run?.status==='complete'&&run.seedId===SEED&&release?.enabled===true&&release.fictionalOnly===true&&release.projectId===PROJECT&&release.databaseId==='(default)'&&release.rootPath===ROOT&&release.sourceManifestDigest===run.planDigest&&run.planDigest===plan.sourceManifestDigest&&hash([...(release.authUids??[])].sort())===hash(plan.identities.map(i=>i.uid).sort()),'release_or_cohort_binding');
  check(hash(rows[plan.sourcePath])===hash(done?plan.sourceAfter:plan.sourceBefore)&&hash(rows[owner(plan.sourcePath)])===hash(proof(plan.sourcePath,done?plan.sourceAfter:plan.sourceBefore)),'source_index_or_seed_proof_drift');
  if(done)check(hash(audit)===hash({schemaVersion:1,classification:'fictional_synthetic_presentation',planDigest:digest,sourceBeforeDigest:hash(plan.sourceBefore),sourceAfterDigest:hash(plan.sourceAfter),entryDigests:Object.fromEntries(Object.entries(plan.entries).map(([p,d])=>[p,hash(d)]))}));
  for(const {i,created} of authBindings){const a=rows[`datasetAssignments/${i.uid}`],o=rows[`${ROOT}/seedAuthOwnership/${i.uid}`];check(a?.datasetId==='fyp-v1'&&a.organizationId==='gainpath'&&a.seedId===SEED&&a.enabled===true&&a.role===i.role&&a.authCreatedAtMillis===created&&o?.state==='bound'&&o.seedId===SEED&&o.uid===i.uid&&o.email===i.email&&o.authCreatedAtMillis===created);}
  for(const [p,d]of Object.entries(plan.entries)){check(p.startsWith(ROOT+'/'));if(done)check(hash(rows[p])===hash(d)&&hash(rows[owner(p)])===hash(proof(p,d)));else check(!rows[p]&&!rows[owner(p)],'append_path_collision');}
  if(validate)check(done);
  if(write&&!done){for(const [p,d]of Object.entries(plan.entries)){tx.create(db.doc(p),d);tx.create(db.doc(owner(p)),proof(p,d));}tx.set(db.doc(plan.sourcePath),plan.sourceAfter);tx.set(db.doc(owner(plan.sourcePath)),proof(plan.sourcePath,plan.sourceAfter));tx.create(db.doc(auditPath),{schemaVersion:1,classification:'fictional_synthetic_presentation',planDigest:digest,sourceBeforeDigest:hash(plan.sourceBefore),sourceAfterDigest:hash(plan.sourceAfter),entryDigests:Object.fromEntries(Object.entries(plan.entries).map(([p,d])=>[p,hash(d)]))});}
  return {valid:true,alreadyApplied:done,appendDocuments:Object.keys(plan.entries).length,authWrites:0,providerCalls:0,sourceIndexUpdated:write&&!done};
 });
}
module.exports={ROOT,PROJECT,VERSION,hash,payloadHash,owner,proof,buildPlan,execute};
