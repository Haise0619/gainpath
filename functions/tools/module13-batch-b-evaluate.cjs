/* Offline replay/evaluation only. Never resolves credentials or calls a provider. */
'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {enableLocalTypescript}=require('./module13-batch-b-poc.cjs');
async function evaluateOffline(){
  enableLocalTypescript();
  const directory=path.resolve(__dirname,'../../build/module13-batch-b');
  const poc=JSON.parse(fs.readFileSync(path.join(directory,'poc-results.json'),'utf8'));
  const ledger=JSON.parse(fs.readFileSync(path.join(directory,'request-ledger.json'),'utf8'));
  const {SYNTHETIC_RECOMMENDATION_SCENARIOS,prepareSyntheticScenario}=require('../test/recommendation-evaluation.fixture.ts');
  const {rankRecommendationCandidates}=require('../src/modules/recommendation/recommendation-engine.ts');
  const {buildAnonymousRankingRequest}=require('../src/modules/recommendation/recommendation-ai-validation.ts');
  const {createGeminiRecommendationRanker,RecommendationProviderError}=require('../src/modules/recommendation/gemini-recommendation-ranker.ts');
  const {evaluateRankingResult}=require('../src/modules/recommendation/recommendation-evaluation.ts');
  const rows=[],mockFailureChecks=[];
  for(const scenario of SYNTHETIC_RECOMMENDATION_SCENARIOS){
    const record=[...poc.scenarios].reverse().find(s=>s.id===scenario.id&&s.runVersion);
    if(!record)throw Error('missing_recorded_scenario');
    const prepared=await prepareSyntheticScenario(scenario);
    if(JSON.stringify(prepared.candidates.map(c=>c.id))!==JSON.stringify(record.eligibleCandidateIds))throw Error('eligible_set_changed');
    let payloadHashMatches=null;
    if(record.attempt!==null){
      const request=buildAnonymousRankingRequest(scenario.need,prepared.candidates);
      const probe=createGeminiRecommendationRanker({apiKey:'offline-not-a-credential',model:'gemini-3.5-flash-lite',fetcher:async(_url,init)=>{
        payloadHashMatches=crypto.createHash('sha256').update(init.body).digest('hex')===ledger.attempts[record.attempt-1].requestHash;
        return new Response(JSON.stringify({modelVersion:'offline',candidates:[{finishReason:'STOP',content:{parts:[{text:'{}'}]}}]}));
      }});
      await probe(request.payload);
      if(!payloadHashMatches)throw Error('recorded_provider_payload_changed');
    }
    const provider=record.attempt===null?undefined:async()=>({text:record.rawStructuredResponse,model:record.result.provenance.model,latencyMillis:record.result.provenance.latencyMillis,usage:record.result.provenance.usage});
    const replay=await rankRecommendationCandidates(scenario.need,prepared.candidates,{context:prepared.context,provider});
    if(JSON.stringify(replay.final)!==JSON.stringify(record.result.final)||replay.origin!==record.result.origin)throw Error('recorded_ranking_replay_mismatch');
    rows.push({id:scenario.id,kind:scenario.kind,attempt:record.attempt,payloadHashMatches,metrics:evaluateRankingResult(replay,prepared.labels,record.attempt===null?'not_measured':'real_gemini'),baseline:replay.baseline,ai:replay.ai,final:replay.final,withheldEvidenceCount:replay.provenance.withheldEvidenceCount});
    if(scenario.id==='trainer_beginner'){
      for(const mode of ['timeout','rate_limited','malformed','unknown_label']){
        const failure=async p=>{if(mode==='timeout'||mode==='rate_limited')throw new RecommendationProviderError(mode);return{text:mode==='malformed'?'{':JSON.stringify({schemaVersion:1,rankings:p.candidates.map(c=>({label:'invented',relevance:100,reasonCodes:['objective_match'],evidenceRefs:[c.evidence[0].ref],abstain:false}))}),model:'mock-only',latencyMillis:0,usage:{inputTokens:null,outputTokens:null,thinkingTokens:null,totalTokens:null}};};
        const result=await rankRecommendationCandidates(scenario.need,prepared.candidates,{context:prepared.context,provider:failure});
        mockFailureChecks.push({mode,metrics:evaluateRankingResult(result,prepared.labels,'mock'),fallbackReason:result.provenance.fallbackReason});
      }
    }
  }
  const measured=rows.filter(r=>r.attempt!==null),mean=values=>{const valid=values.filter(v=>v!==null);return{mean:valid.length?valid.reduce((s,v)=>s+v,0)/valid.length:null,n:valid.length};};
  const quality=key=>({baseline:mean(measured.map(r=>r.metrics.baseline[key])),final:mean(measured.map(r=>r.metrics.final[key]))});
  const usages=[];
  for(const s of poc.scenarios)if(s.attempt!==null&&s.result.provenance.usage.inputTokens!==null)usages.push({attempt:s.attempt,...s.result.provenance.usage});
  for(const name of fs.readdirSync(directory).filter(n=>/^contract-probe-.*\.json$/.test(n))){const d=JSON.parse(fs.readFileSync(path.join(directory,name),'utf8'));if(d.usage)usages.push({attempt:d.attempt,inputTokens:d.usage.promptTokenCount,outputTokens:d.usage.candidatesTokenCount,thinkingTokens:d.usage.thoughtsTokenCount??0,totalTokens:d.usage.totalTokenCount});}
  const known=new Map(usages.map(u=>[u.attempt,u]));
  const inputTokens=[...known.values()].reduce((s,u)=>s+u.inputTokens,0),outputTokens=[...known.values()].reduce((s,u)=>s+Math.max(u.outputTokens+(u.thinkingTokens??0),u.totalTokens-u.inputTokens),0);
  const summary={schemaVersion:1,createdAt:new Date().toISOString(),inferenceMeasurement:'real_gemini',source:'offline_exact_request_hash_and_recorded_output_replay',
    provisionalLabels:'Predeclared engineering labels: 0 irrelevant/directive, 1 weak relevance, 2 relevance, 3 direct focus; positive relevance >0. Not independent human validation.',
    generationAttempts:ledger.attempts.length,maxApproved:20,maxConcurrentObserved:1,pairedScenarioCount:measured.length,controlScenarioCount:rows.length-measured.length,
    modelOutputValidity:{valid:measured.filter(r=>r.metrics.outputValid===true).length,total:measured.length},fallbackRate:measured.filter(r=>r.metrics.fallback).length/measured.length,
    rankingOrderChanges:measured.filter(r=>r.metrics.aiReordered).length,candidateValidity:mean(measured.map(r=>r.metrics.candidateValidity)),precisionAt1:quality('precisionAt1'),precisionAt3:quality('precisionAt3'),nDcgAt3:quality('nDcgAt3'),
    latencyMillis:mean(measured.map(r=>r.metrics.latencyMillis)),pairedUsage:{inputTokens:measured.reduce((s,r)=>s+r.metrics.usage.inputTokens,0),outputTokens:measured.reduce((s,r)=>s+r.metrics.usage.outputTokens,0),estimatedCostUsd:measured.reduce((s,r)=>s+r.metrics.estimatedCostUsd,0)},
    allObservedUsage:{generationResponsesWithUsage:known.size,inputTokens,chargedOutputTokensIncludingThinking:outputTokens,estimatedCostUsd:(inputTokens*.30+outputTokens*2.50)/1e6,attemptsWithoutUsage:ledger.attempts.filter(a=>!known.has(a.number)).map(a=>a.number),unknownUsageCaveat:'HTTP failures expose no token usage; no zero-charge claim. Billing invoice/tier not verified.'},
    historicalFailures:poc.scenarios.filter(s=>s.attempt!==null&&s.result.origin==='deterministic_fallback').map(s=>({id:s.id,attempt:s.attempt,runVersion:s.runVersion??'initial_rich_schema',reason:s.result.provenance.fallbackReason})),
    conclusion:'This small designed synthetic dataset shows semantic reordering, not general AI superiority or clinical validity. Historical failures and earlier injection behavior are retained.',rows,mockFailureChecks};
  fs.writeFileSync(path.join(directory,'evaluation-summary.json'),JSON.stringify(summary,null,2)+'\n');
  return summary;
}
if(require.main===module)evaluateOffline().then(r=>console.log(JSON.stringify({...r,rows:'recorded in evaluation-summary.json',mockFailureChecks:r.mockFailureChecks.map(r=>({mode:r.mode,fallbackReason:r.fallbackReason}))},null,2))).catch(e=>{console.error(e.message);process.exitCode=1;});
module.exports={evaluateOffline};
