import type {DocumentStore, TransactionPort, DocumentData} from '../../platform/firestore/store';
import {DomainError} from '../../platform/errors';
import {keyOf} from '../../platform/idempotency';
import {requiredIdentifier} from '../../platform/validation';
import {digestOf,keys,object} from '../workouts/workout-backup-validation';
import {parseSubmitWorkoutSession} from '../workouts/workout-validation';
import type {SubmitWorkoutSessionV2} from '../workouts/contracts';
import type {WorkoutModelTuple} from '../workouts/workout-service';
import type {InsightsAuth,FreshAuthIdentity} from './exercise-insights-contracts';
import {evaluateRecommendationConsentV2, type ReviewedConsentNoticePolicy} from './recommendation-consent-v2';
import {requireRecommendationMember} from './recommendation-member-service';
import {requireQueueAdmin} from './recommendation-queue-security';
import {parseCanonicalTarget, queueText, type CanonicalTarget} from './recommendation-queue-contracts';
import type {WorkoutRankingContext, WorkoutRankingFactor} from './workout-recommendation-ranking';
import type {CurrentRecommendationTarget, MemberRecommendationDetail} from './recommendation-member-contracts';
import {OBJECTIVES} from './recommendation-ranking-contracts';

export interface AcceptedCanonicalSession {readonly input: SubmitWorkoutSessionV2; readonly fingerprint: string; readonly acceptedAtMillis: number}
export interface CanonicalSuggestion {
  /** Stable need identity excludes catalog revisions and moving window bounds. */
  needKey: string; evidenceFingerprint: string; policyVersion: string; exerciseLabel: string; objective: string;
  evidenceSummary?: {assessedSessions:number;distinctDays:number;latestAtMillis:number};
  source?: {kind: 'synced_summary'|'recorded_history'|'fitness_profile'|'admin_outreach'; recordKey: string};
  outreach?: {sentBy:string;previewId:string;analysisDays:number;baselineFingerprint:string};
  title: string; summary: string; explanations: string[]; target: CanonicalTarget; targetLabel: string;
  ai?: {method:'gemini'|'rule_fallback';workoutContext:string;fitnessGoals:string[];factors:WorkoutRankingFactor[];
    context?:WorkoutRankingContext;model?:string;changedOrder?:boolean;candidateCount?:number;
    ruleFirstLabel?:string;geminiFirstLabel?:string;changedTopChoice?:boolean;latencyMillis?:number;
    inputTokens?:number|null;outputTokens?:number|null;thinkingTokens?:number|null;totalTokens?:number|null;
    providerSource?:'gemini'|'mock_or_recorded';cacheHit?:boolean;fallbackReason?:string;validationFailure?:string;
    candidateDifficulty?:WorkoutRankingContext['experience'];candidateDuration?:WorkoutRankingContext['duration']};
}
/** Only trusted server composition may supply these reviewed adapters. Derivation
 * must abstain on missing schema/mode/quality; no network inference in a tx. */
export interface ReviewedCanonicalRuntime {
  scopedDataset?: true;
  backupSuggestions?(tx: TransactionPort, org: string, member: string, key: string, now: number, historyStart: number, outreach?: boolean): Promise<readonly CanonicalSuggestion[]>;
  personalize?(suggestions:readonly CanonicalSuggestion[],allowAi:boolean):Promise<readonly CanonicalSuggestion[]>;
  reviewId: string; enabledTuples: readonly WorkoutModelTuple[]; notices: readonly ReviewedConsentNoticePolicy[];
  maximumAgeMillis: number; expiresAfterMillis: number; cooldownMillis: number;
  listAcceptedIds(tx: TransactionPort, org: string, member: string): Promise<readonly string[]>;
  derive(sessions: readonly AcceptedCanonicalSession[], now: number, profile: unknown): CanonicalSuggestion | null;
  resolveTarget(tx: TransactionPort, org: string, suggestion: CanonicalSuggestion, now: number, member?: string, reading?: boolean): Promise<CurrentRecommendationTarget | null>;
  listIds(tx: TransactionPort, org: string, member: string | null, afterId: string | null): Promise<readonly string[]>;
}
export interface CanonicalRecord extends DocumentData {
  schemaVersion: 1; mode: 'accepted_workout'|'workout_backup'; organizationId: string; memberId: string; id: string;
  revision: number; status: 'pending'|'prepared'|'delivered'|'dismissed'|'withdrawn'; suggestion: CanonicalSuggestion;
  consentFingerprint: string; createdAtMillis: number; expiresAtMillis: number; deliveredAtMillis: number|null;
  readAtMillis: number|null; acknowledgedAtMillis: number|null; dismissedAtMillis: number|null;
}
const unavailable = () => new DomainError('failed-precondition', 'Current canonical evidence, consent and target are required.');
const path = (org: string, id: string) => `orgs/${org}/canonicalRecommendations/${id}`;
function runtimeReady(runtime: ReviewedCanonicalRuntime) {
  requiredIdentifier(runtime.reviewId, 'review');
  if ((!runtime.enabledTuples.length && !runtime.backupSuggestions) || !runtime.notices.length || !Number.isSafeInteger(runtime.maximumAgeMillis) || runtime.maximumAgeMillis <= 0 ||
    !Number.isSafeInteger(runtime.expiresAfterMillis) || runtime.expiresAfterMillis <= 0 || !Number.isSafeInteger(runtime.cooldownMillis) || runtime.cooldownMillis < 0) throw unavailable();
}
function record(raw: DocumentData | undefined, org: string, id: string, now=Number.MAX_SAFE_INTEGER): CanonicalRecord {
  if (!raw || raw.schemaVersion !== 1 || !['accepted_workout','workout_backup'].includes(String(raw.mode)) || raw.organizationId !== org || raw.id !== id ||
    !/^[a-f0-9]{64}$/.test(id) || !Number.isSafeInteger(raw.revision) || Number(raw.revision) < 1 || Number(raw.revision)>=Number.MAX_SAFE_INTEGER-1 ||
    !['pending','prepared','delivered','dismissed','withdrawn'].includes(String(raw.status))) throw unavailable();
  requiredIdentifier(raw.memberId, 'member');
  keys(raw,['schemaVersion','mode','organizationId','memberId','id','revision','status','suggestion','consentFingerprint','createdAtMillis','expiresAtMillis','deliveredAtMillis','readAtMillis','acknowledgedAtMillis','dismissedAtMillis']);
  if(typeof raw.consentFingerprint!=='string'||!/^[a-f0-9]{64}$/.test(raw.consentFingerprint)||
    !Number.isSafeInteger(raw.createdAtMillis)||Number(raw.createdAtMillis)<=0||Number(raw.createdAtMillis)>now||
    !Number.isSafeInteger(raw.expiresAtMillis)||Number(raw.expiresAtMillis)<=Number(raw.createdAtMillis))throw unavailable();
  for(const key of ['deliveredAtMillis','readAtMillis','acknowledgedAtMillis','dismissedAtMillis'])if(raw[key]!==null&&
    (!Number.isSafeInteger(raw[key])||Number(raw[key])<Number(raw.createdAtMillis)||Number(raw[key])>now))throw unavailable();
  if(['pending','prepared'].includes(String(raw.status))&&raw.deliveredAtMillis!==null||raw.status==='delivered'&&raw.deliveredAtMillis===null||
    (raw.readAtMillis!==null||raw.acknowledgedAtMillis!==null)&&raw.deliveredAtMillis===null||
    raw.deliveredAtMillis!==null&&[raw.readAtMillis,raw.acknowledgedAtMillis,raw.dismissedAtMillis].some(t=>t!==null&&Number(t)<Number(raw.deliveredAtMillis)))throw unavailable();
  validateSuggestion(raw.suggestion as CanonicalSuggestion,org);
  return raw as CanonicalRecord;
}
function validateSuggestion(s: CanonicalSuggestion, org: string) {
  keys(object(s),['needKey','evidenceFingerprint','policyVersion','exerciseLabel','objective','title','summary','explanations','target','targetLabel','evidenceSummary','source','ai','outreach'],['needKey','evidenceFingerprint','policyVersion','exerciseLabel','objective','title','summary','explanations','target','targetLabel']);
  if(s.outreach){keys(object(s.outreach),['sentBy','previewId','analysisDays','baselineFingerprint']);if(s.source?.kind!=='admin_outreach'||![7,30].includes(s.outreach.analysisDays)||!/^[a-f0-9]{64}$/.test(s.outreach.baselineFingerprint))throw unavailable();}
  if (s.source) {
    keys(object(s.source), ['kind','recordKey']);
    if (s.source.kind === 'fitness_profile') {
      if (s.source.recordKey !== 'fitness-profile' || s.target.kind !== 'trainer') throw unavailable();
    } else if (s.source.kind==='admin_outreach') {
      if(!s.outreach||!/^([a-f0-9]{64})$/.test(s.outreach.previewId)||!queueText(s.outreach.sentBy,128)||
        s.source.recordKey!=='fitness-profile'&&!/^session-[A-Za-z0-9_-]{1,128}$/.test(s.source.recordKey))throw unavailable();
    } else if (!['synced_summary','recorded_history'].includes(s.source.kind) ||
      !/^session-[A-Za-z0-9_-]{1,128}$/.test(s.source.recordKey)) throw unavailable();
  }
  requiredIdentifier(s.needKey, 'need'); requiredIdentifier(s.policyVersion, 'policy');
  if (!/^[a-f0-9]{64}$/.test(s.evidenceFingerprint) || !s.exerciseLabel || s.exerciseLabel.length > 120 ||
    !OBJECTIVES.includes(s.objective as typeof OBJECTIVES[number]) || !s.title || s.title.length > 120 || !s.summary || s.summary.length > 400 ||
    !s.targetLabel || s.targetLabel.length > 200 || !Array.isArray(s.explanations) || s.explanations.length > 6 ||
    s.explanations.some(e => typeof e !== 'string' || e.length > 300)) throw unavailable();
  if(s.evidenceSummary!==undefined){
    const e=object(s.evidenceSummary);keys(e,['assessedSessions','distinctDays','latestAtMillis']);
    if(!Number.isSafeInteger(e.assessedSessions)||Number(e.assessedSessions)<1||Number(e.assessedSessions)>200||!Number.isSafeInteger(e.distinctDays)||Number(e.distinctDays)<1||Number(e.distinctDays)>Number(e.assessedSessions)||!Number.isSafeInteger(e.latestAtMillis)||Number(e.latestAtMillis)<=0)throw unavailable();
  }
  if(s.ai && (!['gemini','rule_fallback'].includes(s.ai.method)||!queueText(s.ai.workoutContext,400)||
    !Array.isArray(s.ai.fitnessGoals)||s.ai.fitnessGoals.length>6||s.ai.fitnessGoals.some(g=>!queueText(g,80))||
    !Array.isArray(s.ai.factors)||s.ai.factors.length>12||s.ai.factors.some(f=>!queueText(f,80))))throw unavailable();
  parseCanonicalTarget(s.target, org);
}
/** Verifies the actual server acceptance record and command receipt. A backup,
 * provenance string, or manually renamed synthetic row cannot pass this reader. */
export async function readAcceptedCanonicalSession(tx: TransactionPort, org: string, member: string, id: string,
  runtime: ReviewedCanonicalRuntime, now: number): Promise<AcceptedCanonicalSession> {
  if (!/^[a-f0-9]{64}$/.test(id)) throw unavailable();
  const raw = await tx.get(`orgs/${org}/workoutSessions/${id}`);
  if (!raw || raw.status !== 'accepted' || raw.organizationId !== org || raw.memberId !== member ||
    !Number.isSafeInteger(raw.acceptedAtMillis) || Number(raw.acceptedAtMillis) > now) throw unavailable();
  const {fingerprint, status: _, acceptedAtMillis, ...stored} = raw;
  const input = parseSubmitWorkoutSession(stored);
  const {requestId: _request, ...sessionInput} = input;
  if (input.organizationId !== org || input.memberId !== member || id !== keyOf(member, input.sessionId) ||
    fingerprint !== keyOf(sessionInput) || input.endedAtMillis > Number(acceptedAtMillis) ||
    input.repetitions * 600 > input.trackedDurationMillis || !runtime.enabledTuples.some(t =>
      t.organizationId === org && t.exerciseId === input.exerciseId && t.detectorId === input.detectorId &&
      t.detectorVersion === input.detectorVersion && t.scoringVersion === input.scoringVersion && t.cameraView === input.cameraView)) throw unavailable();
  const receipt = await tx.get(`orgs/${org}/commandReceipts/${keyOf('submitWorkoutSession', member, input.requestId)}`);
  const result = receipt?.result as Record<string, unknown> | undefined;
  if (receipt?.fingerprint !== keyOf(input) || result?.schemaVersion !== 2 || result.status !== 'accepted' ||
    result.requestId !== input.requestId || result.sessionId !== input.sessionId || result.acceptedAtMillis !== acceptedAtMillis) throw unavailable();
  return {input, fingerprint: String(fingerprint), acceptedAtMillis: Number(acceptedAtMillis)};
}

function writeDelivery(tx: TransactionPort, r: CanonicalRecord, now: number) {
  const root = `orgs/${r.organizationId}`;
  const notificationId = digestOf({canonicalRecommendation: r.id});
  tx.create(`${root}/notifications/${notificationId}`, {
    schemaVersion: 1, type: 'recommendation', mode: r.mode, recipientId: r.memberId,
    recommendationId: r.id, recommendationKind: r.suggestion.target.kind, title: r.suggestion.title,
    message: 'Open to review this suggestion.', createdAtMillis: now, read: false,
  });
  tx.create(`${root}/canonicalRecommendationDeliveries/${r.id}`, {
    schemaVersion: 1, id: r.id, memberId: r.memberId, fingerprint: digestOf(r.suggestion), deliveredAtMillis: now,
  });
}

export interface CanonicalLifecycleDependencies {store:DocumentStore;runtime:ReviewedCanonicalRuntime;clock?:()=>number;readAuthIdentity:(uid:string)=>Promise<FreshAuthIdentity>}
export function createCanonicalRecommendationLifecycle(deps: CanonicalLifecycleDependencies) {
  const {runtime, store} = deps;
  const nowOf = () => {const n = (deps.clock ?? Date.now)(); if (!Number.isSafeInteger(n) || n <= 0) throw unavailable(); return n;};
  async function privacy(tx: TransactionPort, org: string, member: string, now: number, delivery = false) {
    if(!runtime.scopedDataset && await tx.get(`datasetAssignments/${member}`))throw unavailable();
    const user = await tx.get(`users/${member}`), membership = await tx.get(`orgs/${org}/members/${member}`), organization = await tx.get(`orgs/${org}`);
    const lifecycle = user?.accountLifecycle as Record<string, unknown>|undefined;
    if (organization?.status !== 'active' || user?.organizationId !== org || membership?.role !== 'member' ||
      membership?.status !== 'active' || membership.organizationId !== org || membership.userId !== undefined && membership.userId !== member ||
      !Array.isArray(membership.branchIds) || user?.role !== undefined && user.role !== 'member' ||
      lifecycle && (lifecycle.schemaVersion !== 1 || lifecycle.state !== 'active' || lifecycle.revocationPending !== false ||
        !Number.isSafeInteger(lifecycle.sessionNotBeforeSeconds))) throw unavailable();
    const consent = await tx.get(`orgs/${org}/recommendationConsent/${member}`);
    const purposes = delivery ? ['exerciseInsights','recommendationGeneration','recommendationDelivery'] as const : ['exerciseInsights','recommendationGeneration'] as const;
    const decisions = purposes.map(p => evaluateRecommendationConsentV2(consent, {organizationId: org, memberId: member}, now, runtime.notices, p));
    if (decisions.some(d => !d.allowed)) throw unavailable();
    const allowed = decisions.filter(d => d.allowed);
    const external=evaluateRecommendationConsentV2(consent,{organizationId:org,memberId:member},now,runtime.notices,'externalAiInference');
    return {fingerprint: digestOf(consent), historyStart: Math.max(...allowed.map(d => Number(d.historyStartAtMillis))),allowAi:external.allowed};
  }
  async function eligibleIdentity(member:string) {
    const identity=await deps.readAuthIdentity(member);
    if(!identity||identity.uid!==member||identity.disabled!==false||identity.emailVerified!==true||!identity.email||
      !Number.isSafeInteger(identity.tokensValidAfterMillis)||identity.tokensValidAfterMillis<0)throw unavailable();
  }
  async function recipientIdentity(org:string,id:string,admin?:InsightsAuth){
    const member=await store.transact(async tx=>{if(admin)await requireQueueAdmin(tx,admin,org);return record(await tx.get(path(org,id)),org,id,nowOf()).memberId;});
    await eligibleIdentity(member);
  }
  async function derive(tx: TransactionPort, org: string, member: string, now: number, boundary: number) {
    const ids = await runtime.listAcceptedIds(tx, org, member);
    if (ids.length > 200 || new Set(ids).size !== ids.length) throw unavailable();
    const sessions: AcceptedCanonicalSession[] = [];
    for (const id of ids) {
      const session = await readAcceptedCanonicalSession(tx, org, member, id, runtime, now);
      if (session.input.startedAtMillis >= boundary && now - session.input.endedAtMillis <= runtime.maximumAgeMillis) sessions.push(session);
    }
    const profile=await tx.get(`orgs/${org}/profiles/${member}`);
    const suggestion = runtime.derive(sessions, now, profile);
    if (suggestion) validateSuggestion(suggestion, org);
    return suggestion;
  }
  async function current(tx: TransactionPort, r: CanonicalRecord, now: number) {
    const consent = await privacy(tx, r.organizationId, r.memberId, now, true);
    if (r.expiresAtMillis <= now || r.createdAtMillis > now || consent.fingerprint !== r.consentFingerprint) throw unavailable();
    if (r.mode === 'workout_backup') {
      const target = await runtime.resolveTarget(tx, r.organizationId, r.suggestion, now, r.memberId, true);
      if (!target) throw unavailable();
      return target;
    }
    const suggestion = await derive(tx, r.organizationId, r.memberId, now, consent.historyStart);
    if (!suggestion || digestOf(suggestion) !== digestOf(r.suggestion)) throw unavailable();
    const target = await runtime.resolveTarget(tx, r.organizationId, suggestion, now, r.memberId);
    if (!target || digestOf(target.target) !== digestOf(suggestion.target)) throw unavailable();
    return target;
  }
  return {
    /** Explicit Admin outreach has its own preview identity and atomic delivery; automatic fatigue is untouched. */
    async outreach(auth:InsightsAuth,org:string,member:string,previewId:string,consentFingerprint:string,suggestions:readonly CanonicalSuggestion[]){
      runtimeReady(runtime);const now=nowOf();await eligibleIdentity(member);
      if(!/^[a-f0-9]{64}$/.test(previewId)||!suggestions.length||suggestions.length>3)throw unavailable();
      return store.transact(async tx=>{
        await requireQueueAdmin(tx,auth,org);const consent=await privacy(tx,org,member,now,true);
        if(!consent.allowAi||consent.fingerprint!==consentFingerprint)throw unavailable();
        const writes:(()=>void)[]=[],ids:string[]=[],kinds=new Set<string>();
        for(const suggestion of suggestions){
          validateSuggestion(suggestion,org);
          if(suggestion.source?.kind!=='admin_outreach'||suggestion.outreach?.sentBy!==auth.uid||suggestion.outreach.previewId!==previewId||suggestion.ai?.method!=='gemini'||kinds.has(suggestion.target.kind))throw unavailable();
          kinds.add(suggestion.target.kind);
          const id=digestOf({org,member,previewId,kind:suggestion.target.kind,source:'admin_outreach'});
          const old=await tx.get(path(org,id));
          if(old){const r=record(old,org,id,now);if(r.status!=='delivered'||r.suggestion.summary!==suggestion.summary)throw new DomainError('aborted','This recommendation was already sent with another message.');ids.push(id);continue;}
          const fresh=await runtime.backupSuggestions?.(tx,org,member,suggestion.source.recordKey,now,Math.max(consent.historyStart,now-suggestion.outreach.analysisDays*86400000),true)??[];
          if(!fresh.some(c=>digestOf(c)===suggestion.outreach!.baselineFingerprint))throw new DomainError('failed-precondition','Member context or available content changed. Generate a fresh preview.');
          const target=await runtime.resolveTarget(tx,org,suggestion,now,member);if(!target||digestOf(target.target)!==digestOf(suggestion.target))throw unavailable();
          const r:CanonicalRecord={schemaVersion:1,mode:'workout_backup',organizationId:org,memberId:member,id,revision:1,status:'delivered',suggestion,consentFingerprint,createdAtMillis:now,expiresAtMillis:now+runtime.expiresAfterMillis,deliveredAtMillis:now,readAtMillis:null,acknowledgedAtMillis:null,dismissedAtMillis:null};
          writes.push(()=>{tx.create(path(org,id),r);writeDelivery(tx,r,now);});ids.push(id);
        }
        writes.forEach(w=>w());return ids;
      });
    },
    async backup(org: string, member: string, key: string) {
      runtimeReady(runtime);
      requiredIdentifier(org, 'organization');
      requiredIdentifier(member, 'member');
      if (key !== 'fitness-profile' && !/^session-[A-Za-z0-9_-]{1,128}$/.test(key)) throw unavailable();
      if (!runtime.backupSuggestions || org !== 'gainpath') return [];
      const now = nowOf();
      await eligibleIdentity(member);
      // Provider I/O happens once between read and commit, outside retrying transactions.
      const prepared = runtime.personalize ? await store.transact(async tx=>{
        const consent=await privacy(tx,org,member,now,true);
        if (key === 'fitness-profile') {
          const id=digestOf({org,member,key,kind:'trainer',source:'workout_backup',consent:consent.fingerprint});
          if (await tx.get(path(org,id))) return {consent,candidates:[]};
        }
        const candidates=await runtime.backupSuggestions!(tx,org,member,key,now,consent.historyStart);
        const eligible:CanonicalSuggestion[]=[];
        for(const candidate of candidates){
          validateSuggestion(candidate,org);
          const id=digestOf({org,member,key,kind:candidate.target.kind,source:'workout_backup',consent:consent.fingerprint});
          const fatiguePath=`orgs/${org}/canonicalRecommendationFatigue/${digestOf({member,need:candidate.needKey})}`;
          const [old,fatigue]=await Promise.all([tx.get(path(org,id)),tx.get(fatiguePath)]);
          if(!old && Number(fatigue?.untilMillis||0)<=now)eligible.push(candidate);
        }
        return {consent,candidates:eligible};
      }):null;
      if(prepared && !prepared.candidates.length)return [];
      const ranked = prepared ? await runtime.personalize!(prepared.candidates,prepared.consent.allowAi):null;
      await eligibleIdentity(member);
      return store.transact(async tx => {
        const consent = await privacy(tx, org, member, now, true);
        if(prepared && consent.fingerprint!==prepared.consent.fingerprint)return [];
        const fresh = await runtime.backupSuggestions!(tx, org, member, key, now, consent.historyStart);
        const suggestions=ranked===null?fresh:ranked.flatMap(selected=>{
          const baseline=prepared!.candidates.find(candidate=>candidate.needKey===selected.needKey&&
            digestOf(candidate.target)===digestOf(selected.target));
          if(baseline && fresh.some(candidate=>digestOf(candidate)===digestOf(baseline)))return[selected];
          const fallback=fresh.find(candidate=>candidate.target.kind===selected.target.kind);
          return fallback?[{...fallback,...(fallback.ai?{ai:{...fallback.ai,method:'rule_fallback' as const,
            ruleFirstLabel:fallback.targetLabel,candidateCount:fresh.filter(candidate=>candidate.target.kind===selected.target.kind).length,
            fallbackReason:'context_changed'}}:{})}]:[];
        });
        const writes: (() => void)[] = [];
        const delivered: string[] = [];
        const kinds = new Set<string>();
        for (const suggestion of suggestions) {
          validateSuggestion(suggestion, org);
          const kind = suggestion.target.kind;
          if (kinds.has(kind)) throw unavailable();
          kinds.add(kind);
          const id = digestOf({org, member, key, kind, source: 'workout_backup', consent: consent.fingerprint});
          const fatiguePath = `orgs/${org}/canonicalRecommendationFatigue/${digestOf({member, need: suggestion.needKey})}`;
          const [old, fatigue] = await Promise.all([tx.get(path(org, id)), tx.get(fatiguePath)]);
          if (old || Number(fatigue?.untilMillis) > now) continue;
          const target = await runtime.resolveTarget(tx, org, suggestion, now, member);
          if (!target || digestOf(target.target) !== digestOf(suggestion.target)) continue;
          const r: CanonicalRecord = {schemaVersion: 1, mode: 'workout_backup', organizationId: org, memberId: member, id,
            revision: 1, status: 'delivered', suggestion, consentFingerprint: consent.fingerprint, createdAtMillis: now,
            expiresAtMillis: now + runtime.expiresAfterMillis, deliveredAtMillis: now, readAtMillis: null,
            acknowledgedAtMillis: null, dismissedAtMillis: null};
          writes.push(() => {
            writeDelivery(tx, r, now);
            tx.create(path(org, id), r);
            tx.set(fatiguePath, {untilMillis: now + runtime.cooldownMillis});
          });
          delivered.push(id);
        }
        writes.forEach(write => write());
        return delivered;
      });
    },
    /** At-least-once event input is only an identifier; all authority is reread. */
    async accepted(org: string, member: string, acceptedId: string) {
      runtimeReady(runtime); requiredIdentifier(org, 'organization'); requiredIdentifier(member, 'member'); const now = nowOf();
      await eligibleIdentity(member);
      return store.transact(async tx => {
        const consent = await privacy(tx, org, member, now);
        const accepted = await readAcceptedCanonicalSession(tx, org, member, acceptedId, runtime, now);
        if (accepted.input.startedAtMillis < consent.historyStart || now - accepted.input.endedAtMillis > runtime.maximumAgeMillis) return {status: 'abstained' as const};
        const suggestion = await derive(tx, org, member, now, consent.historyStart);
        if (!suggestion) return {status: 'abstained' as const};
        const target = await runtime.resolveTarget(tx, org, suggestion, now, member); if (!target) return {status: 'abstained' as const};
        const id = digestOf({org, member, needKey: suggestion.needKey, evidence: suggestion.evidenceFingerprint, policy: suggestion.policyVersion});
        const old = await tx.get(path(org, id));
        const fatiguePath = `orgs/${org}/canonicalRecommendationFatigue/${digestOf({member, need: suggestion.needKey})}`;
        const fatigue = await tx.get(fatiguePath);
        if (old) return {status: 'existing' as const, id};
        if (fatigue && Number(fatigue.untilMillis) > now) return {status: 'suppressed' as const};
        const r: CanonicalRecord = {schemaVersion: 1, mode: 'accepted_workout', organizationId: org, memberId: member, id,
          revision: 1, status: 'pending', suggestion, consentFingerprint: consent.fingerprint, createdAtMillis: now,
          expiresAtMillis: now + runtime.expiresAfterMillis, deliveredAtMillis: null, readAtMillis: null, acknowledgedAtMillis: null, dismissedAtMillis: null};
        tx.create(path(org, id), r);
        tx.set(fatiguePath,{untilMillis:now+runtime.cooldownMillis});
        return {status: 'created' as const, id};
      });
    },
    async decide(auth: InsightsAuth, org: string, id: string, revision: number, commandId: string, action: 'send'|'dismiss') {
      runtimeReady(runtime); requiredIdentifier(commandId, 'command'); const now = nowOf();
      if(action==='send') await recipientIdentity(org,id,auth);
      return store.transact(async tx => {
        await requireQueueAdmin(tx, auth, org); const r = record(await tx.get(path(org, id)), org, id);
        const receiptPath = `orgs/${org}/canonicalRecommendationCommands/${digestOf({actor: auth.uid, commandId})}`;
        const fingerprint = digestOf({id, revision, action}); const receipt = await tx.get(receiptPath);
        if (receipt) {if (receipt.fingerprint !== fingerprint) throw new DomainError('aborted', 'Command reused.'); return receipt.result;}
        if (r.status !== 'pending' || r.revision !== revision) throw new DomainError('aborted', 'Recommendation changed.');
        if(action==='send') await current(tx, r, now);
        const result = {id, revision: revision + 1, status: action === 'send' ? 'prepared' : 'dismissed'};
        tx.set(path(org, id), {...r, ...result, dismissedAtMillis: action === 'dismiss' ? now : null});
        if(action==='dismiss'&&r.suggestion.source?.kind!=='admin_outreach')tx.set(`orgs/${org}/canonicalRecommendationFatigue/${digestOf({member:r.memberId,need:r.suggestion.needKey})}`,{untilMillis:now+runtime.cooldownMillis});
        tx.create(receiptPath, {fingerprint, result, actorId: auth.uid, atMillis: now}); return result;
      });
    },
    /** Recovery is the same atomic delivery operation as immediate Send. No
     * network send or nontransactional gap exists after notification commit. */
    async deliver(org: string, id: string) {
      runtimeReady(runtime); const now = nowOf();
      await recipientIdentity(org,id);
      return store.transact(async tx => {
        const r = record(await tx.get(path(org, id)), org, id); await current(tx, r, now);
        const receiptPath = `orgs/${org}/canonicalRecommendationDeliveries/${id}`;
        const receipt = await tx.get(receiptPath); const notificationId = digestOf({canonicalRecommendation: id});
        const notificationPath = `orgs/${org}/notifications/${notificationId}`;
        const notification = await tx.get(notificationPath);
        if (r.status === 'delivered') {
          if (!receipt || !notification || receipt.memberId !== r.memberId || receipt.id!==id || receipt.fingerprint!==digestOf(r.suggestion) ||
            receipt.deliveredAtMillis!==r.deliveredAtMillis || notification.mode!==r.mode || notification.recipientId !== r.memberId ||
            notification.recommendationId !== id || notification.createdAtMillis!==r.deliveredAtMillis || notification.title!==r.suggestion.title) throw unavailable();
          return {id, status: 'delivered' as const};
        }
        if (r.status !== 'prepared' || receipt || notification) throw unavailable();
        writeDelivery(tx, r, now);
        tx.set(path(org, id), {...r, status: 'delivered', revision: r.revision + 1, deliveredAtMillis: now});
        if(r.suggestion.source?.kind!=='admin_outreach')tx.set(`orgs/${org}/canonicalRecommendationFatigue/${digestOf({member: r.memberId, need: r.suggestion.needKey})}`, {untilMillis: now + runtime.cooldownMillis});
        return {id, status: 'delivered' as const};
      });
    },
    async member(auth: InsightsAuth, org: string, id: string, action: 'get'|'resolve'|'read'|'acknowledge'|'dismiss', expectedRevision: number|null, commandId: string|null) {
      runtimeReady(runtime); const now = nowOf();
      return store.transact(async tx => {
        await requireRecommendationMember(tx, auth, org);
        if(!runtime.scopedDataset && await tx.get(`datasetAssignments/${auth.uid}`))throw new DomainError('permission-denied','Canonical account required.');
        const raw = await tx.get(path(org, id));
        if (!raw || raw.memberId !== auth.uid) throw new DomainError('permission-denied', 'Recommendation unavailable.');
        const r = record(raw, org, id,now);
        const receipt = await tx.get(`orgs/${org}/canonicalRecommendationDeliveries/${id}`);
        const notificationPath=`orgs/${org}/notifications/${digestOf({canonicalRecommendation:id})}`;
        const notification=await tx.get(notificationPath);
        if(r.deliveredAtMillis===null){if(receipt||notification)throw unavailable();}
        else if(!receipt||receipt.schemaVersion!==1||receipt.id!==id||receipt.memberId!==auth.uid||receipt.fingerprint!==digestOf(r.suggestion)||
          receipt.deliveredAtMillis!==r.deliveredAtMillis||!notification||notification.schemaVersion!==1||notification.mode!==r.mode||
          notification.type!=='recommendation'||notification.recipientId!==auth.uid||notification.recommendationId!==id||
          notification.recommendationKind!==r.suggestion.target.kind||notification.createdAtMillis!==r.deliveredAtMillis||
          notification.title!==r.suggestion.title||notification.message!=='Open to review this suggestion.'||
          notification.read!==(r.readAtMillis!==null))throw unavailable();
        let state:MemberRecommendationDetail['state']=r.deliveredAtMillis===null?'not_delivered':r.dismissedAtMillis!==null?'dismissed':
          r.status==='withdrawn'?'withdrawn':r.expiresAtMillis<=now?'expired':'available';
        let target:CurrentRecommendationTarget|null=null;
        if(state==='available'){
          // Revoked permission reveals no evidence/target and performs no source
          // scan, while the owner retains minimal delivered history metadata.
          try{const permission=await privacy(tx,org,auth.uid,now,true);if(permission.fingerprint!==r.consentFingerprint)state='withdrawn';}
          catch(error){if(!(error instanceof DomainError)||error.code!=='failed-precondition')throw error;state='withdrawn';}
          if(state==='available')try{target=await current(tx,r,now);}catch(error){if(!(error instanceof DomainError)||error.code!=='failed-precondition')throw error;state='unavailable';}
        }
        function detail(value:CanonicalRecord):Omit<MemberRecommendationDetail,'mode'>&{mode:CanonicalRecord['mode']}{
          const available=state==='available'&&target!==null;
          const title=available?value.suggestion.title:state==='dismissed'?'Recommendation dismissed':state==='expired'?'Recommendation expired':
            state==='not_delivered'?'Recommendation pending delivery':'Recommendation unavailable';
          return{schemaVersion:1,mode:value.mode,organizationId:org,recommendationId:id,kind:value.suggestion.target.kind,revision:value.revision,state,title,
            summary:available?value.suggestion.summary:'You can browse current tutorials and Coaches.',
            exerciseLabel:available?value.suggestion.exerciseLabel:null,objective:available?value.suggestion.objective as MemberRecommendationDetail['objective']:null,
            explanations:available?value.suggestion.explanations:[],target:available?target!.target:null,targetLabel:available?target!.label:null,
            specialization:available?target!.specialization:null,imageUrl:available?target!.imageUrl:null,photoPath:available?target!.photoPath:null,
            ...(available?Object.fromEntries(['difficulty','durationMinutes','exerciseCount','priceMinor','currency','branchLabel']
              .filter(k=>(target as unknown as Record<string,unknown>)[k]!==undefined)
              .map(k=>[k,(target as unknown as Record<string,unknown>)[k]])):{}),
            ...(available && value.suggestion.ai?{aiMethod:value.suggestion.ai.method}:{}),
            createdAtMillis:value.createdAtMillis,deliveredAtMillis:value.deliveredAtMillis,expiresAtMillis:value.expiresAtMillis,
            readAtMillis:value.readAtMillis,acknowledgedAtMillis:value.acknowledgedAtMillis,dismissedAtMillis:value.dismissedAtMillis};
        }
        if (!['get','resolve'].includes(action)) {
          requiredIdentifier(commandId, 'command');
          const commandPath = `orgs/${org}/canonicalRecommendationCommands/${digestOf({actor: auth.uid, commandId})}`;
          const fingerprint = digestOf({id, action, expectedRevision}); const command = await tx.get(commandPath);
          if (command) {if (command.fingerprint !== fingerprint) throw new DomainError('aborted', 'Command reused.'); return detail(r);}
          if (r.revision !== expectedRevision) throw new DomainError('aborted', 'Recommendation changed.');
          const canReadDismissed = action === 'read' && state === 'dismissed';
          if (r.deliveredAtMillis === null ||
              (action !== 'dismiss' && state !== 'available' && !canReadDismissed)) throw unavailable();
          const changed=action==='read'?r.readAtMillis===null:action==='acknowledge'?r.acknowledgedAtMillis===null:r.dismissedAtMillis===null;
          const updated = {...r, revision: r.revision + (changed?1:0), ...(action === 'read' ? {readAtMillis: r.readAtMillis ?? now} :
            action === 'acknowledge' ? {acknowledgedAtMillis: r.acknowledgedAtMillis ?? now} : {dismissedAtMillis: r.dismissedAtMillis ?? now})};
          // Read does not imply acknowledgment; neither implies booking/use.
          if(changed)tx.set(path(org, id), updated);
          if(action==='read'&&changed&&notification)tx.set(notificationPath,{...notification,read:true});
          if(action==='dismiss'&&r.suggestion.source?.kind!=='admin_outreach')tx.set(`orgs/${org}/canonicalRecommendationFatigue/${digestOf({member:r.memberId,need:r.suggestion.needKey})}`,{untilMillis:now+runtime.cooldownMillis});
          if(action==='dismiss')state='dismissed';
          tx.create(commandPath, {schemaVersion:1,fingerprint,actorId:auth.uid,id,action,previousRevision:r.revision,revision:updated.revision,atMillis:now});
          return detail(updated);
        }
        return detail(r);
      });
    },
    async ids(auth: InsightsAuth, org: string, afterId: string|null, admin = false) {
      runtimeReady(runtime);
      return store.transact(async tx => {if (admin) await requireQueueAdmin(tx, auth, org); else await requireRecommendationMember(tx, auth, org);
        const ids = await runtime.listIds(tx, org, admin ? null : auth.uid, afterId); if (ids.length > 25) throw unavailable(); return ids;});
    },
    async adminDetail(auth: InsightsAuth, org: string, id: string) {
      runtimeReady(runtime); const now = nowOf();
      return store.transact(async tx => {await requireQueueAdmin(tx, auth, org); const r = record(await tx.get(path(org,id)),org,id);
        const redacted=()=>({schemaVersion:1,mode:r.mode,organizationId:org,id:r.id,memberId:r.memberId,
          revision:r.revision,status:'withdrawn',redacted:true,kind:r.suggestion.target.kind,
          createdAtMillis:r.createdAtMillis,expiresAtMillis:r.expiresAtMillis,deliveredAtMillis:r.deliveredAtMillis});
        try {
          const permission=await privacy(tx,org,r.memberId,now,true);
          if(permission.fingerprint!==r.consentFingerprint)return redacted();
        } catch(error) {
          if(!(error instanceof DomainError)||error.code!=='failed-precondition')throw error;
          return redacted();
        }
        if (r.mode === 'workout_backup' && r.status === 'delivered') {
          const receipt = await tx.get(`orgs/${org}/canonicalRecommendationDeliveries/${id}`);
          const notification = await tx.get(`orgs/${org}/notifications/${digestOf({canonicalRecommendation:id})}`);
          if (receipt?.id !== id || receipt.memberId !== r.memberId || receipt.deliveredAtMillis !== r.deliveredAtMillis ||
            receipt.fingerprint !== digestOf(r.suggestion) || notification?.recommendationId !== id ||
            notification.recipientId !== r.memberId || notification.createdAtMillis !== r.deliveredAtMillis ||
            notification.mode !== r.mode) return redacted();
          if (r.expiresAtMillis > now && !await runtime.resolveTarget(tx,org,r.suggestion,now,r.memberId,true)) return redacted();
        }
        if(r.status==='pending'||r.status==='prepared') {
          try { await current(tx,r,now); }
          catch(error) {
            if(!(error instanceof DomainError)||error.code!=='failed-precondition')throw error;
            return redacted();
          }
        }
        const member = await tx.get(`orgs/${org}/members/${r.memberId}`);
        const memberLabel = queueText(member?.displayName, 120) ? member.displayName : r.memberId;
        return {...r, memberLabel};});
    },
  };
}
