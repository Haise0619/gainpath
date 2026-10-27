import {expect,it} from 'vitest';
import {routineRewardEligibility} from '../src/modules/gamification/routine-reward-eligibility';
const routine={schemaVersion:1,kind:'routine',status:'published',exercises:[{dayNumber:1,exerciseId:'squat',sets:1,reps:5}]};
const evidence={schemaVersion:2,organizationId:'o',memberId:'m',sessionId:'s',exerciseId:'squat',publishedRoutineId:'r',status:'accepted',provenance:'real_camera',cameraView:'side',repetitions:5,trackedDurationMillis:5000,rejectedDurationMillis:0,startedAtMillis:1000,endedAtMillis:6000,acceptedAtMillis:7000,detectorId:'live',detectorVersion:'v1',scoringVersion:'v1',consentVersion:'pose-local-summary-v1'};
const tuple={organizationId:'o',exerciseId:'squat',detectorId:'live',detectorVersion:'v1',scoringVersion:'v1',cameraView:'side'};
it('default policy remains off regardless of claimed completion',()=>{
 expect(routineRewardEligibility({organizationId:'o',memberId:'m',routineId:'r',day:1,routine,sessions:[evidence],now:8000,enabledTuples:[],policy:null})).toEqual({status:'disabled'});
});
it('provisional/local metrics or unsupported model tuples cannot prove eligibility',()=>{
 const input={organizationId:'o',memberId:'m',routineId:'r',day:1,routine,sessions:[evidence],now:8000,enabledTuples:[],policy:{enabled:true,points:100,dailyPointsCap:100}};
 expect(routineRewardEligibility(input).status).toBe('unverified');
 expect(routineRewardEligibility({...input,enabledTuples:[tuple],sessions:[{...evidence,status:'provisional'}]}).status).toBe('unverified');
});
it('requires every target, unique session identity, ownership and plausible accepted evidence',()=>{
 const input={organizationId:'o',memberId:'m',routineId:'r',day:1,routine,sessions:[evidence],now:8000,enabledTuples:[tuple],policy:{enabled:true,points:100,dailyPointsCap:100}};
 expect(routineRewardEligibility(input)).toEqual({status:'eligible',points:100,sessionIds:['s']});
 for(const patch of [{memberId:'other'},{repetitions:4},{trackedDurationMillis:0},{acceptedAtMillis:9000}])expect(routineRewardEligibility({...input,sessions:[{...evidence,...patch}]}).status).not.toBe('eligible');
 expect(routineRewardEligibility({...input,sessions:[evidence,evidence]}).status).not.toBe('eligible');
});
