/* Explicit opt-in, synthetic-only real Gemini evaluation. No Firebase datastore bootstrap. */
'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {spawnSync}=require('node:child_process');
const {openPocBudget}=require('./module13-batch-b-budget.cjs');
const functionRoot=path.resolve(__dirname,'..');
const evidenceRoot=path.resolve(functionRoot,'../build/module13-batch-b');
const runVersion='verified_structural_schema_v1';
function enableLocalTypescript(){
  const ts=require('typescript');
  require.extensions['.ts']=(module,filename)=>{
    if(!filename.startsWith(functionRoot+path.sep)||filename.includes(`${path.sep}node_modules${path.sep}`))throw Error('unexpected_typescript_source');
    const text=ts.transpileModule(fs.readFileSync(filename,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,esModuleInterop:true}}).outputText;
    module._compile(text,filename);
  };
}
function existingCredential(){
  if(process.env.GEMINI_API_KEY?.trim())return process.env.GEMINI_API_KEY.trim();
  const r=spawnSync(process.execPath,[path.join(functionRoot,'node_modules/firebase-tools/lib/bin/firebase.js'),'functions:secrets:access','GEMINI_API_KEY','--project','gainpath-0619','--non-interactive'],{encoding:'utf8',timeout:25000,windowsHide:true,maxBuffer:65536});
  const key=r.stdout?.trim();
  if(r.status!==0||!key||!/^[-\w]{20,200}$/.test(key))throw Error('existing_configured_credential_unavailable');
  return key;
}
async function metadataJson(url,init){
  const r=await fetch(url,{...init,signal:AbortSignal.timeout(10000),redirect:'error'});
  if(!r.ok)throw Error(`provider_preflight_http_${r.status}`);
  const text=await r.text();if(Buffer.byteLength(text)>131072)throw Error('preflight_oversize');
  return JSON.parse(text);
}
async function runRealPoc(){
  if(process.argv.length!==3||process.argv[2]!=='--run-real')throw Error('explicit_run_real_flag_required');
  const budget=openPocBudget(evidenceRoot);
  let report={schemaVersion:1,datasetId:'module13-batch-b-v1',inferenceMeasurement:'real_gemini',startedAt:new Date().toISOString(),preflight:null,scenarios:[],status:'incomplete',blocker:null};
  const resultPath=path.join(evidenceRoot,'poc-results.json');
  if(fs.existsSync(resultPath))report=JSON.parse(fs.readFileSync(resultPath,'utf8'));
  const save=()=>fs.writeFileSync(resultPath,JSON.stringify(report,null,2)+'\n');
  try{
    enableLocalTypescript();
    const {SYNTHETIC_RECOMMENDATION_SCENARIOS,prepareSyntheticScenario}=require('../test/recommendation-evaluation.fixture.ts');
    const {createGeminiRecommendationRanker,RecommendationProviderError}=require('../src/modules/recommendation/gemini-recommendation-ranker.ts');
    const {rankRecommendationCandidates}=require('../src/modules/recommendation/recommendation-engine.ts');
    const {evaluateRankingResult}=require('../src/modules/recommendation/recommendation-evaluation.ts');
    const key=existingCredential(),model=process.env.GEMINI_CHAT_MODEL||'gemini-3.5-flash-lite';
    // Do not silently switch models/rates. A different configured model needs a new reviewed cost bound.
    if(model!=='gemini-3.5-flash-lite')throw Error('configured_model_needs_cost_review');
    const headers={'Content-Type':'application/json','x-goog-api-key':key};
    const metadata=await metadataJson(`https://generativelanguage.googleapis.com/v1beta/models/${model}`,{headers});
    if(!metadata.supportedGenerationMethods?.includes('generateContent')||metadata.outputTokenLimit<2048||metadata.inputTokenLimit<6000)throw Error('configured_model_capability_unavailable');
    report.preflight={checkedAt:new Date().toISOString(),configuredModel:model,modelName:metadata.name,version:metadata.version,supportedGenerationMethods:metadata.supportedGenerationMethods,inputTokenLimit:metadata.inputTokenLimit,outputTokenLimit:metadata.outputTokenLimit,
      credential:'existing_GEMINI_API_KEY_only',structuredOutput:'verified basic OpenAPI responseSchema plus full strict independent local validation',maxGenerationAttempts:20,maxConcurrent:1,maxInputTokens:6000,maxOutputTokens:2048,timeoutMillis:15000,automaticRetries:0,
      standardUsdPerMillion:{input:.30,outputIncludingThinking:2.50},maxEstimatedGenerationCostUsd:20*(6000*.30+2048*2.50)/1e6,
      quotaAndBilling:'No billing/quota settings read or changed. Exact remaining project quota/tier not exposed by model metadata. Stop on auth/payment/quota or preflight failure; usage priced conservatively at published paid rates.'};save();
    for(const scenario of SYNTHETIC_RECOMMENDATION_SCENARIOS){
      const effectiveRunVersion=scenario.id.endsWith('_injection')?'directive_quarantine_v1':runVersion;
      if(report.scenarios.some(s=>s.id===scenario.id&&s.runVersion===effectiveRunVersion))continue;
      const attemptScenario=`${scenario.id}_${scenario.id.endsWith('_injection')?'quarantine_v1':'structural_v1'}`;
      if(budget.snapshot().attempts.some(a=>a.scenario===attemptScenario))throw Error('prior_attempt_without_result_no_automatic_retry');
      const prepared=await prepareSyntheticScenario(scenario);
      let rawInference=null,tokenPreflight=null,attempt=null,providerHttp=null;
      const fetcher=async(url,init)=>{
        if(url!==`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`)throw Error('unexpected_provider_destination');
        const body=JSON.parse(init.body);
        const count=await metadataJson(`https://generativelanguage.googleapis.com/v1beta/models/${model}:countTokens`,{method:'POST',headers,body:JSON.stringify({generateContentRequest:{model:`models/${model}`,...body}})});
        if(!Number.isSafeInteger(count.totalTokens)||count.totalTokens<1||count.totalTokens>6000)throw new RecommendationProviderError('invalid_request');
        tokenPreflight=count.totalTokens;
        attempt=budget.reserve({scenario:attemptScenario,requestHash:crypto.createHash('sha256').update(init.body).digest('hex'),inputTokens:count.totalTokens});
        try{const response=await fetch(url,init);providerHttp={status:response.status};
          if(!response.ok){try{const e=await response.clone().json();providerHttp.errorStatus=typeof e?.error?.status==='string'?e.error.status:null;providerHttp.message=typeof e?.error?.message==='string'?e.error.message.replaceAll(key,'[redacted]').slice(0,600):null;}catch{}}
          budget.complete(attempt,response.ok?'returned':'failed');return response;}
        catch{budget.complete(attempt,'failed');throw new RecommendationProviderError(init.signal?.aborted?'timeout':'provider_unavailable');}
      };
      const base=createGeminiRecommendationRanker({apiKey:key,model,fetcher});
      const provider=async request=>{rawInference=await base(request);return rawInference;};
      const result=await rankRecommendationCandidates(scenario.need,prepared.candidates,{context:prepared.context,provider});
      const metrics=evaluateRankingResult(result,prepared.labels,attempt===null?'not_measured':'real_gemini');
      report.scenarios.push({id:scenario.id,runVersion:effectiveRunVersion,kind:scenario.kind,need:scenario.need,labelSource:'predeclared_provisional_engineering_v1',labelRationale:scenario.rationale,labels:prepared.labels,eligibleCandidateIds:prepared.candidates.map(c=>c.id),tokenPreflight,attempt,providerHttp,result,metrics,rawStructuredResponse:rawInference?.text??null});save();
      process.stdout.write(JSON.stringify({scenario:scenario.id,attempt,origin:result.origin,validation:result.provenance.validationStatus,orderChanged:metrics.aiReordered,inputTokens:result.provenance.usage.inputTokens,outputTokens:result.provenance.usage.outputTokens})+'\n');
      // Invalid model output is an evaluation outcome with baseline fallback, never retried.
      // Access/quota/transport failures stop the bounded run. Controls do not call the provider.
      if(result.provenance.validationStatus==='provider_failed')throw Error(`poc_stopped_${result.provenance.fallbackReason}`);
    }
    report.status='complete';report.blocker=null;report.completedAt=new Date().toISOString();
  }catch(error){report.status='incomplete';report.blocker=/^[a-z0-9_]+$/.test(error?.message||'')?error.message:'local_poc_failure';process.stdout.write(JSON.stringify({pocStatus:'incomplete',blocker:report.blocker})+'\n');}
  finally{report.requestBudget=budget.snapshot();save();budget.close();}
  return report;
}
if(require.main===module)runRealPoc().then(r=>{process.exitCode=r.status==='complete'?0:1;}).catch(()=>{process.stdout.write('Local POC could not start safely.\n');process.exitCode=1;});
module.exports={runRealPoc,enableLocalTypescript,existingCredential,metadataJson};
