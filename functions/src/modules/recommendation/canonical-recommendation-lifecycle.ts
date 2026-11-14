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
import {parseQueueTarget, type QueueTarget} from './recommendation-queue-contracts';
import type {CurrentRecommendationTarget, MemberRecommendationDetail} from './recommendation-member-contracts';
import {OBJECTIVES} from './recommendation-ranking-contracts';

export interface AcceptedCanonicalSession {readonly input: SubmitWorkoutSessionV2; readonly fingerprint: string; readonly acceptedAtMillis: number}
export interface CanonicalSuggestion {
  /** Stable need identity excludes catalog revisions and moving window bounds. */
  needKey: string; evidenceFingerprint: string; policyVersion: string; exerciseLabel: string; objective: string;
  evidenceSummary?: {assessedSessions:number;distinctDays:number;latestAtMillis:number};
  title: string; summary: string; explanations: string[]; target: QueueTarget; targetLabel: string;
}
/** Only trusted server composition may supply these reviewed adapters. Derivation
 * must abstain on missing schema/mode/quality; no network inference in a tx. */
export interface ReviewedCanonicalRuntime {
  reviewId: string; enabledTuples: readonly WorkoutModelTuple[]; notices: readonly ReviewedConsentNoticePolicy[];
  maximumAgeMillis: number; expiresAfterMillis: number; cooldownMillis: number;
  listAcceptedIds(tx: TransactionPort, org: string, member: string): Promise<readonly string[]>;
  derive(sessions: readonly AcceptedCanonicalSession[], now: number, profile: unknown): CanonicalSuggestion | null;
  resolveTarget(tx: TransactionPort, org: string, suggestion: CanonicalSuggestion, now: number): Promise<CurrentRecommendationTarget | null>;
  listIds(tx: TransactionPort, org: string, member: string | null, afterId: string | null): Promise<readonly string[]>;
}
export interface CanonicalRecord extends DocumentData {
  schemaVersion: 1; mode: 'accepted_workout'; organizationId: string; memberId: string; id: string;
  revision: number; status: 'pending'|'prepared'|'delivered'|'dismissed'|'withdrawn'; suggestion: CanonicalSuggestion;
  consentFingerprint: string; createdAtMillis: number; expiresAtMillis: number; deliveredAtMillis: number|null;
  readAtMillis: number|null; acknowledgedAtMillis: number|null; dismissedAtMillis: number|null;
}
const unavailable = () => new DomainError('failed-precondition', 'Current canonical evidence, consent and target are required.');
const path = (org: string, id: string) => `orgs/${org}/canonicalRecommendations/${id}`;
function runtimeReady(runtime: ReviewedCanonicalRuntime) {
  requiredIdentifier(runtime.reviewId, 'review');
  if (!runtime.enabledTuples.length || !runtime.notices.length || !Number.isSafeInteger(runtime.maximumAgeMillis) || runtime.maximumAgeMillis <= 0 ||
    !Number.isSafeInteger(runtime.expiresAfterMillis) || runtime.expiresAfterMillis <= 0 || !Number.isSafeInteger(runtime.cooldownMillis) || runtime.cooldownMillis < 0) throw unavailable();
}
function record(raw: DocumentData | undefined, org: string, id: string, now=Number.MAX_SAFE_INTEGER): CanonicalRecord {
  if (!raw || raw.schemaVersion !== 1 || raw.mode !== 'accepted_workout' || raw.organizationId !== org || raw.id !== id ||
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
  keys(object(s),['needKey','evidenceFingerprint','policyVersion','exerciseLabel','objective','title','summary','explanations','target','targetLabel','evidenceSummary']);
  requiredIdentifier(s.needKey, 'need'); requiredIdentifier(s.policyVersion, 'policy');
  if (!/^[a-f0-9]{64}$/.test(s.evidenceFingerprint) || !s.exerciseLabel || s.exerciseLabel.length > 120 ||
    !OBJECTIVES.includes(s.objective as typeof OBJECTIVES[number]) || !s.title || s.title.length > 120 || !s.summary || s.summary.length > 400 ||
    !s.targetLabel || s.targetLabel.length > 200 || !Array.isArray(s.explanations) || s.explanations.length > 6 ||
    s.explanations.some(e => typeof e !== 'string' || e.length > 300)) throw unavailable();
  if(s.evidenceSummary!==undefined){
    const e=object(s.evidenceSummary);keys(e,['assessedSessions','distinctDays','latestAtMillis']);
    if(!Number.isSafeInteger(e.assessedSessions)||Number(e.assessedSessions)<1||Number(e.assessedSessions)>200||!Number.isSafeInteger(e.distinctDays)||Number(e.distinctDays)<1||Number(e.distinctDays)>Number(e.assessedSessions)||!Number.isSafeInteger(e.latestAtMillis)||Number(e.latestAtMillis)<=0)throw unavailable();
  }
  parseQueueTarget(s.target, org);
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

export interface CanonicalLifecycleDependencies {store:DocumentStore;runtime:ReviewedCanonicalRuntime;clock?:()=>number;readAuthIdentity:(uid:string)=>Promise<FreshAuthIdentity>}
export function createCanonicalRecommendationLifecycle(deps: CanonicalLifecycleDependencies) {
  const {runtime, store} = deps;
  const nowOf = () => {const n = (deps.clock ?? Date.now)(); if (!Number.isSafeInteger(n) || n <= 0) throw unavailable(); return n;};
  async function privacy(tx: TransactionPort, org: string, member: string, now: number, delivery = false) {
    if(await tx.get(`datasetAssignments/${member}`))throw unavailable();
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
    return {fingerprint: digestOf(consent), historyStart: Math.max(...allowed.map(d => Number(d.historyStartAtMillis)))};
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
    const suggestion = await derive(tx, r.organizationId, r.memberId, now, consent.historyStart);
    if (!suggestion || digestOf(suggestion) !== digestOf(r.suggestion)) throw unavailable();
    const target = await runtime.resolveTarget(tx, r.organizationId, suggestion, now);
    if (!target || digestOf(target.target) !== digestOf(suggestion.target)) throw unavailable();
    return target;
  }
  return {
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
        const target = await runtime.resolveTarget(tx, org, suggestion, now); if (!target) return {status: 'abstained' as const};
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
        if(action==='dismiss')tx.set(`orgs/${org}/canonicalRecommendationFatigue/${digestOf({member:r.memberId,need:r.suggestion.needKey})}`,{untilMillis:now+runtime.cooldownMillis});
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
            receipt.deliveredAtMillis!==r.deliveredAtMillis || notification.mode!=='accepted_workout' || notification.recipientId !== r.memberId ||
            notification.recommendationId !== id || notification.createdAtMillis!==r.deliveredAtMillis || notification.title!==r.suggestion.title) throw unavailable();
          return {id, status: 'delivered' as const};
        }
        if (r.status !== 'prepared' || receipt || notification) throw unavailable();
        tx.create(notificationPath, {schemaVersion: 1, type: 'recommendation', mode: 'accepted_workout', recipientId: r.memberId,
          recommendationId: id, recommendationKind: r.suggestion.target.kind, title: r.suggestion.title, message: 'Open to review this suggestion.', createdAtMillis: now, read: false});
        tx.create(receiptPath, {schemaVersion: 1, id, memberId: r.memberId, fingerprint: digestOf(r.suggestion), deliveredAtMillis: now});
        tx.set(path(org, id), {...r, status: 'delivered', revision: r.revision + 1, deliveredAtMillis: now});
        tx.set(`orgs/${org}/canonicalRecommendationFatigue/${digestOf({member: r.memberId, need: r.suggestion.needKey})}`, {untilMillis: now + runtime.cooldownMillis});
        return {id, status: 'delivered' as const};
      });
    },
    async member(auth: InsightsAuth, org: string, id: string, action: 'get'|'resolve'|'read'|'acknowledge'|'dismiss', expectedRevision: number|null, commandId: string|null) {
      runtimeReady(runtime); const now = nowOf();
      return store.transact(async tx => {
        await requireRecommendationMember(tx, auth, org);
        if(await tx.get(`datasetAssignments/${auth.uid}`))throw new DomainError('permission-denied','Canonical account required.');
        const raw = await tx.get(path(org, id));
        if (!raw || raw.memberId !== auth.uid) throw new DomainError('permission-denied', 'Recommendation unavailable.');
        const r = record(raw, org, id,now);
        const receipt = await tx.get(`orgs/${org}/canonicalRecommendationDeliveries/${id}`);
        const notificationPath=`orgs/${org}/notifications/${digestOf({canonicalRecommendation:id})}`;
        const notification=await tx.get(notificationPath);
        if(r.deliveredAtMillis===null){if(receipt||notification)throw unavailable();}
        else if(!receipt||receipt.schemaVersion!==1||receipt.id!==id||receipt.memberId!==auth.uid||receipt.fingerprint!==digestOf(r.suggestion)||
          receipt.deliveredAtMillis!==r.deliveredAtMillis||!notification||notification.schemaVersion!==1||notification.mode!=='accepted_workout'||
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
        function detail(value:CanonicalRecord):Omit<MemberRecommendationDetail,'mode'>&{mode:'accepted_workout'}{
          const available=state==='available'&&target!==null;
          const title=available?value.suggestion.title:state==='dismissed'?'Recommendation dismissed':state==='expired'?'Recommendation expired':
            state==='not_delivered'?'Recommendation pending delivery':'Recommendation unavailable';
          return{schemaVersion:1,mode:'accepted_workout',organizationId:org,recommendationId:id,kind:value.suggestion.target.kind,revision:value.revision,state,title,
            summary:available?value.suggestion.summary:'You can browse current tutorials and Coaches.',
            exerciseLabel:available?value.suggestion.exerciseLabel:null,objective:available?value.suggestion.objective as MemberRecommendationDetail['objective']:null,
            explanations:available?value.suggestion.explanations:[],target:available?target!.target:null,targetLabel:available?target!.label:null,
            specialization:available?target!.specialization:null,imageUrl:available?target!.imageUrl:null,photoPath:available?target!.photoPath:null,
            createdAtMillis:value.createdAtMillis,deliveredAtMillis:value.deliveredAtMillis,expiresAtMillis:value.expiresAtMillis,
            readAtMillis:value.readAtMillis,acknowledgedAtMillis:value.acknowledgedAtMillis,dismissedAtMillis:value.dismissedAtMillis};
        }
        if (!['get','resolve'].includes(action)) {
          requiredIdentifier(commandId, 'command');
          const commandPath = `orgs/${org}/canonicalRecommendationCommands/${digestOf({actor: auth.uid, commandId})}`;
          const fingerprint = digestOf({id, action, expectedRevision}); const command = await tx.get(commandPath);
          if (command) {if (command.fingerprint !== fingerprint) throw new DomainError('aborted', 'Command reused.'); return detail(r);}
          if (r.revision !== expectedRevision) throw new DomainError('aborted', 'Recommendation changed.');
          if(r.deliveredAtMillis===null||action!=='dismiss'&&state!=='available')throw unavailable();
          const changed=action==='read'?r.readAtMillis===null:action==='acknowledge'?r.acknowledgedAtMillis===null:r.dismissedAtMillis===null;
          const updated = {...r, revision: r.revision + (changed?1:0), ...(action === 'read' ? {readAtMillis: r.readAtMillis ?? now} :
            action === 'acknowledge' ? {acknowledgedAtMillis: r.acknowledgedAtMillis ?? now} : {dismissedAtMillis: r.dismissedAtMillis ?? now})};
          // Read does not imply acknowledgment; neither implies booking/use.
          if(changed)tx.set(path(org, id), updated);
          if(action==='read'&&changed&&notification)tx.set(notificationPath,{...notification,read:true});
          if(action==='dismiss')tx.set(`orgs/${org}/canonicalRecommendationFatigue/${digestOf({member:r.memberId,need:r.suggestion.needKey})}`,{untilMillis:now+runtime.cooldownMillis});
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
        const redacted=()=>({schemaVersion:1,mode:'accepted_workout',organizationId:org,id:r.id,memberId:r.memberId,
          revision:r.revision,status:'withdrawn',redacted:true,kind:r.suggestion.target.kind,
          createdAtMillis:r.createdAtMillis,expiresAtMillis:r.expiresAtMillis,deliveredAtMillis:r.deliveredAtMillis});
        try {
          const permission=await privacy(tx,org,r.memberId,now,true);
          if(permission.fingerprint!==r.consentFingerprint)return redacted();
        } catch(error) {
          if(!(error instanceof DomainError)||error.code!=='failed-precondition')throw error;
          return redacted();
        }
        if(r.status==='pending'||r.status==='prepared') {
          try { await current(tx,r,now); }
          catch(error) {
            if(!(error instanceof DomainError)||error.code!=='failed-precondition')throw error;
            return redacted();
          }
        }
        return r;});
    },
  };
}
