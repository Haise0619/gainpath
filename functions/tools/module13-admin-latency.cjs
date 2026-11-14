// Read-only fixed-cohort benchmark. No deploy, writes, refresh, decisions, or provider calls.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {performance}=require('node:perf_hooks'),{client}=require('./module13-presentation-walkthrough.cjs');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'build/module13-admin-performance');
async function main(){
 const phase=process.argv[2];assert(['baseline','after'].includes(phase)&&process.argv.length===3);
 fs.mkdirSync(out,{recursive:true});const file=path.join(out,phase+'.json');
 const previous=phase==='after'?JSON.parse(fs.readFileSync(path.join(out,'baseline.json'),'utf8')):null;
 const report={phase,projectId:'gainpath-0619',scope:'orgs/gainpath/cohorts/fyp-v1',startedAt:new Date().toISOString(),coldStart:'First observed only; no forced cold start or proven startup correlation.',method:'Three content and trainer list pairs (sequential baseline; parallel after); at most two available pending details; fixed recent 30-day window and limit 25. Parallel first calls may each include lazy sign-in. Auth/AppCheck setup excluded except first callable lazy sign-in. SDK reads use administrative credentials, not equivalent authorization.',calls:[],pairedLoads:[],direct:[],providerCalls:0,mutations:0};
 const save=()=>fs.writeFileSync(file,JSON.stringify(report,null,2)+'\n');let x;
 try{
 x=await client();const name='projects/gainpath-0619/locations/asia-southeast1/functions/fypDatasetCommand';
 const metadata=await x.c.request('GET','https://cloudfunctions.googleapis.com/v2/'+name);
 const s=metadata.serviceConfig??{};report.deployed={name:metadata.name,state:metadata.state,updateTime:metadata.updateTime,runtime:metadata.buildConfig?.runtime,service:s.service,availableMemory:s.availableMemory,availableCpu:s.availableCpu,timeoutSeconds:s.timeoutSeconds,minInstanceCount:s.minInstanceCount??0,maxInstanceCount:s.maxInstanceCount,maxInstanceRequestConcurrency:s.maxInstanceRequestConcurrency,environmentVariablesOmitted:true};
 report.window=previous?.window??{startAtMillis:Date.now()-30*86400000,endAtMillis:Date.now()};
 const query=kind=>({schemaVersion:1,organizationId:'gainpath',kind,status:'all',...report.window,exerciseId:null,category:null,specialization:null,afterLeadId:null,limit:25});
 const details=[];
 async function call(operation,data,round,kind=data.kind??null){const t=performance.now();try{const result=await x.call('demo-m13-admin',operation,data);report.calls.push({operation,kind,round,elapsedMs:Math.round(performance.now()-t),count:result.leads?.length??null,status:'ok',pending:result.leads?.filter(l=>l.status==='pending').length??null});save();return result;}catch(e){report.calls.push({operation,kind,round,elapsedMs:Math.round(performance.now()-t),status:'error',code:e.code??null});save();throw e;}}
 const kinds=['content','trainer'];
 for(let round=0;round<3;round++){
  const started=performance.now(), readKind=kind=>call('admin.queue.list',query(kind),round);
  const pages=phase==='after'
   ?await Promise.all(kinds.map(readKind))
   :[await readKind('content'),await readKind('trainer')];
  report.pairedLoads.push({round,elapsedMs:Math.round(performance.now()-started),mode:phase==='after'?'parallel':'sequential'});
  if(round===0)for(const page of pages){
   const lead=page.leads.find(l=>l.status==='pending');
   if(lead)details.push({schemaVersion:1,organizationId:'gainpath',kind:lead.kind,leadId:lead.leadId});
  }
 }
 for(const d of details.slice(0,2))try{const {kind,...data}=d;await call('admin.queue.detail',data,0,kind);}catch{}
 for(let round=0;round<3;round++){const t=performance.now();const rows=await x.c.db.collection(report.scope+'/recommendationLeads').orderBy('__name__').limit(26).get();report.direct.push({round,elapsedMs:Math.round(performance.now()-t),documents:rows.size,kind:'bounded raw SDK query; no callable authorization or response projection'});save();}
 const logs=await x.c.request('POST','https://logging.googleapis.com/v2/entries:list',{resourceNames:['projects/gainpath-0619'],filter:`resource.type="cloud_run_revision" AND resource.labels.service_name="fypdatasetcommand" AND timestamp>="${report.startedAt}"`,orderBy:'timestamp desc',pageSize:50}).catch(()=>null);
 report.logs=logs?{available:true,entries:(logs.entries??[]).map(e=>({timestamp:e.timestamp,logName:e.logName?.split('/').at(-1),latency:e.httpRequest?.latency??null,status:e.httpRequest?.status??null,startupEvidence:typeof e.textPayload==='string'&&/Starting new instance|Default STARTUP TCP probe succeeded/.test(e.textPayload)})).filter(e=>e.latency||e.startupEvidence)}:{available:false};
 report.finishedAt=new Date().toISOString();report.passed=true;save();console.log(JSON.stringify(report,null,2));
 }finally{if(x)await x.close();}
}
if(require.main===module)main().catch(e=>{console.error(JSON.stringify({benchmarkFailed:true,code:e.code??null,errorClass:e.name,privateDetailsOmitted:true}));process.exitCode=1;});
