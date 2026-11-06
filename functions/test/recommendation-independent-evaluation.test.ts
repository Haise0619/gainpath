import {describe, expect, it} from 'vitest';
import {evaluateIndependentOrder, summarizeMeasurements, rateWithUncertainty, compareRepeatedOrders} from '../src/modules/recommendation/recommendation-independent-evaluation';
import {buildBlindPackage, validateAssessment, reconcileAssessments} from '../src/modules/recommendation/recommendation-independent-evaluation-labels';

describe('independent evaluation metric contracts', () => {
  it('uses eligible effective K and penalizes short output without pretending empty sets are perfect', () => {
    expect(evaluateIndependentOrder(['a'], ['a', 'b'], {a:3,b:0})).toMatchObject({precisionAt1:1,precisionAt3:.5,effectiveK:2,validTargetRate:1,unsupportedRecommendationRate:0});
    expect(evaluateIndependentOrder(['a','b'], ['a','b'], {a:3,b:0}).nDcgAt3).toBe(1);
    expect(evaluateIndependentOrder([], [], {})).toMatchObject({precisionAt1:null,precisionAt3:null,nDcgAt3:null,validTargetRate:null,unsupportedRecommendationRate:null});
    expect(evaluateIndependentOrder([], ['a'], {a:3})).toMatchObject({precisionAt1:0,precisionAt3:0,nDcgAt3:0});
  });
  it('counts invalid targets separately from human irrelevance and never treats absent grades as zero', () => {
    expect(evaluateIndependentOrder(['x','b'], ['a','b'], {a:3,b:0})).toMatchObject({validTargetRate:.5,unsupportedRecommendationRate:1,invalidTargetCount:1});
    expect(evaluateIndependentOrder(['a'], ['a'], null)).toMatchObject({precisionAt1:null,unsupportedRecommendationRate:null,validTargetRate:1});
    expect(() => evaluateIndependentOrder(['a','a'], ['a'], {a:3})).toThrow('duplicate_returned_target');
    expect(() => evaluateIndependentOrder(['a'], ['a','b'], {a:3})).toThrow('incomplete_labels');
    expect(() => evaluateIndependentOrder(['a'], ['a'], {a:4} as any)).toThrow('invalid_labels');
  });
  it('reports observed and missing sample counts without silently imputing missing usage', () => {
    expect(summarizeMeasurements([1,null,3])).toEqual({mean:2,n:2,missing:1,min:1,max:3,standardError:1});
    expect(summarizeMeasurements([null])).toEqual({mean:null,n:0,missing:1,min:null,max:null,standardError:null});
    expect(() => summarizeMeasurements([NaN])).toThrow();
    expect(rateWithUncertainty(0,0)).toEqual({numerator:0,denominator:0,rate:null,wilson95:null});
    const rate=rateWithUncertainty(1,2);expect(rate.rate).toBe(.5);expect(rate.wilson95![0]).toBeCloseTo(.09453,4);expect(rate.wilson95![1]).toBeCloseTo(.90547,4);
    expect(() => rateWithUncertainty(2,1)).toThrow();
  });
  it('requires genuine repeated identical-input observations for stability', () => {
    expect(compareRepeatedOrders([['a','b']])).toEqual({comparisons:0,exactAgreement:null,meanTop3Jaccard:null});
    const repeated=compareRepeatedOrders([['a','b'],['b','a'],['a','c']]);
    expect(repeated).toMatchObject({comparisons:3,exactAgreement:0});expect(repeated.meanTop3Jaccard).toBeCloseTo(5/9);
    expect(compareRepeatedOrders([[],[]])).toEqual({comparisons:1,exactAgreement:1,meanTop3Jaccard:1});
  });
});

const cases=[{id:'secret-case',kind:'trainer' as const,need:{exercise:'squat' as const,objective:'technique_foundations' as const,level:'beginner' as const},candidates:[{id:'secret-coach',evidence:[{kind:'instructional_focus',text:'Practice controlled squat depth.'}]}]}];
describe('independent blind assessment contracts', () => {
  it('excludes identities/rankings/grades from assessor packets and retains a separate reproducible key', () => {
    const packet=buildBlindPackage(cases,'fixed-seed');
    expect(packet).toEqual(buildBlindPackage(cases,'fixed-seed'));
    expect(JSON.stringify(packet.assessorPacket)).not.toContain('secret-');
    expect(packet.forms[0].assessorId).not.toBe(packet.forms[1].assessorId);
    expect(packet.forms[0].items[0].grade).toBeNull();
    expect(packet.privateKey).toHaveLength(1);
    expect(() => validateAssessment(packet.forms[0],packet.assessorPacket)).toThrow('incomplete_assessment');
  });
  it('rejects invalid or duplicate labels, unblinded declarations, and identical assessor identities', () => {
    const p=buildBlindPackage(cases,'seed'),form={...p.forms[0],independent:true,blinded:true,items:p.forms[0].items.map(i=>({...i,grade:3,rationale:'Direct movement, objective and beginner evidence.'}))};
    expect(validateAssessment(form,p.assessorPacket).items[0].grade).toBe(3);
    expect(()=>validateAssessment({...form,items:[{...form.items[0],grade:3.1}]},p.assessorPacket)).toThrow('invalid_grade');
    expect(()=>validateAssessment({...form,items:[...form.items,...form.items]},p.assessorPacket)).toThrow('assessment_coverage');
    expect(()=>validateAssessment({...form,blinded:false},p.assessorPacket)).toThrow('independent_blind_assessment_required');
    expect(()=>validateAssessment({...form,packetId:'different-frozen-packet'},p.assessorPacket)).toThrow('assessment_packet_mismatch');
    expect(()=>reconcileAssessments(form,form,p.assessorPacket)).toThrow('distinct_assessors_required');
  });
  it('records disagreement and requires a distinct explicit human adjudicator instead of averaging', () => {
    const p=buildBlindPackage(cases,'seed');
    const forms=p.forms.map((f,i)=>({...f,independent:true,blinded:true,items:f.items.map(item=>({...item,grade:i+1,rationale:'Human rationale covering the movement and objective.'}))}));
    const result=reconcileAssessments(forms[0],forms[1],p.assessorPacket);
    expect(result.status).toBe('awaiting_adjudication');expect(result.resolvedLabels).toBeNull();expect(result.disagreements).toHaveLength(1);
    expect(()=>reconcileAssessments(forms[0],forms[1],p.assessorPacket,{adjudicatorId:forms[0].assessorId,items:[]})).toThrow('distinct_adjudicator_required');
    expect(reconcileAssessments(forms[0],forms[1],p.assessorPacket,{adjudicatorId:'human-C',items:[{itemId:forms[0].items[0].itemId,grade:2,rationale:'Reviewed disagreement against rubric.'}]})).toMatchObject({status:'complete',resolvedLabels:{[forms[0].items[0].itemId]:2}});
  });
});
