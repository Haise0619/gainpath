export const actor = { uid: 'member', token: { email_verified: true, auth_time: 100 } };
export const payload = { sessionId: 's1', userId: 'member', organizationId: 'gainpath', exerciseId: 'squat', repetitions: 2, accuracy: 90, startedAt: '2026-10-25T01:00:00.000Z', endedAt: '2026-10-25T01:00:10.000Z', summarySchemaVersion: 3, provenance: 'realCamera', poseMetrics: { schemaVersion: 1, partialRepetitions: 0, trackedDurationMicros: 8000000, rejectedDurationMicros: 0, formScorePercent: 90, scoringVersion: 'bodyweight-squat-side-v1', detectorId: 'blazepose-tflite', detectorVersion: 'v1', cameraView: 'side', consentVersion: 'pose-local-summary-v1', consentedAt: '2026-10-25T01:00:00.000Z', publishedRoutineId: 'routine', deviations: {} } };
export const command = { schemaVersion: 1, organizationId: 'gainpath', memberId: 'member', consented: true, kind: 'session', id: 's1', baseDigest: null, payload };
export function completedStandaloneBackup(id: string, repetitions: number, partialRepetitions = 0) {
  const score = { formScorePercent: 90, partialRepetitions: 0 };
  return { ...command, id, payload: {
    ...payload, sessionId: id, exerciseId: 'dumbbell-curl-side-v1', repetitions,
    poseMetrics: {
      ...payload.poseMetrics, schemaVersion: 2, publishedRoutineId: null, partialRepetitions,
      curlArms: {
        mode: 'leftOnly', targetSets: 1, completedSets: 1, repetitionsPerArm: repetitions,
        left: { ...score, repetitions, partialRepetitions },
        right: { ...score, repetitions: 0, formScorePercent: null },
      },
    },
  }};
}
export const routinePayload={schemaVersion:1,id:'r1',organizationId:'gainpath',userId:'member',routineId:'routine',planSignature:'["routine","blueprint",["squat",1,1,2]]',day:1,selectedIndex:0,updatedAtMicros:1792880000000000,finished:false,startedAtMicros:1792879990000000,sessions:{},pending:{},manualSets:{},reviewed:[],skipped:[],attempt:{schemaVersion:1,id:'r1',organizationId:'gainpath',userId:'member',routineId:'routine',routine:{schemaVersion:1,kind:'routine',status:'published',sourceBlueprintId:'blueprint',title:'Strength',estimatedMinutes:10,exercises:[{exerciseId:'squat',dayNumber:1,name:'Squat',category:'Lower body',sets:1,reps:2,cue:'Stand tall',imageUrl:'',muscleGroup:'Legs',videoUrl:'',description:'',coverImageUrl:'',difficulty:'Beginner',equipment:'',tutorialSteps:[]}]},day:1,finished:false,startedAtMicros:1792879990000000,finishedAtMicros:null,updatedAtMicros:1792880000000000,entries:[{index:0,status:'notStarted',sessionIds:[],fullRepetitions:0,partialRepetitions:0,trackedDurationMicros:0,manualSets:0}]}};
export function timedBackupFixture():Record<string,any>{
 const start=1792879990000000,end=start+45000000;
 const mediaValidation={schemaVersion:1,videoUrl:'https://example.com/video.mp4',generation:'123',sourceRevision:1,contentType:'video/mp4'};
 const row={entryId:'entry1',exerciseId:'mobility',dayNumber:1,name:'Mobility',category:'Core',sets:1,durationSeconds:45,restSeconds:30,executionMode:'videoGuidedTimed',cue:'',imageUrl:'',muscleGroup:'Core',videoUrl:mediaValidation.videoUrl,description:'',coverImageUrl:'',difficulty:'Beginner',equipment:'',tutorialSteps:[],mediaRevision:1,mediaGeneration:'123',mediaValidation};
 const guided={runId:'run1',entryId:'entry1',entryIndex:0,exerciseId:'mobility',prescription:{sets:1,durationSeconds:45,restSeconds:30},mediaIdentity:JSON.stringify([row.videoUrl,1,'123']),completionProvenance:'timerElapsed',startedAt:new Date(start/1000).toISOString(),updatedAt:new Date(end/1000).toISOString(),endedAt:new Date(end/1000).toISOString(),phase:'completed',phaseBeforePause:'working',restKind:'betweenSets',completedSetActiveMicroseconds:[45000000],currentSetActiveMicroseconds:0,remainingRestMicroseconds:0};
 const routine={...routinePayload.attempt.routine,schemaVersion:2,kind:'routine_v2',exercises:[row]};
 return {...routinePayload,schemaVersion:2,finished:true,updatedAtMicros:end,planSignature:JSON.stringify(['routine','blueprint',2,['entry1','mobility','videoGuidedTimed',1,guided.prescription,1,'123',row.videoUrl]]),guidedProgress:{'0':guided},attempt:{...routinePayload.attempt,schemaVersion:2,routine,finished:true,finishedAtMicros:end,updatedAtMicros:end,entries:[{kind:'timed',index:0,status:'timerCompleted',guided}]}};
}
