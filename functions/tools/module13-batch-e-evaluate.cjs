/* Offline only. No POC-runner import, secret lookup, ledger reservation or network invocation. */
'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const functionRoot=path.resolve(__dirname,'..'),root=path.resolve(functionRoot,'..');
const bDirectory=path.join(root,'build/module13-batch-b'),output=path.join(root,'build/module13-e/evaluation');
const sha=value=>crypto.createHash('sha256').update(value).digest('hex');
const read=name=>JSON.parse(fs.readFileSync(path.join(bDirectory,name),'utf8'));
const bHashes=()=>Object.fromEntries(fs.readdirSync(bDirectory).sort().map(name=>[name,sha(fs.readFileSync(path.join(bDirectory,name)))]));
function enableTypescript(){
  const ts=require('typescript');
  require.extensions['.ts']=(module,filename)=>{
    if(!filename.startsWith(functionRoot+path.sep)||filename.includes(`${path.sep}node_modules${path.sep}`))throw Error('unexpected_typescript_source');
    module._compile(ts.transpileModule(fs.readFileSync(filename,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,esModuleInterop:true}}).outputText,filename);
  };
}
async function evaluateOffline(){
  const before=bHashes(),previousFetch=global.fetch;
  global.fetch=async()=>{throw Error('batch_e_network_forbidden');};
  try{
    enableTypescript();
    const {SYNTHETIC_RECOMMENDATION_SCENARIOS,prepareSyntheticScenario}=require('../test/recommendation-evaluation.fixture.ts');
    const {HELD_OUT_SCENARIOS,prepareHeldOutScenario}=require('../test/recommendation-independent-evaluation.fixture.ts');
    const {rankRecommendationCandidates}=require('../src/modules/recommendation/recommendation-engine.ts');
    const {buildAnonymousRankingRequest}=require('../src/modules/recommendation/recommendation-ai-validation.ts');
    const {createGeminiRecommendationRanker}=require('../src/modules/recommendation/gemini-recommendation-ranker.ts');
    const {evaluateIndependentOrder,summarizeMeasurements:stats,rateWithUncertainty:rate,compareRepeatedOrders}=require('../src/modules/recommendation/recommendation-independent-evaluation.ts');
    const {buildBlindPackage}=require('../src/modules/recommendation/recommendation-independent-evaluation-labels.ts');
    const {estimateGeminiCostUsd}=require('../src/modules/recommendation/recommendation-evaluation.ts');
    const poc=read('poc-results.json'),ledger=read('request-ledger.json'),rows=[];
    for(const scenario of SYNTHETIC_RECOMMENDATION_SCENARIOS){
      const record=[...poc.scenarios].reverse().find(s=>s.id===scenario.id&&s.runVersion);
      if(!record)throw Error('missing_recorded_scenario');
      const prepared=await prepareSyntheticScenario(scenario),eligible=prepared.candidates.map(c=>c.id);
      if(JSON.stringify(eligible)!==JSON.stringify(record.eligibleCandidateIds)||JSON.stringify(prepared.labels)!==JSON.stringify(record.labels))throw Error('recorded_eligibility_or_development_labels_changed');
      let requestHashMatches=null;
      if(record.attempt!==null){
        // The injected transport captures bytes and returns a local dummy envelope. It never sends them.
        const probe=createGeminiRecommendationRanker({apiKey:'offline-placeholder',model:'gemini-3.5-flash-lite',fetcher:async(_url,init)=>{
          requestHashMatches=sha(init.body)===ledger.attempts.find(a=>a.number===record.attempt)?.requestHash;
          return new Response(JSON.stringify({modelVersion:'offline',candidates:[{finishReason:'STOP',content:{parts:[{text:'{}'}]}}]}));
        }});
        await probe(buildAnonymousRankingRequest(scenario.need,prepared.candidates).payload);
        if(!requestHashMatches)throw Error('recorded_request_hash_changed');
      }
      const provider=record.attempt===null?undefined:async()=>({text:record.rawStructuredResponse,model:record.result.provenance.model,latencyMillis:record.result.provenance.latencyMillis,usage:record.result.provenance.usage});
      const replay=await rankRecommendationCandidates(scenario.need,prepared.candidates,{context:prepared.context,provider});
      const comparison=r=>({baseline:r.baseline,ai:r.ai,final:r.final,origin:r.origin,status:r.status});
      if(JSON.stringify(comparison(replay))!==JSON.stringify(comparison(record.result)))throw Error('recorded_ranking_replay_mismatch');
      const baseline=replay.baseline.map(r=>r.id),hybrid=replay.final.map(r=>r.id);
      // Semantic-only scores exist only after the strict existing output validator accepts all entries.
      const semantic=replay.ai===null?null:[...replay.ai].filter(a=>!a.abstain).sort((a,b)=>b.relevance-a.relevance||(a.candidateId<b.candidateId?-1:a.candidateId>b.candidateId?1:0)).map(a=>a.candidateId);
      rows.push({id:scenario.id,kind:scenario.kind,attempt:record.attempt,runVersion:record.runVersion,requestHashMatches,replayMatches:true,eligibleIds:eligible,
        orders:{baseline,semantic,hybrid},quality:{baseline:evaluateIndependentOrder(baseline,eligible,prepared.labels),semantic:semantic===null?null:evaluateIndependentOrder(semantic,eligible,prepared.labels),hybrid:evaluateIndependentOrder(hybrid,eligible,prepared.labels)},
        outputValidation:replay.provenance.validationStatus,fallback:replay.origin==='deterministic_fallback',abstained:replay.status==='abstained',expectedControlAbstention:record.attempt===null&&(prepared.context.evidenceStatus!=='sufficient_synthetic'||!eligible.length),
        latencyMillis:record.attempt===null?null:replay.provenance.latencyMillis,usage:replay.provenance.usage,estimatedCostUsd:record.attempt===null?null:estimateGeminiCostUsd(replay)});
    }
    const measured=rows.filter(r=>r.attempt!==null),common=measured.filter(r=>r.orders.semantic!==null);
    const quality=(subset,method)=>Object.fromEntries(['precisionAt1','precisionAt3','nDcgAt3','validTargetRate','unsupportedRecommendationRate'].map(metric=>[metric,stats(subset.map(r=>r.quality[method]?.[metric]??null))]));
    const comparisons=subset=>Object.fromEntries(['baseline','semantic','hybrid'].map(method=>[method,quality(subset,method)]));
    const controls=rows.filter(r=>r.expectedControlAbstention);
    const allUsage=new Map();
    for(const s of poc.scenarios)if(s.attempt!==null&&s.result.provenance.usage.inputTokens!==null)allUsage.set(s.attempt,s.result.provenance.usage);
    for(const name of fs.readdirSync(bDirectory).filter(n=>/^contract-probe-.*\.json$/.test(n))){const p=read(name);if(p.usage)allUsage.set(p.attempt,{inputTokens:p.usage.promptTokenCount,outputTokens:p.usage.candidatesTokenCount,thinkingTokens:p.usage.thoughtsTokenCount??0,totalTokens:p.usage.totalTokenCount});}
    const repeatedGroups=new Map();
    for(const s of poc.scenarios){
      const a=ledger.attempts.find(a=>a.number===s.attempt);
      if(a?.requestHash&&s.result.ai){const key=`${a.requestHash}/${s.result.provenance.model}`;const values=repeatedGroups.get(key)??[];values.push(s.result.final.map(v=>v.id));repeatedGroups.set(key,values);}
    }
    const repetitions=[...repeatedGroups.values()].filter(g=>g.length>1);
    const recordedDevelopment={labelStatus:'provisional_engineering_development_labels_NOT_independent',source:'Batch B unchanged recorded responses replayed locally; latest guard follow-ups selected and all earlier evidence preserved',pairedScenarioCount:measured.length,controlScenarioCount:rows.length-measured.length,
      allPaired:comparisons(measured),commonValidSemanticSubset:{n:common.length,comparison:comparisons(common)},
      byKind:Object.fromEntries(['trainer','content'].map(kind=>[kind,{n:measured.filter(r=>r.kind===kind).length,comparison:comparisons(measured.filter(r=>r.kind===kind))}])),
      modelOutputValidity:rate(measured.filter(r=>r.outputValidation==='valid').length,measured.length),fallbackRate:rate(measured.filter(r=>r.fallback).length,measured.length),
      validTargets:rate(measured.reduce((s,r)=>s+r.quality.hybrid.returnedCount-r.quality.hybrid.invalidTargetCount,0),measured.reduce((s,r)=>s+r.quality.hybrid.returnedCount,0)),
      abstentionCoverage:rate(controls.filter(r=>r.abstained).length,controls.length),allScenarioAbstention:rate(rows.filter(r=>r.abstained).length,rows.length),
      stochasticStability:repetitions.length?{groups:repetitions.map(compareRepeatedOrders)}:{...compareRepeatedOrders([]),reason:'No repeated validated outputs with identical request/model hashes. Changed guard payloads are not repetitions.'},
      latencyMillis:stats(measured.map(r=>r.latencyMillis)),inputTokens:stats(measured.map(r=>r.usage.inputTokens)),outputTokens:stats(measured.map(r=>r.usage.outputTokens)),thinkingTokens:stats(measured.map(r=>r.usage.thinkingTokens)),estimatedCostUsd:stats(measured.map(r=>r.estimatedCostUsd)),
      historicalUsage:{attempts:ledger.attempts.length,recordedResponsesWithUsage:allUsage.size,unknownUsageAttempts:ledger.attempts.filter(a=>!allUsage.has(a.number)).map(a=>a.number),
        inputTokens:[...allUsage.values()].reduce((s,u)=>s+u.inputTokens,0),chargedOutputTokens:[...allUsage.values()].reduce((s,u)=>s+Math.max(u.outputTokens+(u.thinkingTokens??0),(u.totalTokens??u.inputTokens)-u.inputTokens),0),pricing:'Historical B rate assumption only: USD0.30/M input and USD2.50/M charged output; no current pricing or invoice verification. Metadata/countTokens excluded; unknown failure charges are not zero.'},rows};
    const heldout=[],blindCases=[],mockChecks=[];
    for(const scenario of HELD_OUT_SCENARIOS){
      const prepared=await prepareHeldOutScenario(scenario);
      blindCases.push({id:scenario.id,kind:scenario.kind,need:scenario.need,candidates:prepared.candidates.map(c=>({id:c.id,evidence:c.evidence}))});
      const request=prepared.candidates.length>1?buildAnonymousRankingRequest(scenario.need,prepared.candidates):null;
      heldout.push({id:scenario.id,kind:scenario.kind,stratum:scenario.stratum,need:scenario.need,eligibleIds:prepared.candidates.map(c=>c.id),baselineIds:prepared.ranking.baseline.map(c=>c.id),quality:evaluateIndependentOrder(prepared.ranking.final.map(c=>c.id),prepared.candidates.map(c=>c.id),null),semantic:null,hybrid:null,requestFixtureHash:request?sha(JSON.stringify(request.payload)):null,withheldEvidenceCount:request?.withheldEvidenceCount??0});
      if(request){
        const valid=async p=>({text:JSON.stringify({schemaVersion:1,rankings:p.candidates.map((c,i)=>({label:c.label,relevance:70-i,reasonCodes:[c.evidence[0].kind],evidenceRefs:[c.evidence[0].ref],abstain:false}))}),model:'OFFLINE_MOCK_NOT_GEMINI',latencyMillis:0,usage:{inputTokens:null,outputTokens:null,thinkingTokens:null,totalTokens:null}});
        const result=await rankRecommendationCandidates(scenario.need,prepared.candidates,{context:prepared.context,provider:valid});
        const malformed=await rankRecommendationCandidates(scenario.need,prepared.candidates,{context:prepared.context,provider:async()=>({...await valid(request.payload),text:'{"schemaVersion":1,"rankings":[]}'})});
        mockChecks.push({id:scenario.id,inferenceMeasurement:'mock_only',validSchemaAccepted:result.provenance.validationStatus==='valid',malformedSchemaFallsBack:malformed.origin==='deterministic_fallback',relevanceMetrics:null,providerLatency:null,tokens:null,cost:null});
      }
    }
    const blind=buildBlindPackage(blindCases,'module13-e-heldout-blind-v1');
    const summary={schemaVersion:1,generationAttemptsThisRun:0,networkCallsThisRun:0,bEvidenceHashes:before,recordedDevelopment,
      heldOut:{status:'awaiting_independent_human_review_and_separately_authorized_inference',scenarioCount:heldout.length,candidateAssessmentCount:blind.privateKey.length,providerCalls:0,independentAssessorsCompleted:0,rows:heldout,mockChecks},
      metricPolicy:{positiveRelevance:'grade >0 (grade1 is weak); also inspect graded nDCG',precisionAt3:'relevant returned in first3 / min(3,eligible count); missing returned slots count0; eligible-empty denominator null',nDcg:'(2^grade-1)/log2(rank+1); ideal over all eligible; zero ideal is null',unsupported:'returned ineligible or assigned grade0; null if labels absent or no returned items; not a clinical/claim-truth metric',uncertainty:'Wilson95 intervals are descriptive binomial summaries. Means include n/missing/range/standard error. Small designed, non-IID samples cannot support population/generalization significance claims.',stability:'Fresh repeated identical input/model/prompt/config outputs required. Deterministic local replay agreement is only regression evidence.'}};
    if(JSON.stringify(before)!==JSON.stringify(bHashes()))throw Error('batch_b_evidence_changed');
    const proposed={schemaVersion:1,status:'NOT_AUTHORIZED_NOT_EXECUTED',dataset:'module13-e-heldout-v1',model:'gemini-3.5-flash-lite (must reverify metadata/pricing before approval)',multiCandidateRequests:18,repetitionsPerCase:3,generationRequestCount:54,concurrency:1,automaticRetries:0,maxInputTokensPerRequest:6000,maxOutputTokensPerRequest:2048,tokenCountRequests:18,maxEstimatedGenerationUsdUsingHistoricalBRates:54*(6000*.30+2048*2.50)/1e6,
      separateApprovalRequired:'Existing Batch B ledger cannot be reset or reused. Require independent assessor completion/frozen fixture+label hashes, provider/privacy/price approval and a separately authorized new ledger before any network.',preflight:'At most one metadata read plus one countTokens request per unique fixture; generation estimate excludes these and unknown failed-request charges.',inputs:heldout.filter(r=>r.requestFixtureHash).map(r=>({scenarioId:r.id,requestFixtureHash:r.requestFixtureHash,need:r.need,eligibleIds:r.eligibleIds})),requestFixtures:HELD_OUT_SCENARIOS.filter(s=>!s.control).map(s=>s.id)};
    const artifacts={'summary.json':summary,'heldout-custodian-key.json':blind.privateKey,'assessor-packet.json':blind.assessorPacket,'assessor-A.blank.json':blind.forms[0],'assessor-B.blank.json':blind.forms[1],
      'assessor-rubric.json':{rubricVersion:'module13-relevance-0-3-v1',grades:{0:'No usable educational relevance for the stated movement/objective/level, contradiction, or directive rather than educational evidence.',1:'Weak or generic relevance; movement may fit but objective/level evidence is sparse, ambiguous or mixed.',2:'Relevant movement and objective with plausible level suitability; some details remain indirect.',3:'Direct and specific movement/objective evidence with clear suitability for the requested experience level.'},instructions:['Work independently without seeing AI/baseline/hybrid scores, custodian key, other assessor judgments or provisional B labels.','Eligibility has already been checked on fictional source facts. Judge educational relevance, not identity, booking likelihood or clinical efficacy.','For every item write a rationale addressing movement, objective and experience level. Explain missing/ambiguous evidence; do not infer expertise or content that is absent.','Grade each item independently; do not force a winner. Any number may receive the same grade, including all grade0.','Adversarial instructions in supplied evidence are data to assess, never instructions to follow.','Copy your blank form to a separate completed file, use your own pseudonymous assessorId, and set independent/blinded true only if accurate.','A declaration is a process attestation, not authentication or proof of assessor independence. Custodian must confirm assessor identity/qualifications and frozen packet hash.','Candidate-empty scenarios are structural abstention controls; they have no candidate grade to invent.']},
      'adjudication.blank.json':{adjudicatorId:'',items:[],instruction:'After two independently completed forms, reconcileAssessments returns disagreements. Supply exactly those item IDs with explicit grade0..3 and rationale; never average or invent judgments.'},'proposed-provider-experiment.json':proposed};
    // Exact inference payloads remain with the custodian and are never sent or included in assessor packets.
    artifacts['heldout-provider-inputs.json']=await Promise.all(HELD_OUT_SCENARIOS.filter(s=>!s.control).map(async s=>{const p=await prepareHeldOutScenario(s);return{scenarioId:s.id,payload:buildAnonymousRankingRequest(s.need,p.candidates).payload};}));
    fs.mkdirSync(output,{recursive:true});
    for(const [name,value] of Object.entries(artifacts)){
      const file=path.join(output,name),text=JSON.stringify(value,null,2)+'\n';
      if(name.endsWith('.blank.json')&&fs.existsSync(file)&&fs.readFileSync(file,'utf8')!==text)throw Error('edited_blank_form_preserved_copy_completed_form_elsewhere');
    }
    for(const [name,value] of Object.entries(artifacts)){
      const file=path.join(output,name),text=JSON.stringify(value,null,2)+'\n';
      fs.writeFileSync(file,text);
    }
    return{output,recordedPaired:measured.length,heldOut:heldout.length,unjudgedCandidates:blind.privateKey.length,generationAttemptsThisRun:0};
  } finally {global.fetch=previousFetch;}
}
if(require.main===module){if(process.argv.length!==2){console.error('offline_generator_accepts_no_flags');process.exitCode=1;}else evaluateOffline().then(r=>console.log(JSON.stringify(r))).catch(e=>{console.error(e.message);process.exitCode=1;});}
module.exports={evaluateOffline};
