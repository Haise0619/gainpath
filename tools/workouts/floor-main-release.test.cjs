const {test}=require('node:test'),assert=require('node:assert/strict');
const {content,paths,encode,decode,hash,assertTargetProof,requiredReviewInputs,normalizeFunction}=require('./floor-main-release.cjs');
test('publication is exactly one distinct floor catalog/routine/blueprint/audit',()=>{
 const p=content();assert.equal(p.exerciseId,'standard-floor-push-up-side-v1');assert.equal(p.content.title,'Standard Floor Push-Up');
 assert.equal(paths(p).length,4);assert.equal(new Set(paths(p)).size,4);
 assert(paths(p).every(x=>x.startsWith('orgs/gainpath/')&&!x.includes('wall-push-up')&&!x.includes('/members/')));
 assert.deepEqual(p.content.exercises.map(e=>[e.exerciseId,e.sets,e.reps,e.restSeconds]),[['standard-floor-push-up-side-v1',3,8,60]]);
 assert.equal(p.fields.isActive,true);assert.equal(p.content.status,'published');
 assert.deepEqual(decode(encode(p)),p);
});
const before={name:'function',state:'ACTIVE',updateTime:'old',buildConfig:{runtime:'nodejs22',entryPoint:'workoutBackupCommand',source:{object:'old'},build:'old'},serviceConfig:{revision:'old',service:'same',environmentVariables:{preserve:'yes'}}};
function fixture(){const current=structuredClone(before);current.updateTime='new';current.buildConfig.source.object='prepared';current.buildConfig.build='new';current.serviceConfig.revision='new';return{current,proof:{active:true,sourceHashVerified:true,sha256:'prepared-sha',functionDigest:hash(current)},expected:{preparedSha256:'prepared-sha'},iam:{bindings:[]}};}
test('verified source-only revision preserves runtime and IAM',()=>{const f=fixture();assertTargetProof(f.current,before,f.proof,f.expected,f.iam,f.iam);});
for(const drift of ['source','runtime','iam','receipt','state'])test('stale receipt cannot hide live '+drift+' drift',()=>{
 const f=fixture(),originalIam=structuredClone(f.iam);
 if(drift==='source')f.current.buildConfig.source.object='rolled-back';
 if(drift==='runtime'){f.current.buildConfig.runtime='nodejs24';f.proof.functionDigest=hash(f.current);}
 if(drift==='iam')f.iam.bindings.push({role:'unexpected'});
 if(drift==='receipt')f.proof.sha256='other';
 if(drift==='state'){f.current.state='DEPLOYING';f.proof.functionDigest=hash(f.current);}
 assert.throws(()=>assertTargetProof(f.current,before,f.proof,f.expected,f.iam,originalIam));
});
test('seal requires mutable helpers and target/security baselines',()=>{
 for(const p of ['build/latency-completion-20261024/cloud.cjs','tools/admin_web/cache-policy.cjs',
  'build/floor-push-up-main-20261106/package-manifest.json',
  'build/floor-push-up-main-20261106/functions-before.private.json'])assert(requiredReviewInputs.includes(p));
});
test('Eventarc filter-map order is ignored without hiding value or metadata drift',()=>{
 const a={state:'ACTIVE',updateTime:'same',eventTrigger:{eventFilters:[{attribute:'database',value:'(default)'},{attribute:'namespace',value:'(default)'}]}};
 const b=structuredClone(a);b.eventTrigger.eventFilters.reverse();
 assert.deepEqual(normalizeFunction(a),normalizeFunction(b));
 assert.equal(a.eventTrigger.eventFilters[0].attribute,'database');
 b.eventTrigger.eventFilters[0].value='changed';
 assert.notDeepEqual(normalizeFunction(a),normalizeFunction(b));
 const c=structuredClone(a);c.updateTime='changed';
 assert.notDeepEqual(normalizeFunction(a),normalizeFunction(c));
});
