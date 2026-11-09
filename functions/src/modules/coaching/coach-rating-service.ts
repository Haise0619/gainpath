import { requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import { InputValidationError, requiredIdentifier } from '../../platform/validation';
import { readAll, type DocumentStore, type DocumentData } from '../../platform/firestore/store';
import { currentBookingMembership, requireBookingOrganization } from './booking-validation';
import { allowed, object } from './coach-availability-contracts';
export interface PublicCoachReview { stars:number; reviewText:string; reviewedAtMillis:number; authorLabel:string }
export interface CoachRatingRecord { coachId:string; reviewCount:number; averageRating:number|null; completedSessions?:number; recentReviews?:PublicCoachReview[]; branchNames?:Record<string,string> }
export interface RatingReader { aggregate(org: string, coachId: string): Promise<{ count: number; total: number }>; countCompleted?(org: string, coachId: string): Promise<number>; latestReviews?(org:string,coachId:string):Promise<{id:string;data:DocumentData}[]> }
export async function coachRatings(store: DocumentStore, auth: { uid: string; token: Record<string, unknown> } | undefined, raw: unknown, reader: RatingReader) {
  requireVerifiedEmail(auth); const d = object(raw); allowed(d, ['schemaVersion', 'organizationId', 'coachIds', 'includeAccountSummary', 'includePublicSummary']);
  const org = requiredIdentifier(d.organizationId, 'organizationId');
  if (d.schemaVersion !== 1 || !Array.isArray(d.coachIds) || d.coachIds.length > 20 || d.coachIds.length === 0) throw new InputValidationError('Choose 1–20 Coaches.');
  const ids = [...new Set(d.coachIds.map(id => requiredIdentifier(id, 'coachId')))];
  if (d.includeAccountSummary !== undefined && typeof d.includeAccountSummary !== 'boolean') throw new InputValidationError('Invalid summary option.');
  const summary = d.includeAccountSummary === true;
  if (d.includePublicSummary !== undefined && typeof d.includePublicSummary !== 'boolean') throw new InputValidationError('Invalid public summary option.');
  const publicSummary = d.includePublicSummary === true;
  if (publicSummary && ids.length !== 1) throw new InputValidationError('Choose one Coach for public details.');
  const check = () => store.transact(async tx => {
    const actor = await currentBookingMembership(tx, org, auth!.uid); await requireBookingOrganization(tx, org);
    if (summary && (actor.role !== 'coach' || ids.length !== 1 || ids[0] !== auth!.uid)) throw new DomainError('permission-denied', 'Account summary is private to the Coach.');
    const labels = summary ? await readAll(tx, actor.branchIds.map(id => `orgs/${org}/branches/${id}`)) : [];
    const profiles = await readAll(tx, ids.map(id => `orgs/${org}/coaches/${id}`));
    if (profiles.some((p, i) => p?.status !== 'published' && !(actor.role === 'coach' && ids[i] === auth!.uid))) throw new DomainError('permission-denied', 'Coach ratings unavailable.');
    if (publicSummary && profiles.some(p => p?.status !== 'published')) throw new DomainError('permission-denied', 'Public Coach details unavailable.');
    const publicIds = publicSummary && Array.isArray(profiles[0]?.branchIds) ? profiles[0]!.branchIds as unknown[] : [];
    if (publicIds.length > 8 || publicIds.some(id=>typeof id !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(id))) throw new DomainError('failed-precondition','Public profile needs review.');
    const publicBranches = await readAll(tx,publicIds.map(id=>`orgs/${org}/branches/${id}`));
    const branchNames = Object.fromEntries(publicBranches.flatMap((b,i)=>typeof b?.name==='string' && b.name.trim() ? [[String(publicIds[i]),b.name.trim()]] : []));
    return { publicBranchNames:branchNames, role: actor.role, branches: actor.branchIds, labels: labels.map((b,i) => ({id:actor.branchIds[i], name:typeof b?.name === 'string' && b.name.trim() ? b.name.trim() : null})) };
  });
  const before = await check();
  const records:CoachRatingRecord[] = await Promise.all(ids.map(async coachId => {
    const { count, total } = await reader.aggregate(org, coachId);
    if (!Number.isSafeInteger(count) || count < 0 || !Number.isSafeInteger(total) || total < count || total > count * 5) throw new DomainError('failed-precondition', 'Ratings need review.');
    const rating={coachId,reviewCount:count,averageRating:count ? total/count : null};
    if(!publicSummary)return rating;
    if(!reader.countCompleted || !reader.latestReviews)throw new DomainError('unavailable','Public Coach statistics are unavailable.');
    const [completedSessions,rows]=await Promise.all([reader.countCompleted(org,coachId),reader.latestReviews(org,coachId)]);
    const fail=()=>new DomainError('failed-precondition','Public Coach statistics need review.');
    if(!Number.isSafeInteger(completedSessions)||completedSessions<0||!Array.isArray(rows)||rows.length>10||rows.length>count)throw fail();
    const recentReviews=await store.transact(async tx=>{
      const result:{stars:number;reviewText:string;reviewedAtMillis:number;authorLabel:string}[]=[];
      const seen=new Set<string>();
      for(const row of rows){
        const r=row.data, bid=r.bookingId;
        if(typeof bid!=='string'||!/^[A-Za-z0-9_-]{1,128}$/.test(bid)||row.id!==bid||seen.has(bid)||r.schemaVersion!==1||r.coachId!==coachId||typeof r.memberId!=='string'||!Number.isInteger(r.stars)||Number(r.stars)<1||Number(r.stars)>5||!Number.isSafeInteger(r.reviewedAtMillis)||Number(r.reviewedAtMillis)<=0||Number(r.reviewedAtMillis)>Date.now()||(r.reviewText!==undefined&&(typeof r.reviewText!=='string'||r.reviewText.length>500)))throw fail();
        seen.add(bid);
        const [b,note]=await readAll(tx,[`orgs/${org}/bookings/${bid}`,`orgs/${org}/bookings/${bid}/consultation/current`]);
        if(b?.schemaVersion!==1||b.bookingId!==bid||b.coachId!==coachId||b.memberId!==r.memberId||!['completed','refunded'].includes(String(b.status))||note?.schemaVersion!==1||note.bookingId!==bid||note.coachId!==coachId||note.memberId!==r.memberId)throw fail();
        result.push({stars:Number(r.stars),reviewText:typeof r.reviewText==='string'?r.reviewText:'',reviewedAtMillis:Number(r.reviewedAtMillis),authorLabel:'Verified member'});
      }
      return result;
    });
    return {...rating,completedSessions,recentReviews,branchNames:before.publicBranchNames};
  }));
  let accountSummary: {completedSessions:number; branches:typeof before.labels} | undefined;
  if (summary) {
    if (!reader.countCompleted) throw new DomainError('unavailable', 'Account summary is unavailable.');
    const completedSessions = await reader.countCompleted(org, auth!.uid);
    if (!Number.isSafeInteger(completedSessions) || completedSessions < 0) throw new DomainError('failed-precondition', 'Session count needs review.');
    accountSummary = {completedSessions, branches:before.labels};
  }
  if (JSON.stringify(before) !== JSON.stringify(await check())) throw new DomainError('permission-denied', 'Account access changed.');
  return { schemaVersion: 1, records, ...(accountSummary ? {accountSummary} : {}) };
}
