import {describe,it,expect} from 'vitest';
import {validatePlannerOutput,validateOutreachOutput,aggregateActivity} from '../src/modules/recommendation/admin-ai-assistance';

const exercise={id:'squat',name:'Squat',difficulty:'Beginner',category:'Compound Lower-Body',equipment:'Bodyweight',muscleGroup:'Legs',executionMode:'aiTracked',revision:1};
const draft={type:'exercise',name:'Glute Bridge',canonicalName:'Glute Bridge',aliases:[],variantOfExerciseId:'',variantDifference:'',description:'Beginner floor movement.',contentGap:'Adds hip extension.',whyRecommended:'Expands beginner hip extension options.',difficulty:'Beginner',category:'Accessory',primaryMuscleGroup:'Glutes',equipment:'Bodyweight',instructions:['Lie on the floor.','Lift and lower slowly.'],evidenceKeys:['catalog_count']};

describe('Admin AI contracts',()=>{
  it('accepts supported drafts and derives evidence from server facts',()=>{
    const result=validatePlannerOutput({summary:'Expand catalog variety.',suggestions:[draft,{...draft,name:'Heel Slide',canonicalName:'Heel Slide'},{...draft,name:'Dead Bug',canonicalName:'Dead Bug'}]},'exercise',[exercise],[],{catalog_count:'1 active exercise'});
    expect(result.suggestions[0].evidence).toEqual(['1 active exercise']);
    expect(result.suggestions[0].sources).toEqual([]);
  });
  it('rejects existing names and unknown routine exercise IDs',()=>{
    expect(()=>validatePlannerOutput({summary:'A',suggestions:[{...draft,name:'Squat'}]},'exercise',[exercise],[],{})).toThrow();
    expect(()=>validatePlannerOutput({summary:'A',suggestions:[{...draft,type:'routine',exercises:[{exerciseId:'fake',sets:3,reps:10,restSeconds:60}]}]},'routine',[exercise],[],{})).toThrow();
  });
  it('rejects invented evidence and duplicate suggestions',()=>{
    expect(()=>validatePlannerOutput({summary:'A',suggestions:[draft]},'exercise',[exercise],[],{})).toThrow();
    expect(()=>validatePlannerOutput({summary:'A',suggestions:[draft,draft]},'exercise',[exercise],[],{catalog_count:'1'})).toThrow();
  });
  it('maps only valid targets and drops unsupported optional evidence',()=>{
    const candidates=[{id:'T1',kind:'content',factors:['experience_match']}];
    expect(validateOutreachOutput({recommendations:[{candidateId:'T1',message:'Review this tutorial.',evidenceKeys:['experience_match']}]},candidates)).toHaveLength(1);
    expect(()=>validateOutreachOutput({recommendations:[{candidateId:'fake',message:'A',evidenceKeys:[]}]},candidates)).toThrow();
    expect(validateOutreachOutput({recommendations:[{candidateId:'T1',message:'A',evidenceKeys:['goal_match']}]},candidates)[0].evidenceKeys).toEqual([]);
  });
  it('excludes test and synthetic activity and deduplicates sessions',()=>{
    const now=Date.now();
    const rows=[{id:'a',data:{endedAtMillis:now-1,exerciseId:'squat'}},{id:'a',data:{endedAtMillis:now-1,exerciseId:'squat'}},{id:'b',data:{endedAtMillis:now-1,exerciseId:'squat',synthetic:true}}];
    expect(aggregateActivity(rows,now,30).workouts).toBe(1);
  });
});
