// Fixed, authenticated FYP walkthrough. No deploy, ordinary evidence admission, financial or provider calls.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const p=require('./fyp-live-platform.cjs'),{connect}=require('./module13-presentation.cjs'),core=require('./module13-presentation-core.cjs');
const out=path.join(p.root,'build/module13-presentation'),q=(extra={})=>({schemaVersion:1,organizationId:'gainpath',...extra});
let clientStage='start';
async function client(){
 clientStage='manifest';
 const manifest=p.read('docs/integration/gainpath-fyp-cohort-preflight.json');
 clientStage='project_connect';const c=await connect();try{
 clientStage='seed_validation';
 const saved=JSON.parse(fs.readFileSync(path.join(out,'plan.json'))),plan=core.buildPlan(manifest,p.read('build/fyp-cohort-integration/proposed-source-records.json'),saved.anchorMillis);
 assert.equal(plan.digest,saved.digest);await core.execute(c.db,c.auth,plan,{validate:true});
 clientStage='credential_vault';const credentials=require('./module13-presentation-credentials.cjs').open();
 clientStage='app_check';const appCheck=await p.appCheck(c),config=fs.readFileSync(path.join(p.root,'apps/admin_web/lib/firebase_options.dart'),'utf8'),key=config.match(/apiKey:\s*'([^']+)'/)?.[1],tokens=new Map();assert(key);
 async function token(uid){if(tokens.has(uid))return tokens.get(uid);const i=manifest.identities.find(i=>i.uid===uid);assert(i);const entry=credentials.entries[uid];assert(entry&&entry.resetComplete,'Only the two approved actors may sign in');const r=await fetch('https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key='+key,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({email:entry.email,password:entry.password,returnSecureToken:true}),signal:AbortSignal.timeout(30000)}),body=await r.json();assert(r.ok&&body.localId===uid,'Approved account sign-in failed');const decoded=await c.auth.verifyIdToken(body.idToken,true);assert.equal(decoded.uid,uid);assert.equal(decoded.email_verified,true);tokens.set(uid,body.idToken);return body.idToken;}
 async function call(uid,operation,data){const r=await fetch(`https://asia-southeast1-${core.PROJECT}.cloudfunctions.net/fypDatasetCommand`,{method:'POST',headers:{'content-type':'application/json',Authorization:'Bearer '+await token(uid),'X-Firebase-AppCheck':appCheck.token},body:JSON.stringify({data:{schemaVersion:1,operation,data}}),signal:AbortSignal.timeout(120000)}),body=await r.json();if(!r.ok||body.error){const e=Error('Protected presentation command rejected');e.code=body.error?.status??String(r.status);e.operation=operation;throw e;}return body.result;}
 return{c,call,manifest,anchor:plan.anchorMillis,close:()=>c.close()};
 }catch(e){await c.close();throw e;}
}
async function main(){const mode=process.argv[2];assert(['generate','walkthrough','inspect'].includes(mode)&&process.argv.length===3&&process.version.startsWith('v22.'));
 const x=await client(),file=path.join(out,'authenticated-'+mode+'.json'),report={at:new Date().toISOString(),projectId:core.PROJECT,rootPath:core.ROOT,mode,realAuth:true,authMethod:'Firebase email/password login for two explicitly approved sample actors',passwordsChanged:true,realAppCheck:true,syntheticEvidenceOnly:true,geminiRequests:0,ordinaryPolicyActivation:false,operations:[],results:[]};
 const call=async(uid,op,data)=>{report.operations.push({uid,operation:op});return x.call(uid,op,data);};
 const loaded=new Map();
 const list=async kind=>{if(loaded.has(kind))return loaded.get(kind);let afterLeadId=null,leads=[];for(let n=0;n<5;n++){const page=await call('demo-m13-admin','admin.queue.list',q({kind,status:'all',startAtMillis:x.anchor-30*86400000,endAtMillis:Date.now(),exerciseId:null,category:null,specialization:null,afterLeadId,limit:25}));leads.push(...page.leads);afterLeadId=page.nextAfterLeadId;if(!afterLeadId)break;}loaded.set(kind,leads);return leads;};
 const checkpoint=()=>fs.writeFileSync(file,JSON.stringify(report,null,2)+'\n');
 try{
 if(mode==='generate'){for(const kind of ['content','trainer']){let continuation=null,last;for(let page=0;page<11;page++){last=await call('demo-m13-admin','admin.queue.refresh',q({kind,commandId:`presentation-${x.anchor}-${kind}-v1`,continuation}));continuation=last.summary.nextCursor;checkpoint();console.log(JSON.stringify({kind,status:last.summary.status,processed:last.summary.processed,generated:last.summary.generated}));if(!continuation)break;}assert.equal(last.summary.status,'complete');report.results.push({kind,summary:last.summary});}}
 if(mode==='inspect'||mode==='walkthrough'){for(const kind of ['content','trainer']){const leads=await list(kind);report.results.push({kind,total:leads.length,pending:leads.filter(l=>l.status==='pending').length,statuses:leads.map(l=>({leadId:l.leadId,memberId:l.memberId,status:l.status,model:l.ranking.model,origin:l.ranking.origin}))});}}
 if(mode==='walkthrough'){
 const selectedFile=path.join(out,'walkthrough-intent.json');let intent;
 if(fs.existsSync(selectedFile))intent=JSON.parse(fs.readFileSync(selectedFile));else{const content=(await list('content')).filter(l=>l.status==='pending'&&l.memberId==='demo-m13-member-01'),trainer=(await list('trainer')).filter(l=>l.status==='pending');const c=content.find(c=>trainer.some(t=>t.memberId===c.memberId));assert(c,'Need a recipient with current eligible content and Coach suggestions');const t=trainer.find(t=>t.memberId===c.memberId);const discard=(await list('content')).find(l=>l.status==='pending'&&l.memberId!==c.memberId);assert(discard);intent={anchor:x.anchor,leads:[c,t],dismiss:discard,memberId:c.memberId};fs.writeFileSync(selectedFile,JSON.stringify(intent,null,2)+'\n',{flag:'wx'});}
 assert.equal(intent.anchor,x.anchor);report.memberId=intent.memberId;
 for(const lead of intent.leads){const input=q({leadId:lead.leadId,commandId:`presentation-send-${lead.leadId}`,expectedRevision:lead.revision,action:'send',reason:null});const sent=await call('demo-m13-admin','admin.queue.decide',input);assert.equal(sent.outcome,'prepared');assert.deepEqual(await call('demo-m13-admin','admin.queue.decide',input),sent);const id=sent.recipientRecommendationId;assert(id);const get=q({action:'get',recommendationId:id,commandId:null,expectedRevision:null});const detail=await call(lead.memberId,'member.recommendation.command',get);assert(['available','dismissed'].includes(detail.state));if(detail.state==='dismissed'){assert.equal(lead.kind,'content');assert.equal(detail.target,null);}const target=detail.target;
 const destination=target===null?null:target.kind==='trainer'?await call(lead.memberId,'member.coach',q({coachId:target.coachId})):await call(lead.memberId,'member.routine',q({routineId:target.destination.routineId}));if(destination)assert.equal(destination.status,'published');
 const inbox=await call(lead.memberId,'module/module9MemberCommandCallable',q({action:'inbox'}));assert(inbox.records.some(n=>n.recommendation?.recommendationId===id));
 const other=(await x.c.db.collection(core.ROOT+'/recommendationRecipients').where('memberId','==','demo-m13-member-02').limit(1).get()).docs[0];assert(other,'Existing peer recipient required for ownership denial');
 let peerDenied=false;try{await call('demo-m13-member-01','member.recommendation.command',q({action:'get',recommendationId:other.id,commandId:null,expectedRevision:null}));}catch(e){assert.equal(e.code,'PERMISSION_DENIED');peerDenied=true;}assert(peerDenied);
 report.results.push({leadId:lead.leadId,recommendationId:id,memberId:lead.memberId,kind:lead.kind,delivered:true,currentDestination:detail.state==='available',alreadyDismissed:detail.state==='dismissed',peerDenied:true});checkpoint();}
 const lead=intent.dismiss,input=q({leadId:lead.leadId,commandId:`presentation-dismiss-${lead.leadId}`,expectedRevision:lead.revision,action:'dismiss',reason:'Guidance is not needed at this time.'});const dismissed=await call('demo-m13-admin','admin.queue.decide',input);assert.equal(dismissed.outcome,'dismissed');assert.deepEqual(await call('demo-m13-admin','admin.queue.decide',input),dismissed);report.adminDismissal=true;
 // Exercise Member dismissal on the tutorial and retain the Coach suggestion. Intent makes reruns use the same command receipt.
 const sentRow=report.results.find(r=>r.kind==='content'&&r.recommendationId),id=sentRow.recommendationId;
 const detail=await call(intent.memberId,'member.recommendation.command',q({action:'get',recommendationId:id,commandId:null,expectedRevision:null}));
 const responsePath=path.join(out,'member-dismiss-intent.json');let dismissal=fs.existsSync(responsePath)?JSON.parse(fs.readFileSync(responsePath)):q({action:'dismiss',recommendationId:id,commandId:`presentation-member-dismiss-${id}`,expectedRevision:detail.revision});if(!fs.existsSync(responsePath))fs.writeFileSync(responsePath,JSON.stringify(dismissal,null,2)+'\n',{flag:'wx'});
 const result=await call(intent.memberId,'member.recommendation.command',dismissal);assert.equal(result.state,'dismissed');assert.equal(result.target,null);assert.deepEqual(await call(intent.memberId,'member.recommendation.command',dismissal),result);report.memberDismissal=true;
 }
 report.passed=true;checkpoint();console.log(JSON.stringify({mode,passed:true,results:report.results.length,memberId:report.memberId??null,providerCalls:0}));
 }catch(e){report.passed=false;report.failure={code:e.code??'assertion_or_precondition',operation:e.operation??null,assertion:e.code==='ERR_ASSERTION'?String(e.message).slice(0,180):null};checkpoint();console.error(JSON.stringify({mode,passed:false,...report.failure}));process.exitCode=1;}finally{await x.close();}
}
if(require.main===module)main().catch(e=>{console.error(JSON.stringify({status:'presentation_initialization_failed',stage:clientStage,code:e.presentationCode??e.code??null,errorClass:e.name,privateDetailsOmitted:true}));process.exitCode=1;});
module.exports={client};
