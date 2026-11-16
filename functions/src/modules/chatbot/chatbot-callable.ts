import { randomUUID } from 'node:crypto';
import { getFirestore, FieldPath, type Firestore } from 'firebase-admin/firestore';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { readCoachIdentity } from '../coaching/coach-identity-reader';
import { AssistantBookingTools, type AssistantCoachAvailability } from './assistant-booking-tools';
import type { CoachIdentityReader } from '../coaching/coach-profile-service';
import { defineSecret } from 'firebase-functions/params';
import { HttpsError, onCall, type CallableRequest } from 'firebase-functions/v2/https';
import { requireActiveMembership, requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import { personalMetricsIntent, runGemini, SAFETY_REPLY, unsafeRequest, unsupportedPersonalMetrics, validateInput, type AssistantMetrics, privateProviderApproved, PERSONAL_FACTS_UNVERIFIED_REPLY, coachAvailabilityRequest, withinAssistantDeadline } from './chatbot-service';
const key = defineSecret('GEMINI_API_KEY');
const bookingActionClaim=(text:string)=>/\b(booked|reserved|emailed|scheduled)\b|\b(?:booking|session|payment|email|calendar)\b.{0,35}\b(?:confirmed|created|sent|taken|updated|completed)\b/i.test(text);
const noBookingAction='I have not booked, paid, emailed or changed your calendar. Ask me for available coaching times, then review a suggestion in checkout.';

export async function fitnessAssistantHandler(request: CallableRequest, dependencies: { db?: Firestore; apiKey?: string; fetcher?: typeof fetch; clock?: () => number; readIdentity?:CoachIdentityReader; fypScopeHandled?:boolean } = {}): Promise<unknown> {
  const started=Date.now();
  const metrics:AssistantMetrics={providerRequests:0,toolCalls:0,inputTokens:0,outputTokens:0,thinkingTokens:0,usageComplete:true};
  try {
    if (!request.app) throw new HttpsError('unauthenticated', 'App verification is required.');
    requireVerifiedEmail(request.auth);
    const input = validateInput(request.data), uid = request.auth!.uid, org = input.organizationId;
    if(request.auth!.token.fypAuthCreatedAtMillis!==undefined&&!dependencies.fypScopeHandled){
      const {createFypDatasetBackend}=await import('../dataset/fyp-backend');
      const {resolveFypRuntimeRelease}=await import('../dataset/fyp-runtime-release');
      const {getAuth}=await import('firebase-admin/auth');
      const db=dependencies.db??getFirestore();
      const release=await resolveFypRuntimeRelease(db);
      return await createFypDatasetBackend({db,auth:getAuth(),release,assistant:{apiKey:dependencies.apiKey??key.value(),fetcher:dependencies.fetcher}}).command({app:{appId:request.app!.appId},auth:request.auth,data:{schemaVersion:1,operation:'member.assistant',data:request.data}});
    }
    const db = dependencies.db ?? getFirestore(), now = (dependencies.clock ?? Date.now)();
    const stateRef = db.doc(`orgs/${org}/members/${uid}/chatbot/state`);
    const requireCanonical = (u: any, m: any, organization: any) => {
      if (u?.organizationId !== org || organization?.status !== 'active' || requireActiveMembership(m).role !== 'member' || m?.organizationId !== org || (m?.userId !== undefined && m.userId !== uid) ||
          (u.accountLifecycle !== undefined && (!u.accountLifecycle || typeof u.accountLifecycle !== 'object' || u.accountLifecycle.schemaVersion !== 1 || u.accountLifecycle.state !== 'active' || u.accountLifecycle.revocationPending !== false || !Number.isSafeInteger(u.accountLifecycle.sessionNotBeforeSeconds) || Number(request.auth!.token.auth_time ?? 0) < u.accountLifecycle.sessionNotBeforeSeconds))) throw new HttpsError('permission-denied', 'An active member account is required.');
    };
    const reauthorize = () => db.runTransaction(async tx => {
      const [user, member, organization] = await tx.getAll(db.doc(`users/${uid}`), db.doc(`orgs/${org}/members/${uid}`), db.doc(`orgs/${org}`));
      requireCanonical(user.data(), member.data(), organization.data());
    });
    const result = await db.runTransaction(async tx => {
      const [user, member, organization, disclaimerDoc, stateDoc] = await tx.getAll(db.doc(`users/${uid}`), db.doc(`orgs/${org}/members/${uid}`), db.doc(`orgs/${org}`), db.doc(`orgs/${org}/chatbotDisclaimer/config`), stateRef);
      const u = user.data(), m = member.data();
      requireCanonical(u, m, organization.data());
      const disclaimer = disclaimerDoc.data();
      if (!disclaimer || disclaimer.isActive !== true || typeof disclaimer.text !== 'string' || !disclaimer.text.trim() || disclaimer.text.length > 10000 || !Number.isSafeInteger(disclaimer.revision) || disclaimer.revision < 1) throw new HttpsError('failed-precondition', 'The organization disclaimer is unavailable.');
      const previous = stateDoc.data() ?? {};
      const state = { schemaVersion: 1, acknowledgedRevision: Number(previous.acknowledgedRevision ?? 0), bookmarks: Array.isArray(previous.bookmarks) ? previous.bookmarks.filter((v: unknown) => typeof v === 'string' && v.length <= 6000).slice(-50) : [], ratings: Array.isArray(previous.ratings) ? previous.ratings.slice(-100) : [], rateWindowMillis: Number(previous.rateWindowMillis ?? 0), rateCount: Number(previous.rateCount ?? 0) };
      if (input.action === 'bootstrap') return { disclaimer: { text: disclaimer.text, revision: disclaimer.revision }, acknowledged: state.acknowledgedRevision === disclaimer.revision, bookmarks: state.bookmarks, contextMode:privateProviderApproved()?'private-approved':'public' };
      if (input.action === 'acknowledge') {
        if (input.disclaimerRevision !== disclaimer.revision) throw new HttpsError('failed-precondition', 'Please review the current disclaimer.');
        state.acknowledgedRevision = disclaimer.revision;
      } else {
        if (state.acknowledgedRevision !== disclaimer.revision) throw new HttpsError('failed-precondition', 'Acknowledge the current disclaimer first.');
        if (input.action === 'reply') {
          if (now - state.rateWindowMillis >= 60000) { state.rateWindowMillis = now; state.rateCount = 0; }
          if (state.rateCount >= 10) throw new HttpsError('resource-exhausted', 'Please wait before sending another message.');
          state.rateCount++;
        }
        if (input.action === 'bookmark') state.bookmarks = [...new Set([...state.bookmarks, input.text!])].slice(-50);
        if (input.action === 'removeBookmark') state.bookmarks = state.bookmarks.filter((t: string) => t !== input.text);
        if (input.action === 'rate') state.ratings = [...state.ratings.filter((r: any) => r.responseId !== input.responseId), { responseId: input.responseId!, helpful: input.helpful!, atMillis: now }].slice(-100);
      }
      tx.set(stateRef, state);
      return { ok: true, bookmarks: state.bookmarks, contextMode:privateProviderApproved()?'private-approved':'public' };
    });
    if (input.action !== 'reply') return result;
    const progress = async () => {
      await reauthorize();
      const rows = await db.collection(`orgs/${org}/workoutSessions`).where('memberId', '==', uid).limit(101).get();
      const accepted = rows.docs.slice(0, 100).map(d => d.data()).filter(d => d.status === 'accepted');
      const ids = new Set(accepted.map(d => d.sessionId));
      const device = (input.deviceProgress?.sessions ?? []).filter(s => !ids.has(s.sessionId));
      return { source: 'server-confirmed accepted workouts; device reports are unverified and may be unuploaded', sessions: accepted.length, repetitions: accepted.reduce((sum, d) => sum + (Number.isSafeInteger(d.repetitions) && d.repetitions >= 0 ? d.repetitions : 0), 0), deviceSessions: device.length, deviceRepetitions: device.reduce((sum, d) => sum + d.repetitions, 0), truncated: rows.size > 100 };
    };
    let requestedProgress: Awaited<ReturnType<typeof progress>> | undefined;
    const sources = new Set<string>();
    let bookingReadReply:string|undefined;
    let personalReadRefused=false;
    let coachSuggestions: unknown[]|undefined;
    let coachAvailability:AssistantCoachAvailability|undefined;
    const bookingTools = new AssistantBookingTools(new FirestoreStore(db),request.auth,org,async after=>{
      let query=db.collection(`orgs/${org}/coaches`).where('status','==','published').orderBy(FieldPath.documentId()).limit(21);
      if(after)query=query.startAfter(after);
      return (await query.get()).docs.map(d=>d.id);
    },dependencies.readIdentity??readCoachIdentity,()=>now);
    const progressText = (facts: Awaited<ReturnType<typeof progress>>) => `Your server-confirmed records contain ${facts.sessions} accepted workout sessions and ${facts.repetitions} repetitions${facts.truncated ? ' in this bounded sample (more records may exist)' : ''}. ${input.deviceProgress?.unavailable ? 'Device progress could not be loaded; its totals are unknown.' : input.deviceProgress ? `Your device additionally reports ${facts.deviceSessions} sessions and ${facts.deviceRepetitions} repetitions from the supplied records within the last 90 days; these are unverified and may be unuploaded.${input.deviceProgress.truncated ? ' This device sample is limited; older records may exist.' : ''}` : 'Device progress was not supplied; its totals are unknown.'} Matching session IDs are counted only in server records. Distance, calories burned, weight changes, and other measurements are unavailable from these records. These records cannot establish a diagnosis or guarantee improvement.`;
    const execute = async (name: string,args:Record<string,unknown> = {}) => {
      if(name==='get_my_progress'&&!personalMetricsIntent(input.text!)){personalReadRefused=true;return{available:false,reason:'An explicit personal-progress question is required.'};}
      sources.add(name);
      if(['list_coaches','get_coaching_options','propose_booking'].includes(name)){
        await reauthorize();const value=await bookingTools.execute(name,args) as any;
        if(name==='list_coaches'){
          coachSuggestions=value.items.map((coach:any)=>({
            coachId:coach.coachId,name:coach.name,branchName:coach.branchName,
            amountMinor:coach.amountMinor,durationMinutes:60,currency:'MYR',
          }));
          bookingReadReply=value.items.length
            ? 'These are eligible published Coaches. Choose one to check current times and the final price before booking.'
            : 'No eligible published Coaches were found on this directory page. Availability has not been checked; browse the directory for other options.';
        }
        if(name==='get_coaching_options')bookingReadReply=value.items.length
          ? `Available times for ${value.localDate} (${value.timeZone}), ${value.durationMinutes} minutes:\n${value.items.slice(0,12).map((s:any)=>`${s.coachName}: ${s.startLabel} – ${s.endLabel} · ${s.branchName} · RM ${(s.amountMinor/100).toFixed(2)}`).join('\n')}${value.items.length>12?'\nMore times are available; specify your preferred time.':''}\nNothing is reserved. Ask for an exact time to review a suggestion in checkout.`
          : `No eligible times are available on ${value.localDate} (${value.timeZone}). Choose another date or check My bookings for an existing session or hold.`;
        return value;
      }
      if (name === 'get_my_progress') { requestedProgress = await progress(); return { ...requestedProgress, deviceUnavailable: input.deviceProgress?.unavailable ?? !input.deviceProgress, deviceTruncated: input.deviceProgress?.truncated ?? false }; }
      if (name !== 'find_equipment') throw new HttpsError('invalid-argument', 'Unknown read tool.');
      await reauthorize();
      const rows = await db.collection(`orgs/${org}/gymEquipment`).where('isActive', '==', true).limit(51).get();
      return { items: rows.docs.slice(0, 50).map(d => {
        const data = d.data();
        const steps = (raw: unknown) => Array.isArray(raw) ? raw.filter((s: unknown) => typeof s === 'string').slice(0, 10).map((s: string) => s.slice(0, 400)) : [];
        return { name: String(data.name ?? '').slice(0, 160), description: String(data.description ?? '').slice(0, 600), category: String(data.category ?? '').slice(0, 80), muscleGroup: String(data.muscleGroup ?? '').slice(0, 80), howToUse: steps(data.howToUse), safetyTips: steps(data.safetyTips) };
      }), truncated: rows.size > 50 };
    };
    let text: string;
    if (unsafeRequest(input.text!)) text = SAFETY_REPLY;
    else if(coachAvailabilityRequest(input.text!)){
      await reauthorize();
      coachAvailability=await withinAssistantDeadline(bookingTools.availableCoaches(coachAvailabilityRequest(input.text!)!),40000);
      metrics.toolCalls=bookingTools.availabilityToolCalls;
      sources.add('list_coaches');sources.add('get_coaching_options');
      const relativeDay=coachAvailabilityRequest(input.text!)?.dayOffset;
      const when=`${relativeDay===1?'Tomorrow · ':relativeDay===0?'Today · ':''}${coachAvailability.localDate} (${coachAvailability.timeZone})`;
      text=coachAvailability.items.length
        ? `These Coaches have verified 60-minute times on ${when}. Nothing is reserved or paid. Review a time in checkout; price and availability are checked again.${coachAvailability.truncated?' This is a limited selection; additional Coaches or times may exist.':''}`
        : `No eligible 60-minute times were found on ${when} in the checked Coach directory page.${coachAvailability.truncated?' More Coaches may exist on another page.':''} This does not mean every Coach is unavailable. Try another date or browse Coaches.`;
    }
    else if (personalMetricsIntent(input.text!)) {
      const facts = await progress();
      sources.add('get_my_progress');
      text = progressText(facts);
    } else {
      let publicBookingContext:unknown;
      const hint=input.bookingContext;
      if(hint&&hint.expiresAtMillis>now&&hint.expiresAtMillis<=now+300000){
        // Never forward raw client context. Re-read public Coach/slot/price facts
        // under current scope before providing follow-up context to the model.
        try{
          await reauthorize();
          publicBookingContext=await bookingTools.execute('get_coaching_options',{coachId:hint.coachId,localDate:hint.localDate,durationMinutes:hint.durationMinutes});
          sources.add('get_coaching_options');
        }catch{
          // A former selection is a hint, not a prerequisite for asking an
          // unrelated question. Still reject any canonical account revocation.
          await reauthorize();publicBookingContext=undefined;bookingTools.context=undefined;
        }
      }
      text = await runGemini(dependencies.apiKey ?? key.value(), input.text!, input.history ?? [], execute, dependencies.fetcher,publicBookingContext,{metrics,terminalReply:()=>bookingTools.suggestion?'Here is an available session suggestion. Nothing has been booked or charged.':bookingReadReply??(personalReadRefused?PERSONAL_FACTS_UNVERIFIED_REPLY:requestedProgress?progressText(requestedProgress):undefined)});
      if(!bookingReadReply&&!bookingTools.suggestion&&bookingActionClaim(text))text=noBookingAction;
      else if (!requestedProgress && !bookingReadReply && !bookingTools.suggestion && unsupportedPersonalMetrics(text)) {
        text = PERSONAL_FACTS_UNVERIFIED_REPLY;
      }
      if (requestedProgress) text = progressText(requestedProgress);
    }
    if (/\b(take|inject|prescrib|dose)\b.{0,60}\b(steroid|insulin|opioid|medication|drug)\b|\b(ignore|push through)\b.{0,30}\b(chest pain|injur|faint)/i.test(text)) text = SAFETY_REPLY;
    await reauthorize();
    const bookingSuggestion=bookingTools.suggestion;
    if(bookingSuggestion)text='Here is an available session suggestion. Nothing has been booked or charged. Review it in checkout; availability and price will be checked again before you continue.';
    else if(bookingReadReply)text=bookingReadReply;
    else if(!requestedProgress&&!coachAvailability&&bookingActionClaim(text))text=noBookingAction;
    return { responseId: randomUUID(), text, ...(coachAvailability?{coachAvailability}:{}), ...(coachSuggestions?{coachSuggestions}:{}), telemetry:{...metrics,responseTimeMillis:Math.max(0,Date.now()-started)}, ...(bookingTools.context?{bookingContext:bookingTools.context}:{}), ...(bookingSuggestion?{bookingSuggestion}:{}), ...(sources.size ? { sources: [...sources] } : {}) };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    if (error instanceof DomainError) throw new HttpsError(error.code, error.message);
    throw new HttpsError('unavailable', 'Assistant is temporarily unavailable. Please retry.');
  }
}
export const fitnessAssistantCommand = onCall({ enforceAppCheck: true, secrets: [key], timeoutSeconds: 60, maxInstances: 2, concurrency: 10 }, async request => {
  const result=await fitnessAssistantHandler(request) as {telemetry?:AssistantMetrics&{responseTimeMillis:number}};
  // Only server-constructed counters; never prompts, replies, identity or tool arguments.
  if(result.telemetry)console.info('fitness_assistant_metrics',result.telemetry);
  return result;
});
