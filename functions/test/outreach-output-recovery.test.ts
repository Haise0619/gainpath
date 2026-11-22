import {it,expect} from 'vitest';
import {validateOutreachOutput} from '../src/modules/recommendation/admin-ai-assistance';
// Anonymous reconstruction of the reported production member: flexibility/general fitness,
// intermediate, 14 workouts, 3 tutorials + 4 routines, no eligible coach.
const candidates=[1,2,3,4,5,6,7].map(n=>({id:'C'+n,kind:n<4?'content':'routine',factors:['exercise_match','recent_activity','completion']}));
it('accepts one recommendation without nonessential evidence fields',()=>{expect(validateOutreachOutput({recommendations:[{candidateId:'C1',message:'Review Squat technique from your recent practice.'}]},candidates)).toHaveLength(1);});
it('keeps independent valid items when another item has unknown ID or malformed fields',()=>{expect(validateOutreachOutput({recommendations:[{candidateId:'unknown',message:'Invalid'},{candidateId:'C1',message:'Review your recent Squat practice.'},{candidateId:'C4',message:'Explore a general training routine.'},{candidateId:'C7'}]},candidates)).toHaveLength(2);});
it('keeps first valid item per type instead of rejecting the entire response',()=>{expect(validateOutreachOutput({recommendations:[{candidateId:'C1',message:'Review technique.'},{candidateId:'C2',message:'Another tutorial.'},{candidateId:'C4',message:'Explore the routine.'}]},candidates)).toHaveLength(2);});
it('ignores unsupported optional evidence while keeping a valid choice',()=>{expect(validateOutreachOutput({recommendations:[{candidateId:'C1',message:'Review technique.',evidenceKeys:['invented','exercise_match']}]},candidates)[0].evidenceKeys).toEqual(['exercise_match']);});
it('reports precise rejection reasons when every item is unusable',()=>{expect(()=>validateOutreachOutput({recommendations:[{candidateId:'C1'}]},candidates)).toThrow('missing_message');expect(()=>validateOutreachOutput({recommendations:[{candidateId:'C99',message:'Unknown'}]},candidates)).toThrow('invalid_candidate_id');});
it('allows explicit abstention without inventing recommendations',()=>{expect(validateOutreachOutput({recommendations:[]},candidates)).toEqual([]);});
