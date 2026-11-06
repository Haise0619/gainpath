import {InputValidationError,requiredIdentifier} from '../../platform/validation';
import {object,keys,canonical} from './workout-backup-validation';
import {parseExercisePrescription,AI_EXERCISE_IDS} from '../content/exercise-execution';

function targetOf(row:Record<string,unknown>):Record<string,unknown>{const {executionMode,...target}=parseExercisePrescription(row);void executionMode;return target;}
const invalid=()=>new InputValidationError('Invalid timed routine backup.');
function integer(v:unknown,min=0,max=Number.MAX_SAFE_INTEGER):number {if(!Number.isSafeInteger(v)||Number(v)<min||Number(v)>max)throw invalid();return Number(v);}
function list(v:unknown,max:number):unknown[]{if(!Array.isArray(v)||v.length>max)throw invalid();return v;}
function time(v:unknown):number {
 if(typeof v!=='string'||!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?Z$/.test(v)||!Number.isFinite(Date.parse(v)))throw invalid();
 const fraction=/\.(\d+)Z$/.exec(v)?.[1]??'';
 return Date.parse(v)*1000+Number(fraction.padEnd(6,'0').slice(3));
}
export function validateTimedRoutineBackup(raw:unknown,id:string,org:string,uid:string):Record<string,unknown>{
 const p=object(raw);keys(p,['schemaVersion','id','organizationId','userId','routineId','planSignature','day','selectedIndex','updatedAtMicros','finished','startedAtMicros','attempt','sessions','pending','manualSets','reviewed','skipped','guidedProgress']);
 if(p.schemaVersion!==2||p.id!==id||p.organizationId!==org||p.userId!==uid||typeof p.finished!=='boolean')throw invalid();
 requiredIdentifier(p.routineId,'routineId');const day=integer(p.day,1,14),selected=integer(p.selectedIndex,0,49),updated=integer(p.updatedAtMicros);if(p.startedAtMicros!==null)integer(p.startedAtMicros,0,updated);
 const a=object(p.attempt);keys(a,['schemaVersion','id','organizationId','userId','routineId','routine','day','finished','startedAtMicros','finishedAtMicros','updatedAtMicros','entries']);
 for(const key of ['id','organizationId','userId','routineId','day','finished','startedAtMicros'])if(a[key]!==p[key])throw invalid();
 if(a.schemaVersion!==2)throw invalid();integer(a.updatedAtMicros,0,updated);if(a.finishedAtMicros!==null){integer(a.finishedAtMicros,Number(a.startedAtMicros),updated);if(!a.finished||a.startedAtMicros===null)throw invalid();}
 const r=object(a.routine);keys(r,['schemaVersion','kind','status','sourceBlueprintId','title','estimatedMinutes','exercises','difficulty'],['schemaVersion','kind','status','sourceBlueprintId','title','estimatedMinutes','exercises']);
 if(r.schemaVersion!==2||r.kind!=='routine_v2'||r.status!=='published'||typeof r.title!=='string'||!r.title.trim()||r.title.length>200||r.difficulty!==undefined&&!['Beginner','Intermediate','Advanced'].includes(String(r.difficulty)))throw invalid();requiredIdentifier(r.sourceBlueprintId,'blueprintId');integer(r.estimatedMinutes,1,240);
 const rows=list(r.exercises,50).map(object),entryIds=new Set<string>();if(!rows.length)throw invalid();
 for(const row of rows){
  keys(row,['exerciseId','dayNumber','name','category','sets','reps','cue','imageUrl','muscleGroup','videoUrl','description','coverImageUrl','difficulty','equipment','tutorialSteps','restSeconds','entryId','executionMode','durationSeconds','mediaRevision','mediaGeneration','mediaValidation'],['exerciseId','dayNumber','name','sets','entryId','executionMode','restSeconds']);
  const entry=requiredIdentifier(row.entryId,'entryId');if(entryIds.has(entry))throw invalid();entryIds.add(entry);requiredIdentifier(row.exerciseId,'exerciseId');integer(row.dayNumber,1,14);
  const target=targetOf(row);if(!['aiTracked','videoGuidedTimed','legacyManual'].includes(String(row.executionMode)))throw invalid();
  const tracker=org==='gainpath'&&AI_EXERCISE_IDS.includes(String(row.exerciseId));
  if(row.executionMode==='videoGuidedTimed'){
   if(tracker||target.durationSeconds===undefined||row.reps!==undefined)throw invalid();const stamp=object(row.mediaValidation);
   if(stamp.schemaVersion!==1||stamp.videoUrl!==row.videoUrl||stamp.generation!==row.mediaGeneration||stamp.sourceRevision!==row.mediaRevision||stamp.contentType!=='video/mp4')throw invalid();integer(row.mediaRevision);if(typeof row.mediaGeneration!=='string'||!row.mediaGeneration)throw invalid();
  }else if(target.reps===undefined||row.executionMode==='aiTracked'&&!tracker)throw invalid();
  for(const key of ['name','category','cue','imageUrl','muscleGroup','videoUrl','description','coverImageUrl','difficulty','equipment'])if(row[key]!==undefined&&(typeof row[key]!=='string'||String(row[key]).length>8000))throw invalid();
  for(const key of ['videoUrl','imageUrl','coverImageUrl'])if(row[key]&& !String(row[key]).startsWith('https://'))throw invalid();
  for(const rawStep of list(row.tutorialSteps??[],12)){const step=object(rawStep);keys(step,['title','description','imageUrl']);if(typeof step.title!=='string'||step.title.length>80||typeof step.description!=='string'||step.description.length>1200||typeof step.imageUrl!=='string'||step.imageUrl.length>2048)throw invalid();}
 }
 const expected=rows.flatMap((row,i)=>row.dayNumber===day?[i]:[]),entries=list(a.entries,50).map(object);if(!expected.length||!expected.includes(selected)||JSON.stringify(entries.map(e=>e.index))!==JSON.stringify(expected))throw invalid();
 const guided=object(p.guidedProgress),sessions=object(p.sessions),pending=object(p.pending),manual=object(p.manualSets),skipped=list(p.skipped,50).map(v=>integer(v,0,49));list(p.reviewed,50).forEach(v=>integer(v,0,49));
 for(const map of [guided,sessions,pending,manual])for(const key of Object.keys(map))if(!/^\d{1,2}$/.test(key)||!expected.includes(Number(key)))throw invalid();
 const captures:string[]=[],runs=new Set<string>();
 for(const e of entries){const i=Number(e.index),row=rows[i],g=guided[String(i)];
  if(row.executionMode==='videoGuidedTimed'){
   keys(e,['kind','index','status','guided'],['kind','index','status']);if(e.kind!=='timed'||sessions[String(i)]!==undefined||pending[String(i)]!==undefined||Number(manual[String(i)]??0)!==0||canonical(e.guided??null)!==canonical(g??null))throw invalid();
   let complete=false,started=false;
   if(g!==undefined){const t=object(g);keys(t,['runId','entryId','entryIndex','exerciseId','prescription','mediaIdentity','completionProvenance','updatedAt','startedAt','endedAt','phase','phaseBeforePause','restKind','completedSetActiveMicroseconds','currentSetActiveMicroseconds','remainingRestMicroseconds'],['runId','entryId','entryIndex','exerciseId','prescription','mediaIdentity','completionProvenance','updatedAt','phase','phaseBeforePause','restKind','completedSetActiveMicroseconds','currentSetActiveMicroseconds','remainingRestMicroseconds']);
    const run=requiredIdentifier(t.runId,'runId');if(runs.has(run))throw invalid();runs.add(run);if(t.entryId!==row.entryId||t.entryIndex!==i||t.exerciseId!==row.exerciseId||t.completionProvenance!=='timerElapsed'||t.mediaIdentity!==JSON.stringify([row.videoUrl,row.mediaRevision,row.mediaGeneration])||canonical(t.prescription)!==canonical({sets:row.sets,durationSeconds:row.durationSeconds,restSeconds:row.restSeconds}))throw invalid();
    const target=Number(row.durationSeconds)*1000000,sets=list(t.completedSetActiveMicroseconds,50);if(sets.length>Number(row.sets)||sets.some(v=>v!==target))throw invalid();const current=integer(t.currentSetActiveMicroseconds,0,target-1),rest=integer(t.remainingRestMicroseconds,0,Number(row.restSeconds)*1000000);void rest;
    const active=sets.length*target+current,up=time(t.updatedAt);if(up>updated)throw invalid();started=t.startedAt!==undefined;const start=started?time(t.startedAt):up;if(start>up||active>up-start)throw invalid();complete=sets.length===row.sets;
    if(complete&&(current!==0||t.endedAt===undefined)||!complete&&t.endedAt!==undefined)throw invalid();if(t.endedAt!==undefined&&(time(t.endedAt)<start||time(t.endedAt)>up))throw invalid();
    const phases=['loading','ready','working','resting','paused','interrupted','saving','completed'];if(!phases.includes(String(t.phase))||!phases.includes(String(t.phaseBeforePause))||!['betweenSets','midSet'].includes(String(t.restKind))||t.phase==='completed'&&!complete)throw invalid();
   }
   if(e.status!==(complete?'timerCompleted':skipped.includes(i)?'skipped':started?'timerPartial':'notStarted'))throw invalid();
  }else{
   keys(e,['index','status','sessionIds','fullRepetitions','partialRepetitions','trackedDurationMicros','manualSets']);if(!['notStarted','partial','completed','selfReportedPartial','selfReportedCompleted','instructionsReviewed','skipped'].includes(String(e.status)))throw invalid();for(const key of ['fullRepetitions','partialRepetitions','trackedDurationMicros'])integer(e[key]);integer(e.manualSets,0,Number(row.sets));if(g!==undefined)throw invalid();
   for(const capture of list(e.sessionIds,1000))captures.push(requiredIdentifier(capture,'sessionId'));
  }
 }
 if(new Set(captures).size!==captures.length)throw invalid();
 for(const [key,ids]of Object.entries(sessions)){const values=list(ids,1000).map(v=>requiredIdentifier(v,'sessionId'));const entry=entries.find(e=>e.index===Number(key))!;if(canonical(values)!==canonical(entry.sessionIds))throw invalid();}
 for(const v of Object.values(pending))requiredIdentifier(v,'sessionId');for(const [key,v]of Object.entries(manual))integer(v,0,Number(rows[Number(key)].sets));
 const signature=JSON.stringify([p.routineId,r.sourceBlueprintId,2,...rows.map(row=>[row.entryId,row.exerciseId,row.executionMode,row.dayNumber,targetOf(row),row.mediaRevision??null,row.mediaGeneration??null,row.videoUrl??null])]);if(p.planSignature!==signature)throw invalid();
 if(Buffer.byteLength(canonical(p),'utf8')>850000)throw invalid();return p;
}
