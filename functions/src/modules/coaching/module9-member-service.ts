import type { DocumentData, DocumentStore } from '../../platform/firestore/store';
import { requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import { requiredIdentifier, InputValidationError } from '../../platform/validation';
import { allowed, object, integer } from './coach-availability-contracts';
import { currentBookingMembership, requireBookingOrganization } from './booking-validation';
import {parseQueueTarget,type QueueTarget} from '../recommendation/recommendation-queue-contracts';
import type {MemberRecommendationState} from '../recommendation/recommendation-member-contracts';

type Auth = { uid: string; token: Record<string, unknown> } | undefined;
const isRecommendation=(data:DocumentData)=>data.type==='recommendation'||Object.hasOwn(data,'recommendationId')||Object.hasOwn(data,'recommendationKind');
export interface SafeRecommendationNotice {
  schemaVersion:1;recommendationId:string;kind:'trainer'|'content';state:MemberRecommendationState;expiresAtMillis:number;target:QueueTarget|null;
}
export interface RecommendationNoticeProjection {title:string;message:string;recommendation:SafeRecommendationNotice}
export interface NotificationReader {
  list(org: string, uid: string, afterId?: string): Promise<{ id: string; data: DocumentData }[]>;
  /** Protected purpose/current-target projection supplied only by reviewed local composition. */
  projectRecommendation?(org:string,uid:string,id:string,data:DocumentData):Promise<RecommendationNoticeProjection>;
}
export async function module9MemberCommand(store: DocumentStore, auth: Auth, raw: unknown, clock = Date.now, reader?: NotificationReader) {
  requireVerifiedEmail(auth);
  const d = object(raw);
  allowed(d, ['schemaVersion', 'organizationId', 'action', 'enabled', 'expectedRevision', 'notificationId', 'afterId']);
  if (d.schemaVersion !== 1) throw new InputValidationError('schemaVersion 1 is required.');
  const org = requiredIdentifier(d.organizationId, 'organizationId'), uid = requiredIdentifier(auth!.uid, 'actorId');
  const authorize = async (tx: Parameters<Parameters<DocumentStore['transact']>[0]>[0]) => {
    const actor = await currentBookingMembership(tx, org, uid);
    await requireBookingOrganization(tx, org);
    if (actor.role !== 'member') throw new DomainError('permission-denied', 'Member access required.');
  };
  if (d.action === 'inbox') {
    if (!reader) throw new DomainError('unavailable', 'Notification inbox unavailable.');
    const afterId = d.afterId === undefined ? undefined : requiredIdentifier(d.afterId, 'afterId');
    await store.transact(authorize);
    const rows = await reader.list(org, uid, afterId);
    await store.transact(authorize);
    if (rows.length > 31) throw new DomainError('failed-precondition', 'Notification list requires review.');
    const records=[];
    for(const {id,data} of rows.slice(0,30)) {
      if (data.schemaVersion !== 1 || data.recipientId !== uid || typeof data.title !== 'string' || typeof data.message !== 'string'
        || !Number.isSafeInteger(data.createdAtMillis) || typeof data.read !== 'boolean') throw new DomainError('failed-precondition', 'Notification requires review.');
      const record={ id, title: data.title, message: data.message, bookingId: data.bookingId ?? null, createdAtMillis: data.createdAtMillis, read: data.read };
      if(!isRecommendation(data)){records.push(record);continue;}
      if(data.type!=='recommendation')throw new DomainError('failed-precondition','Recommendation type requires review.');
      if(!reader.projectRecommendation){records.push({...record,title:'Recommendation unavailable',message:'Personalized recommendations are unavailable in this release.',bookingId:null});continue;}
      const p=await reader.projectRecommendation(org,uid,id,data),r=object(p.recommendation);
      if(Object.keys(p).length!==3||Object.keys(p).some(k=>!['title','message','recommendation'].includes(k))||typeof p.title!=='string'||!p.title.trim()||p.title.length>200||typeof p.message!=='string'||p.message.length>500||Object.keys(r).length!==6||Object.keys(r).some(k=>!['schemaVersion','recommendationId','kind','state','expiresAtMillis','target'].includes(k))||r.schemaVersion!==1||r.recommendationId!==data.recommendationId||typeof r.recommendationId!=='string'||!/^[a-f0-9]{64}$/.test(r.recommendationId)||r.kind!==data.recommendationKind||(r.kind!=='trainer'&&r.kind!=='content')||!['available','not_delivered','expired','withdrawn','dismissed','unavailable'].includes(r.state as string)||!Number.isSafeInteger(r.expiresAtMillis)||Number(r.expiresAtMillis)<=0||(r.state==='available')!==(r.target!==null))throw new DomainError('failed-precondition','Recommendation projection requires review.');
      const target=r.target===null?null:parseQueueTarget(r.target,org);if(target&&target.kind!==r.kind)throw new DomainError('failed-precondition','Recommendation kind mismatch.');
      records.push({...record,title:p.title,message:p.message,bookingId:null,recommendation:{schemaVersion:1,recommendationId:r.recommendationId,kind:r.kind,state:r.state,expiresAtMillis:r.expiresAtMillis,target}});
    }
    await store.transact(authorize);
    return { schemaVersion: 1, records, nextAfterId: rows.length > 30 ? rows[29].id : null };
  }
  return store.transact(async tx => {
    await authorize(tx);
    if (d.action === 'sharing') {
      const path = `orgs/${org}/coachSharing/${uid}`, existing = await tx.get(path);
      const revision = existing ? integer(existing.revision, 0) : 0;
      if (d.enabled === undefined) return { schemaVersion: 1, enabled: existing?.enabled === true, revision };
      if (typeof d.enabled !== 'boolean') throw new InputValidationError('enabled must be a boolean.');
      if (integer(d.expectedRevision, 0) !== revision) throw new DomainError('aborted', 'Sharing settings changed. Reload and try again.');
      tx.set(path, { schemaVersion: 1, organizationId: org, memberId: uid, enabled: d.enabled, revision: revision + 1, updatedAtMillis: clock() });
      return { schemaVersion: 1, enabled: d.enabled, revision: revision + 1 };
    }
    if (d.action === 'readNotification') {
      const id = requiredIdentifier(d.notificationId, 'notificationId'), path = `orgs/${org}/notifications/${id}`;
      const n = await tx.get(path);
      if (!n || n.schemaVersion !== 1 || n.recipientId !== uid) throw new DomainError('permission-denied', 'Notification unavailable.');
      if(isRecommendation(n))throw new DomainError('failed-precondition','Use the protected recommendation service to record reads.');
      tx.set(path, { ...n, read: true });
      return { schemaVersion: 1, id, read: true };
    }
    throw new InputValidationError('Unsupported Member action.');
  });
}
