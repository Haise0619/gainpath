import {fypDigest} from '../dataset/fyp-integrity';
import { credentialFailure } from './trainer-candidate-eligibility';
import { FieldPath, getFirestore, type Firestore } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';
import type { TransactionPort } from '../../platform/firestore/store';
import { DomainError } from '../../platform/errors';
import { digestOf, object, validateBackupPayload, validateFictionalSessionPayload } from '../workouts/workout-backup-validation';
import { exerciseTutorialProjection, supportsRoutineTutorial } from '../content/exercise-tutorial';
import {parseExercisePrescription,resolveExerciseExecution} from '../content/exercise-execution';
import { tutorialMediaUrl } from '../content/tutorial-media';
import { bookingCoachScope, bookingDaySnapshot, currentBookingMembership, currentBookingPolicy } from '../coaching/booking-validation';
import { localDate, plusDate, SLOT } from '../coaching/coach-availability-contracts';
import { memberBusySlots } from '../coaching/member-booking-conflicts';
import { recommendationPreferences } from './recommendation-personalization';
import type {MemberFitnessGoal} from './recommendation-personalization';
import { parseCanonicalTarget, queueText, type QueueTarget } from './recommendation-queue-contracts';
import {createGeminiWorkoutRecommendationRanker,rankWorkoutRecommendations,type WorkoutRankingProvider,type WorkoutRankingContext,type WorkoutRankingCandidate} from './workout-recommendation-ranking';
import type { CanonicalSuggestion, ReviewedCanonicalRuntime } from './canonical-recommendation-lifecycle';
import type { CurrentRecommendationTarget } from './recommendation-member-contracts';

const DAY = 86400000;
const MAX_AGE = 30 * DAY;
const POLICY = 'workout-backup-guidance-v1';
const EXERCISE_RULES: Readonly<Record<string, string>> = {
  F3b8xIr8ynBDd3gEICKX: 'bodyweight-squat-side-v1',
  'standing-single-arm-curl-side-v1': 'single-arm-curl-side-v1',
  'standing-calf-raise-side-v1': 'standing-calf-raise-side-v1',
  'wall-push-up-side-v1': 'wall-push-up-side-v1',
};
const identifier = (s: unknown): s is string => typeof s === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(s);

function backupSession(raw: Record<string, unknown> | undefined, org: string, member: string, key: string, now: number, boundary: number) {
  if (!raw || raw.schemaVersion !== 1 || raw.classification !== 'provisional_member_backup' ||
    raw.kind !== 'session' || raw.key !== key || !identifier(raw.id) || key !== 'session-' + raw.id ||
    typeof raw.payloadJson !== 'string' || raw.payloadJson.length > 32768) return null;
  try {
    const p = validateBackupPayload('session', raw.id, org, member, JSON.parse(raw.payloadJson));
    const ended = Date.parse(String(p.endedAt));
    if (digestOf(p) !== raw.digest || ended > now || ended < now - MAX_AGE ||
      Date.parse(String(p.startedAt)) < boundary || Number(p.repetitions) < 1) return null;
    const metrics = object(p.poseMetrics);
    const tracked = Number(metrics.trackedDurationMicros);
    const total = tracked + Number(metrics.rejectedDurationMicros);
    const exercise = String(p.exerciseId);
    const rule = EXERCISE_RULES[exercise];
    const armMode = exercise === 'standing-single-arm-curl-side-v1' && metrics.schemaVersion === 2
      ? object(metrics.curlArms).mode : null;
    const scored = rule && metrics.scoringVersion === rule && metrics.cameraView === 'side' &&
      metrics.schemaVersion === (exercise === 'standing-single-arm-curl-side-v1' ? 2 : 1) &&
      identifier(metrics.detectorId) && identifier(metrics.detectorVersion) &&
      total > 0 && tracked / total >= .6 && Number(p.repetitions) >= 3 &&
      typeof metrics.formScorePercent === 'number';
    return { exercise, ended, digest: String(raw.digest), origin: 'synced_summary' as const,
      score: scored ? metrics.formScorePercent as number : null,
      repetitions:Number(p.repetitions),
      compatibility: digestOf({exercise, scoringVersion: metrics.scoringVersion, cameraView: metrics.cameraView,
        armMode, schema: metrics.schemaVersion, detector: metrics.detectorId, version: metrics.detectorVersion}) };
  } catch { return null; }
}

async function readWorkoutSource(tx: TransactionPort, org: string, member: string, key: string,
  now: number, boundary: number, cohortRoot?: string) {
  const backup = await tx.get(`orgs/${org}/members/${member}/workoutBackups/${key}`);
  if (backup || !cohortRoot) return backupSession(backup, org, member, key, now, boundary);
  const id = key.slice('session-'.length);
  if (!identifier(id)) return null;
  const logical = `orgs/${org}/members/${member}/syntheticObservations/${id}`;
  const data = await tx.get(logical);
  const physical = `${cohortRoot}/members/${member}/syntheticObservations/${id}`;
  const ownership = await tx.get(`orgs/${org}/seedOwnership/${fypDigest(physical)}`);
  if (!data || data.schemaVersion !== 1 || data.organizationId !== org || data.memberId !== member ||
    data.observationId !== id || data.seedId !== 'gainpath-fyp-v1' || data.provenance !== 'fictional_synthetic' ||
    ownership?.path !== physical || ownership.digest !== fypDigest(data)) return null;
  try {
    const payload = validateFictionalSessionPayload(id, org, member, data.payload);
    const ended = Date.parse(String(payload.endedAt));
    if (payload.provenance !== 'recordedFixture' || digestOf(payload) !== data.digest ||
      ended !== data.observedAtMillis || ended > now || ended < now - MAX_AGE ||
      Date.parse(String(payload.startedAt)) < boundary || Number(payload.repetitions) < 1) return null;
    // Recorded sample histories supply exercise context only. They never
    // contribute a measured Form Score or become camera/backup records.
    return {exercise: String(payload.exerciseId), ended, digest: String(data.digest), score: null, repetitions:Number(payload.repetitions), origin: 'recorded_history' as const,
      compatibility: digestOf({exercise:payload.exerciseId,source:'recorded_history'})};
  } catch { return null; }
}

async function tutorial(tx: TransactionPort, org: string, target: Extract<QueueTarget, {kind: 'content'}>) {
  const d = target.destination;
  const [publication, catalog] = await Promise.all([
    tx.get(`orgs/${org}/content/${d.routineId}`), tx.get(`orgs/${org}/exerciseVideos/${d.exerciseId}`),
  ]);
  if (publication?.status !== 'published' || !supportsRoutineTutorial(publication) ||
    publication.archived === true || publication.isActive === false ||
    catalog?.isActive !== true || catalog.archived === true || !Array.isArray(publication.exercises)) return null;
  const entry = publication.exercises[d.exerciseIndex];
  if (!entry || entry.exerciseId !== d.exerciseId || (entry.dayNumber ?? 1) !== d.dayNumber || !queueText(entry.name, 120)) return null;
  try {
    const media = exerciseTutorialProjection(entry);
    if (!(Array.isArray(media.tutorialSteps) && media.tutorialSteps.length) && !tutorialMediaUrl(entry.videoUrl)) return null;
    return {target, label: entry.name, imageUrl: typeof media.imageUrl === 'string' ? media.imageUrl : null,
      specialization: null, photoPath: null,
      ...(typeof (media.difficulty??publication.difficulty)==='string'?{difficulty:String(media.difficulty??publication.difficulty)}:{})};
  } catch { return null; }
}

const GOAL_SPECIALTIES: Readonly<Record<string, readonly string[]>> = {
  buildMuscle: ['strength training', 'strength', 'hypertrophy', 'muscle building'],
  improveEndurance: ['endurance', 'cardio', 'conditioning'],
  increaseFlexibility: ['mobility', 'flexibility'],
  generalFitness: ['general fitness', 'functional training', 'beginner strength', 'strength and conditioning'],
  loseWeight: ['weight management', 'weight loss'],
  reduceStress: ['stress management'],
};
const normalized = (value: string) => value.trim().toLowerCase();
const timeBand=(minutes:number):NonNullable<WorkoutRankingContext['duration']> =>
  minutes<=20?'short':minutes<=40?'medium':'long';
const routineGoalCategories:Partial<Record<MemberFitnessGoal,RegExp>>={
  buildMuscle:/\b(strength|resistance|chest|biceps?|triceps?|shoulders?|quads?|glutes?|calf|calves|hamstrings?)\b/i,
  improveEndurance:/\b(cardio|conditioning|endurance|aerobic)\b/i,
  increaseFlexibility:/\b(mobility|flexibility|stretch(?:ing)?)\b/i,
};

async function routineTarget(tx:TransactionPort,org:string,routineId:string):Promise<CurrentRecommendationTarget|null>{
  const publication=await tx.get(`orgs/${org}/content/${routineId}`);
  if(!publication || !supportsRoutineTutorial(publication)||publication.status!=='published'||publication.archived===true||
    publication.isActive===false||![1,2].includes(Number(publication.schemaVersion))||
    !queueText(publication.sourceBlueprintId,128)||!queueText(publication.title,120)||
    !Number.isSafeInteger(publication.estimatedMinutes)||Number(publication.estimatedMinutes)<1||
    Number(publication.estimatedMinutes)>240||!Array.isArray(publication.exercises)||
    !publication.exercises.length||publication.exercises.length>50)return null;
  for(const entry of publication.exercises){
    if(!entry || !identifier(entry.exerciseId)||!queueText(entry.name,120))return null;
    const catalog=await tx.get(`orgs/${org}/exerciseVideos/${entry.exerciseId}`);
    if(catalog?.isActive!==true||catalog.archived===true)return null;
    try{
      const mode=resolveExerciseExecution(org,entry.exerciseId,catalog);
      if(publication.schemaVersion===2 && (!identifier(entry.entryId)||entry.executionMode!==mode))return null;
      parseExercisePrescription({...entry,executionMode:publication.schemaVersion===2?entry.executionMode:mode,
        restSeconds:entry.restSeconds??60});
      if(mode==='videoGuidedTimed'&&!tutorialMediaUrl(entry.videoUrl))return null;
    }catch{return null;}
  }
  const illustrated=publication.exercises.find((e:any)=>e.imageUrl||e.coverImageUrl);
  const image=publication.coverImageUrl??publication.imageUrl??illustrated?.coverImageUrl??illustrated?.imageUrl;
  return {target:{kind:'routine',organizationId:org,routineId},label:publication.title,specialization:null,
    imageUrl:typeof image==='string'?image:null,photoPath:null,
    ...(typeof publication.difficulty==='string'?{difficulty:publication.difficulty}:{}),
    durationMinutes:Number(publication.estimatedMinutes),exerciseCount:publication.exercises.length};
}

async function coachTarget(tx: TransactionPort, org: string, coachId: string, now: number,
  member: string, expectedBranch?: string): Promise<CurrentRecommendationTarget | null> {
  try {
    const root = `orgs/${org}`;
    const profile = await tx.get(`${root}/coaches/${coachId}`);
    const credential = await tx.get(`${root}/coachProfiles/${coachId}/certificationState/current`);
    if (!profile || profile.status !== 'published' || profile.certificationVerified !== true ||
      credential?.certificationVerified !== true || !Number.isSafeInteger(credential.approvedCount) ||
      Number(credential.approvedCount) < 1 || profile.approvedCertificationCount !== credential.approvedCount ||
      !queueText(profile.displayName, 80) || !queueText(profile.specialty, 80)) return null;
    if (typeof await credentialFailure(tx, root, coachId, profile, now) !== 'number') return null;
    const membership = await currentBookingMembership(tx, org, member);
    const scope = await bookingCoachScope(tx, org, coachId, membership.branchIds);
    if (expectedBranch && !scope.permitted.includes(expectedBranch)) return null;
    const policy = currentBookingPolicy(await tx.get(`${root}/settings/booking`));
    const today = localDate(now, policy.timeZone);
    for (const date of [today, plusDate(today, 1), plusDate(today, 2)]) {
      const day = await bookingDaySnapshot(tx, org, coachId, member, date, policy, scope.assigned, now);
      if (day.reservations.length >= policy.cap ||
        (day.dailyCapacityMinutes !== undefined && day.blocked.size * 30 + 30 > day.dailyCapacityMinutes)) continue;
      const busy = await memberBusySlots(tx, org, member, date, policy.timeZone, day.reservations);
      for (const slot of day.grid.slots) {
        if (slot <= now || day.blocked.has(slot) || busy.has(slot)) continue;
        const window = day.windows.find(w => scope.permitted.includes(w.branchId) &&
          (!expectedBranch || w.branchId === expectedBranch) && w.startAtMillis <= slot && w.endAtMillis >= slot + SLOT);
        if (!window) continue;
        const target: QueueTarget = {kind: 'trainer', coachId, branchId: window.branchId,
          observedStartAtMillis: slot, observedEndAtMillis: slot + SLOT};
        const prefix = `${root}/coachProfilePhotos/${coachId}/`;
        const photoPath = typeof profile.photoPath === 'string' && profile.photoPath.startsWith(prefix) &&
          /^[a-f0-9]{32}$/.test(profile.photoPath.slice(prefix.length)) ? profile.photoPath : null;
        const branch=await tx.get(`${root}/branches/${window.branchId}`);
        return {target, label: profile.displayName, specialization: profile.specialty, photoPath, imageUrl: null,
          ...(Number.isSafeInteger(profile.consultationFeeMinor)&&Number(profile.consultationFeeMinor)>=0?
            {priceMinor:Number(profile.consultationFeeMinor),currency:'MYR'}:{}),
          ...(queueText(branch?.name,120)?{branchLabel:branch.name}:{})};
      }
    }
    return null;
  } catch (error) {
    if (error instanceof DomainError && ['failed-precondition', 'permission-denied', 'invalid-argument'].includes(error.code)) return null;
    throw error;
  }
}

export function createWorkoutBackupRuntime(db: Firestore, coachIsVerified: (uid: string) => Promise<boolean>, cohortRoot?: string,
  options:{provider?:WorkoutRankingProvider;unifiedAdminPagination?:true}={}): ReviewedCanonicalRuntime {
  if (cohortRoot !== undefined && cohortRoot !== 'orgs/gainpath/cohorts/fyp-v1') throw new Error('Unsupported workout scope.');
  const physical = (logical: string) => cohortRoot ? cohortRoot + logical.slice('orgs/gainpath'.length) : logical;
  const logical = (physicalPath: string) => cohortRoot ? 'orgs/gainpath' + physicalPath.slice(cohortRoot.length) : physicalPath;
  return {
    ...(cohortRoot ? {scopedDataset: true as const} : {}),
    reviewId: POLICY,
    enabledTuples: [],
    notices: [{policyId: POLICY, noticeVersion: 'workout-backup-v1', contentVersion: 'workout-backup-v1',
      history: {mode: 'retained', earliestAtMillis: 0}}],
    maximumAgeMillis: MAX_AGE, expiresAfterMillis: 14 * DAY, cooldownMillis: 7 * DAY,
    listAcceptedIds: async () => [],
    derive: () => null,
    async personalize(suggestions,allowAi){
      const context=suggestions[0]?.ai?.context??{};
      const candidates:WorkoutRankingCandidate<CanonicalSuggestion>[]=suggestions.map(s=>({
        kind:s.target.kind,target:s,factors:s.ai?.factors??[],
        ...(s.ai?.candidateDifficulty?{difficulty:s.ai.candidateDifficulty}:{}),
        ...(s.ai?.candidateDuration?{duration:s.ai.candidateDuration}:{}),
      }));
      const ranked=await rankWorkoutRecommendations(allowAi?options.provider:undefined,context,candidates);
      return Object.values(ranked.selections).filter(selection=>selection!==undefined).map(selection=>{
        const selected=selection!.candidate.target;
        return {...selected,summary:selection!.reason??selected.summary,
          explanations:selection!.reason?[selection!.reason]:selected.explanations,
          ai:{...selected.ai!,method:selection!.method,factors:[...selection!.factors],
            changedOrder:selection!.changedOrder,candidateCount:selection!.ranking.length,
            ...(ranked.inference?{model:ranked.inference.model,latencyMillis:ranked.inference.latencyMillis,
              inputTokens:ranked.inference.usage.inputTokens,outputTokens:ranked.inference.usage.outputTokens,
              thinkingTokens:ranked.inference.usage.thinkingTokens,totalTokens:ranked.inference.usage.totalTokens,
              providerSource:ranked.inference.providerSource,cacheHit:ranked.inference.cacheHit}:{}),
            ...(ranked.failure?{fallbackReason:ranked.failure}:!allowAi?{fallbackReason:'ai_consent_required'}:
              !options.provider?{fallbackReason:'provider_not_configured'}:{})}};
      });
    },
    async listIds(_tx, org, member, afterId) {
      const collection = db.collection(physical(`orgs/${org}/canonicalRecommendations`));
      if(!member){
        let query=collection.orderBy('createdAtMillis','desc').orderBy(FieldPath.documentId(),'desc');
        if(afterId){
          let cursor=await collection.doc(afterId).get();
          if(!cursor.exists&&options.unifiedAdminPagination){
            const other=cohortRoot?`orgs/${org}`:'orgs/gainpath/cohorts/fyp-v1';
            cursor=await db.doc(`${other}/canonicalRecommendations/${afterId}`).get();
          }
          const created=cursor.data()?.createdAtMillis;
          if(!Number.isSafeInteger(created))throw new DomainError('invalid-argument','Recommendation cursor is unavailable.');
          query=query.startAfter(created,afterId);
        }
        return(await query.limit(25).get()).docs.map(row=>row.id);
      }
      // Query by owner first to avoid a composite index requirement.
      let query = (member ? collection.where('memberId', '==', member) : collection).orderBy(FieldPath.documentId());
      if (afterId) query = query.startAfter(afterId);
      return (await query.limit(25).get()).docs.map(d => d.id);
    },
    async resolveTarget(tx, org, suggestion, now, member, reading) {
      if (suggestion.target.kind === 'content') return tutorial(tx, org, suggestion.target);
      if (suggestion.target.kind === 'routine') return routineTarget(tx,org,suggestion.target.routineId);
      if (!member) return null;
      const target = suggestion.target;
      if (!await coachIsVerified(target.coachId)) return null;
      const current = await coachTarget(tx, org, target.coachId, now, member, target.branchId);
      if (!current) return null;
      if (reading) return {...current, target};
      return digestOf(current.target) === digestOf(target) ? current : null;
    },
    async backupSuggestions(tx, org, member, key, now, boundary) {
      // Catalog entries are reused by Tutorials and Routines within this snapshot.
      const underlying=tx,reads=new Map<string,Promise<Awaited<ReturnType<TransactionPort['get']>>>>();
      tx={...underlying,get(path){
        let pending=reads.get(path);
        if(!pending){pending=underlying.get(path);reads.set(path,pending);}
        return pending;
      }};
      const root = `orgs/${org}`;
      const backups = `${root}/members/${member}/workoutBackups`;
      const source = await readWorkoutSource(tx, org, member, key, now, boundary, cohortRoot);
      if (!source) return [];
      const history = await db.collection(physical(backups)).orderBy('updatedAtMillis', 'desc').limit(32).get();
      const observed = cohortRoot ? (await db.collection(`${cohortRoot}/members/${member}/syntheticObservations`)
        .orderBy('observedAtMillis', 'desc').limit(32).get()).docs : [];
      const historyKeys = new Set([...history.docs.map(row => row.id), ...observed.map(row => 'session-' + row.id)]);
      const recent = [source];
      const allRecent=[source];
      for (const historyKey of historyKeys) {
        if (historyKey === key) continue;
        const other = await readWorkoutSource(tx, org, member, historyKey, now, boundary, cohortRoot);
        if(other && other.ended<=source.ended)allRecent.push(other);
        if (other?.exercise === source.exercise && other.ended <= source.ended) recent.push(other);
      }
      const scored = recent.filter(s => s.compatibility === source.compatibility && s.score !== null).sort((a, b) => b.ended - a.ended).slice(0, 5);
      const mean = scored.length >= 2 ? scored.reduce((sum, s) => sum + s.score!, 0) / scored.length : null;
      const objective = mean !== null && mean < 65 ? 'movement_control' :
        mean !== null && mean >= 85 ? 'progression' : 'technique_foundations';
      const catalog = await tx.get(`${root}/exerciseVideos/${source.exercise}`);
      const label = catalog?.exerciseName ?? catalog?.name ?? catalog?.title;
      if (!queueText(label, 80) || catalog?.isActive !== true || catalog.archived === true) return [];
      const profile=await tx.get(`${root}/profiles/${member}`);
      const preferences = recommendationPreferences(profile);
      let completion:WorkoutRankingContext['completion'];
      for(const row of history.docs.filter(row=>row.data().kind==='routine').slice(0,8)){
        const raw=await tx.get(`${backups}/${row.id}`);
        if(!raw || raw.classification!=='provisional_member_backup'||typeof raw.id!=='string'||
          raw.key!==row.id||typeof raw.payloadJson!=='string')continue;
        try{
          const payload=validateBackupPayload('routine',raw.id,org,member,JSON.parse(raw.payloadJson));
          const updated=Number(payload.updatedAtMicros)/1000;
          const attempt=object(payload.attempt);
          if(digestOf(payload)!==raw.digest||updated>now||updated<Math.max(boundary,now-MAX_AGE)||
            !Array.isArray(attempt.entries))continue;
          completion=payload.finished===true&&attempt.entries.every((e:any)=>
            ['completed','selfReportedCompleted'].includes(e.status))?'completed':'partial';
          break;
        }catch{continue;}
      }
      const publications = await db.collection(physical(`${root}/content`)).where('status', '==', 'published').limit(100).get();
      const tutorials: Awaited<ReturnType<typeof tutorial>>[] = [];
      for (const row of publications.docs) {
        const entries = row.data().exercises;
        if (!identifier(row.id) || !Array.isArray(entries) || !supportsRoutineTutorial(row.data())) continue;
        if (tutorials.length >= 20) break;
        for (const [index, entry] of entries.slice(0, 50).entries()) {
          if (tutorials.length >= 20) break;
          if (entry?.exerciseId !== source.exercise) continue;
          const dayNumber = entry.dayNumber ?? 1;
          if (!Number.isInteger(dayNumber) || dayNumber < 1 || dayNumber > 50) continue;
          tutorials.push(await tutorial(tx, org, {kind: 'content', destination: {
            kind: 'published_routine_exercise_tutorial', organizationId: org, routineId: row.id,
            exerciseIndex: index, exerciseId: source.exercise, dayNumber,
          }}));
        }
      }
      const wantedDifficulty = objective === 'movement_control' ? 'beginner' :
        objective === 'progression' && preferences.experience !== 'beginner' ? 'advanced' : preferences.experience ?? 'beginner';
      const difficulty = (value: unknown) => typeof value === 'string' && normalized(value) === wantedDifficulty ? 1 : 0;
      const selected = tutorials.filter(t => t !== null).sort((a, b) => difficulty(b.difficulty) - difficulty(a.difficulty)).slice(0,6);
      const output: CanonicalSuggestion[] = [];
      const goals:Record<string,WorkoutRankingContext['goal']>={buildMuscle:'muscle_gain',loseWeight:'weight_management',
        improveEndurance:'endurance',increaseFlexibility:'mobility',generalFitness:'general_fitness'};
      const aiGoal=preferences.goals.find(goal=>goals[goal]!==undefined);
      const minutes=profile?.preferredWorkoutDuration;
      const duration=typeof minutes==='number'&&Number.isFinite(minutes)&&minutes>0&&minutes<=240?minutes:undefined;
      const weeklySessions=allRecent.filter(s=>s.ended>=now-7*DAY).length;
      const context:WorkoutRankingContext={
        ...(aiGoal?{goal:goals[aiGoal]}:{}),
        ...(preferences.experience?{experience:preferences.experience}:{}),
        frequency:weeklySessions>=6?'regular':weeklySessions>=2?'occasional':'new',
        reps:source.repetitions>=15?'high':source.repetitions>=6?'moderate':'low',
        ...(completion?{completion}:{}),
        ...(/leg|lower|glute|calf|quad/i.test(String(catalog.muscleCategory??''))?{exercise:'lower_body' as const}:
          /arm|shoulder|chest|back|upper/i.test(String(catalog.muscleCategory??''))?{exercise:'upper_body' as const}:{}),
        ...(mean!==null?{form:mean<65?'developing' as const:'consistent' as const}:{}),
        ...(duration?{duration:timeBand(duration)}:{}),
      };
      const make = (candidate: CurrentRecommendationTarget, title: string, summary: string, explanations: string[]): CanonicalSuggestion => ({
        needKey: digestOf({exercise: candidate.target.kind==='routine'?'routine_discovery':source.exercise, kind: candidate.target.kind}), policyVersion: POLICY,
        source: {kind: source.origin, recordKey: key},
        evidenceFingerprint: digestOf({source: source.digest, qualified: scored.map(s => s.digest).sort()}),
        exerciseLabel: label, objective, title, summary, explanations,
        target: parseCanonicalTarget(candidate.target, org), targetLabel: candidate.label,
        ai:{method:'rule_fallback',workoutContext:`${allRecent.length} recent workout summaries; ${recent.length} for ${label}.${mean===null?'':` Comparable estimated Form Score ${Math.round(mean)}%.`}`,
          ...(['beginner','intermediate','advanced'].includes(normalized(candidate.difficulty??''))?
            {candidateDifficulty:normalized(candidate.difficulty!) as NonNullable<WorkoutRankingContext['experience']>}:{}),
          ...(candidate.durationMinutes?{candidateDuration:timeBand(candidate.durationMinutes)}:{}),
          fitnessGoals:[...preferences.goals],context,factors:[
            'exercise_match','recent_activity',...(preferences.experience===normalized(candidate.difficulty??'')?['experience_match' as const]:[]),
            ...(mean!==null&&mean<65?['form_practice' as const]:[]),
            'training_frequency',...(completion?['completion' as const]:[])]},
      });
      for(const target of selected)output.push(make(target, `Practise ${label} with a tutorial`,
        'Explore step-by-step guidance for the exercise you completed.',
        ['Matches your recent workout exercise.']));
      const routines:{target:CurrentRecommendationTarget;exerciseMatch:boolean;goalMatch:boolean}[]=[];
      const goalCategory=aiGoal?routineGoalCategories[aiGoal]:undefined;
      for(const row of publications.docs){
        if(routines.length>=20)break;
        const publication=row.data();
        if(!identifier(row.id)||!Array.isArray(publication.exercises))continue;
        const routine=await routineTarget(tx,org,row.id);
        if(!routine||((preferences.experience??'beginner')==='beginner'&&normalized(routine.difficulty??'')==='advanced'))continue;
        const exerciseMatch=publication.exercises.some((entry:any)=>entry.exerciseId===source.exercise);
        const goalMatch=!!goalCategory&&publication.exercises.some((entry:any)=>
          goalCategory.test(String(entry.muscleGroup??entry.category??'')));
        routines.push({target:routine,exerciseMatch,goalMatch});
      }
      routines.sort((a,b)=>difficulty(b.target.difficulty)-difficulty(a.target.difficulty)||
        Number(b.goalMatch)-Number(a.goalMatch)||Number(b.exerciseMatch)-Number(a.exerciseMatch)||
        (duration?Math.abs((a.target.durationMinutes??0)-duration)-Math.abs((b.target.durationMinutes??0)-duration):0));
      for(const {target:routine,exerciseMatch,goalMatch} of routines.slice(0,6)){
        const suggestion=make(routine,`Try ${routine.label}`,'Build on your recent practice with this published routine.',
          ['A published routine matched to your available training context.']);
        if(!exerciseMatch){
          suggestion.ai!.factors=suggestion.ai!.factors.filter(f=>f!=='exercise_match'&&f!=='form_practice');
        }
        if(goalMatch)suggestion.ai!.factors.push('goal_match');
        if(context.duration && routine.durationMinutes && timeBand(routine.durationMinutes)===context.duration)
          suggestion.ai!.factors.push('duration_match');
        output.push(suggestion);
      }
      // Coaching requires an explicit goal match and repeat practice. One low score cannot trigger an upsell.
      if (recent.length > 1 && preferences.goals.length) {
        const tags = preferences.goals.flatMap(goal => GOAL_SPECIALTIES[goal] ?? []);
        const candidates = await db.collection(physical(`${root}/coaches`)).where('status', '==', 'published').limit(25).get();
        for (const row of candidates.docs) {
          const data = await tx.get(logical(row.ref.path));
          if (!data || data.certificationVerified !== true || !identifier(row.id)) continue;
          const specialties = [data.specialty, ...(Array.isArray(data.specializationTags) ? data.specializationTags : [])];
          if (!specialties.some(v => typeof v === 'string' && tags.includes(normalized(v))) || !await coachIsVerified(row.id)) continue;
          const coach = await coachTarget(tx, org, row.id, now, member);
          if (!coach) continue;
          const suggestion=make(coach, `Explore coaching for ${label}`,
            'Meet a coach whose published specialty matches one of your fitness goals.',
            ['Matches a stated fitness goal.', 'A booking time was available when checked.']);
          const contextTags=aiGoal?GOAL_SPECIALTIES[aiGoal]??[]:[];
          if(specialties.some(v=>typeof v==='string'&&contextTags.includes(normalized(v))))
            suggestion.ai!.factors.push('goal_match','coach_specialization');
          suggestion.ai!.factors=suggestion.ai!.factors.filter(f=>f!=='exercise_match'&&f!=='form_practice');
          output.push(suggestion);
          if(output.filter(s=>s.target.kind==='trainer').length>=6)break;
        }
      }
      return output;
    },
  };
}

let configuredProvider:WorkoutRankingProvider|undefined;
export function getConfiguredWorkoutRankingProvider(){
  if(!process.env.GEMINI_API_KEY)return undefined;
  configuredProvider??=createGeminiWorkoutRecommendationRanker({apiKey:process.env.GEMINI_API_KEY,maxRequests:20});
  return configuredProvider;
}
export function getWorkoutBackupRuntime(options:{unifiedAdminPagination?:true}={}) {
  const db = getFirestore();
  if (db.databaseId !== '(default)') throw new Error('Default workout database required.');
  return createWorkoutBackupRuntime(db, async uid => {
    try {
      const user = await getAuth().getUser(uid);
      return user.emailVerified && !user.disabled;
    } catch (error) {
      if ((error as {code?: string}).code === 'auth/user-not-found') return false;
      throw error;
    }
  },undefined,{...options,provider:getConfiguredWorkoutRankingProvider()});
}
