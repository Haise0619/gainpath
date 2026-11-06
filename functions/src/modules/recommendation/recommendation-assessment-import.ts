/** Offline assessment import. Declarations are process attestations, not authenticated human identities. */
import {buildBlindPackage,reconcileAssessments,type BlindCase,type Adjudication} from './recommendation-independent-evaluation-labels';
import {evaluateIndependentOrder,summarizeMeasurements,type IndependentLabels} from './recommendation-independent-evaluation';

export interface AssessmentImportCase extends BlindCase {baselineIds:readonly string[]}
export function evaluateHumanAssessmentImport(cases:readonly AssessmentImportCase[],seed:string,first:unknown,second:unknown,adjudication?:Adjudication){
 const packet=buildBlindPackage(cases,seed);
 for(const c of cases)if(new Set(c.baselineIds).size!==c.baselineIds.length||c.baselineIds.some(id=>!c.candidates.some(candidate=>candidate.id===id)))throw Error('invalid_baseline_targets');
 const reconciled=reconcileAssessments(first,second,packet.assessorPacket,adjudication);
 const rows=reconciled.resolvedLabels===null?[]:cases.map(c=>{
  const labels:Record<string,0|1|2|3>={};
  for(const key of packet.privateKey.filter(k=>k.sourceCaseId===c.id))labels[key.candidateId]=reconciled.resolvedLabels![key.itemId] as 0|1|2|3;
  return{id:c.id,kind:c.kind,eligibleIds:c.candidates.map(candidate=>candidate.id),labels:labels as IndependentLabels,baseline:evaluateIndependentOrder(c.baselineIds,c.candidates.map(candidate=>candidate.id),labels),semantic:null,hybrid:null};
 });
 const metrics=['precisionAt1','precisionAt3','nDcgAt3','validTargetRate','unsupportedRecommendationRate'] as const;
 return{schemaVersion:1 as const,status:reconciled.status,packetId:packet.assessorPacket.packetId,claim:'Imported independent/blind declarations; actual assessor independence and qualifications are not verified by software. No independent AI-quality claim exists until separately authorized held-out inference is measured.',networkCalls:0,providerCalls:0,disagreements:reconciled.disagreements,agreement:reconciled.agreement,rows,
  summary:reconciled.resolvedLabels===null?null:{baseline:Object.fromEntries(metrics.map(metric=>[metric,summarizeMeasurements(rows.map(row=>row.baseline[metric]))])),semantic:null,hybrid:null}};
}
