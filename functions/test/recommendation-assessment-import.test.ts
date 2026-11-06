import {describe,expect,it} from 'vitest';
import {buildBlindPackage} from '../src/modules/recommendation/recommendation-independent-evaluation-labels';
import {evaluateHumanAssessmentImport} from '../src/modules/recommendation/recommendation-assessment-import';

// These are software-test judgments, never independent human study results.
const cases=[{id:'software-test-only',kind:'content' as const,need:{exercise:'squat' as const,objective:'technique_foundations' as const,level:'beginner' as const},candidates:[{id:'candidate-a',evidence:[{kind:'instructional_focus',text:'Foundational squat setup.'}]},{id:'candidate-b',evidence:[{kind:'instructional_focus',text:'Generic fitness.'}]}],baselineIds:['candidate-b','candidate-a']}];
const seed='software-test-blind';
function forms(){const p=buildBlindPackage(cases,seed);return p.forms.map(f=>({...f,independent:true,blinded:true,items:f.items.map(i=>({...i,grade:p.privateKey.find(k=>k.itemId===i.itemId)!.candidateId==='candidate-a'?3:0,rationale:'Software fixture judgment, not a human assessment.'}))}));}
describe('offline future human-assessment import',()=>{
 it('maps frozen blind item IDs to exact eligible candidates and measures the existing baseline only',()=>{
  const [a,b]=forms(),result=evaluateHumanAssessmentImport(cases,seed,a,b);
  expect(result.status).toBe('complete');expect(result.networkCalls).toBe(0);expect(result.providerCalls).toBe(0);
  expect(result.rows[0]).toMatchObject({id:'software-test-only',labels:{'candidate-a':3,'candidate-b':0},semantic:null,hybrid:null,baseline:{precisionAt1:0,precisionAt3:.5,nDcgAt3:expect.any(Number),validTargetRate:1}});
  expect(result.claim).toContain('not verified');
 });
 it('keeps blank forms unjudged and rejects packet mismatch',()=>{
  const blank=buildBlindPackage(cases,seed).forms;
  expect(()=>evaluateHumanAssessmentImport(cases,seed,blank[0],blank[1])).toThrow('incomplete_assessment');
  const [a,b]=forms();expect(()=>evaluateHumanAssessmentImport(cases,seed,{...a,packetId:'changed'},b)).toThrow('assessment_packet_mismatch');
 });
 it('emits disagreements without inventing labels and accepts exact independent adjudication',()=>{
  const [a,b]=forms();b.items[0].grade=a.items[0].grade===0?2:1;
  const pending=evaluateHumanAssessmentImport(cases,seed,a,b);expect(pending.status).toBe('awaiting_adjudication');expect(pending.rows).toEqual([]);
  const done=evaluateHumanAssessmentImport(cases,seed,a,b,{adjudicatorId:'software-third-person',items:[{...a.items[0],rationale:'Software test adjudication only.'}]});
  expect(done.status).toBe('complete');expect(done.rows).toHaveLength(1);
 });
 it('refuses same assessors, unblinded declarations, extra fields, and invalid source baseline targets',()=>{
  const [a,b]=forms();
  expect(()=>evaluateHumanAssessmentImport(cases,seed,a,{...b,assessorId:a.assessorId})).toThrow('distinct_assessors_required');
  expect(()=>evaluateHumanAssessmentImport(cases,seed,{...a,blinded:false},b)).toThrow('independent_blind_assessment_required');
  expect(()=>evaluateHumanAssessmentImport(cases,seed,{...a,extra:'ignored'},b)).toThrow('invalid_assessment');
  expect(()=>evaluateHumanAssessmentImport([{...cases[0],baselineIds:['invented']}],seed,a,b)).toThrow('invalid_baseline_targets');
 });
 it('retains null empty-set metrics and groups the three ranking methods separately',()=>{
  const empty=[{...cases[0],id:'empty-control',candidates:[],baselineIds:[]}],p=buildBlindPackage(empty,seed);
  const [a,b]=p.forms.map(f=>({...f,independent:true,blinded:true}));
  const result=evaluateHumanAssessmentImport(empty,seed,a,b);
  expect(result.rows[0].baseline).toMatchObject({precisionAt1:null,precisionAt3:null,nDcgAt3:null});
  expect(result.summary).toMatchObject({baseline:{precisionAt1:{mean:null,n:0,missing:1}},semantic:null,hybrid:null});
 });
});
