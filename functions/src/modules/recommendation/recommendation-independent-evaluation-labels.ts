import {createHash} from 'node:crypto';
import {exactKeys,isRecord,type LearningNeed} from './recommendation-ranking-contracts';

export interface BlindCase {id:string;kind:'trainer'|'content';need:LearningNeed;candidates:{id:string;evidence:{kind:string;text:string}[]}[]}
export interface BlindPacket {schemaVersion:1;packetId:string;rubricVersion:'module13-relevance-0-3-v1';cases:{caseId:string;kind:'trainer'|'content';need:LearningNeed;items:{itemId:string;evidence:{kind:string;text:string}[]}[]}[]}
export interface Assessment {schemaVersion:1;packetId:string;rubricVersion:'module13-relevance-0-3-v1';assessorId:string;independent:boolean;blinded:boolean;items:{itemId:string;grade:number|null;rationale:string}[]}
export interface Adjudication {adjudicatorId:string;items:{itemId:string;grade:number;rationale:string}[]}
const hash=(text:string)=>createHash('sha256').update(text).digest('hex');
/** Send only assessorPacket plus one form to each assessor; the private key stays with the custodian. */
export function buildBlindPackage(cases:readonly BlindCase[],seed:string){
  if(!seed||new Set(cases.map(c=>c.id)).size!==cases.length||cases.some(c=>new Set(c.candidates.map(x=>x.id)).size!==c.candidates.length))throw Error('invalid_blind_cases');
  const privateKey:{caseId:string;itemId:string;sourceCaseId:string;candidateId:string}[]=[];
  const sorted=[...cases].sort((a,b)=>hash(seed+a.id).localeCompare(hash(seed+b.id)));
  const assessorPacket:BlindPacket={schemaVersion:1,packetId:'',rubricVersion:'module13-relevance-0-3-v1',cases:sorted.map((c,i)=>{
    const caseId=`S${String(i+1).padStart(3,'0')}`;
    const candidates=[...c.candidates].sort((a,b)=>hash(seed+c.id+a.id).localeCompare(hash(seed+c.id+b.id)));
    return{caseId,kind:c.kind,need:{...c.need},items:candidates.map((candidate,j)=>{
      const itemId=`${caseId}-I${j+1}`;privateKey.push({caseId,itemId,sourceCaseId:c.id,candidateId:candidate.id});
      return{itemId,evidence:candidate.evidence.map(e=>({kind:e.kind,text:e.text}))};
    })};
  })};
  assessorPacket.packetId=hash(JSON.stringify({rubricVersion:assessorPacket.rubricVersion,cases:assessorPacket.cases}));
  const forms:Assessment[]=['assessor-A','assessor-B'].map(assessorId=>({schemaVersion:1,packetId:assessorPacket.packetId,rubricVersion:assessorPacket.rubricVersion,assessorId,independent:false,blinded:false,items:privateKey.map(k=>({itemId:k.itemId,grade:null,rationale:''}))}));
  return{assessorPacket,privateKey,forms};
}
function validateItems(value:unknown,expected:readonly string[]):asserts value is {itemId:string;grade:number;rationale:string}[]{
  if(!Array.isArray(value)||value.length!==expected.length||new Set(value.map(i=>i?.itemId)).size!==expected.length||value.some(i=>!isRecord(i)||!exactKeys(i,['itemId','grade','rationale'])||!expected.includes(i.itemId as string)))throw Error('assessment_coverage');
  for(const item of value){
    if(item.grade===null||typeof item.rationale!=='string'||!item.rationale.trim())throw Error('incomplete_assessment');
    if(!Number.isInteger(item.grade)||item.grade<0||item.grade>3)throw Error('invalid_grade');
    if(item.rationale.length>2000)throw Error('invalid_rationale');
  }
}
export function validateAssessment(value:unknown,packet:BlindPacket):Assessment & {items:{itemId:string;grade:number;rationale:string}[]}{
  if(!isRecord(value)||!exactKeys(value,['schemaVersion','packetId','rubricVersion','assessorId','independent','blinded','items'])||value.schemaVersion!==1||value.rubricVersion!==packet.rubricVersion||typeof value.assessorId!=='string'||!value.assessorId.trim())throw Error('invalid_assessment');
  if(value.packetId!==packet.packetId)throw Error('assessment_packet_mismatch');
  // Incomplete forms remain incomplete even before independence declarations are made.
  validateItems(value.items,packet.cases.flatMap(c=>c.items.map(i=>i.itemId)));
  if(value.independent!==true||value.blinded!==true)throw Error('independent_blind_assessment_required');
  return value as unknown as Assessment & {items:{itemId:string;grade:number;rationale:string}[]};
}
export function reconcileAssessments(a:unknown,b:unknown,packet:BlindPacket,adjudication?:Adjudication){
  const first=validateAssessment(a,packet),second=validateAssessment(b,packet);
  if(first.assessorId.trim()===second.assessorId.trim())throw Error('distinct_assessors_required');
  const disagreements=first.items.filter(i=>i.grade!==second.items.find(j=>j.itemId===i.itemId)!.grade).map(i=>({itemId:i.itemId,first:i.grade,second:second.items.find(j=>j.itemId===i.itemId)!.grade}));
  const resolved:Record<string,number>={};
  for(const item of first.items)if(!disagreements.some(d=>d.itemId===item.itemId))resolved[item.itemId]=item.grade;
  if(adjudication){
    if(typeof adjudication.adjudicatorId!=='string'||!adjudication.adjudicatorId.trim()||[first.assessorId.trim(),second.assessorId.trim()].includes(adjudication.adjudicatorId.trim()))throw Error('distinct_adjudicator_required');
    if(!isRecord(adjudication)||!exactKeys(adjudication,['adjudicatorId','items']))throw Error('invalid_adjudication');
    validateItems(adjudication.items,disagreements.map(d=>d.itemId));
    for(const item of adjudication.items)resolved[item.itemId]=item.grade;
  }
  const complete=!disagreements.length||!!adjudication;
  return{status:complete?'complete':'awaiting_adjudication',disagreements,agreement:packet.cases.flatMap(c=>c.items).length?1-disagreements.length/first.items.length:null,resolvedLabels:complete?resolved:null};
}
