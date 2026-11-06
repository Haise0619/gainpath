import type {RecommendationRankingResult} from './recommendation-engine';
export type RelevanceLabels=Readonly<Record<string,0|1|2|3>>;
export function rankingQuality(ids:readonly string[],labels:RelevanceLabels):{precisionAt1:number|null;precisionAt3:number|null;nDcgAt3:number|null}{
  if(new Set(ids).size!==ids.length||ids.some(id=>!Object.hasOwn(labels,id))||Object.values(labels).some(v=>!Number.isInteger(v)||v<0||v>3))throw Error('invalid_evaluation_labels');
  if(!ids.length)return{precisionAt1:null,precisionAt3:null,nDcgAt3:null};
  const dcg=(grades:number[])=>grades.slice(0,3).reduce((sum,r,i)=>sum+(2**r-1)/Math.log2(i+2),0);
  const ideal=dcg(Object.values(labels).sort((a,b)=>b-a));
  return{precisionAt1:Number(labels[ids[0]]>0),precisionAt3:ids.length<3?null:ids.slice(0,3).filter(id=>labels[id]>0).length/3,
    nDcgAt3:ideal?dcg(ids.map(id=>labels[id]))/ideal:null};
}
/** Published standard text rates verified 1 Nov 2026. Estimate, never an invoice or quota assertion. */
export function estimateGeminiCostUsd(result:RecommendationRankingResult):number|null{
  const p=result.provenance,u=p.usage;
  if(!p.model?.startsWith('gemini-3.5-flash-lite')||u.inputTokens===null||u.outputTokens===null)return null;
  const output=Math.max(u.outputTokens+(u.thinkingTokens??0),u.totalTokens===null?0:u.totalTokens-u.inputTokens);
  return(u.inputTokens*.30+output*2.50)/1_000_000;
}
export function evaluateRankingResult(result:RecommendationRankingResult,labels:RelevanceLabels,inferenceMeasurement:'mock'|'real_gemini'|'not_measured'='not_measured'){
  const before=result.baseline.map(r=>r.id),after=result.final.map(r=>r.id);
  return{baseline:rankingQuality(before,labels),final:rankingQuality(after,labels),candidateValidity:after.length?after.filter(id=>before.includes(id)).length/after.length:1,
    candidateCount:before.length,returnedCount:after.length,orderChanged:JSON.stringify(before)!==JSON.stringify(after),
    aiReordered:result.origin==='ai_reranked'&&JSON.stringify(before)!==JSON.stringify(after),outputValid:result.provenance.validationStatus==='valid'?true:result.provenance.validationStatus==='invalid'?false:null,
    fallback:result.origin==='deterministic_fallback',abstained:result.status==='abstained',origin:result.origin,latencyMillis:result.provenance.latencyMillis,
    usage:result.provenance.usage,estimatedCostUsd:estimateGeminiCostUsd(result),inferenceMeasurement};
}
