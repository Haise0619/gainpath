import {getAuth} from 'firebase-admin/auth';
import {getWorkoutBackupRuntime} from '../recommendation/workout-backup-recommendation-runtime';
import {createCanonicalNoticeProjector} from '../recommendation/canonical-notice-projection';
import type {InsightsRequest} from '../recommendation/exercise-insights-contracts';
import { FieldPath, getFirestore } from 'firebase-admin/firestore';
import { onCall } from 'firebase-functions/v2/https';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { coachCommandError } from './coach-profile-callables';
import { module9MemberCommand } from './module9-member-service';
export const module9MemberCommandCallable = onCall({ region: 'asia-southeast1', enforceAppCheck: true,
  memory: '256MiB', cpu: 1, concurrency: 80, timeoutSeconds: 60, maxInstances: 20 }, async request => {
  try {
    const db = getFirestore();
    const runtime=getWorkoutBackupRuntime();
    const projectRecommendation=runtime&&((request.data as {action?:string}|null)?.action==='inbox')?await createCanonicalNoticeProjector({runtime,store:new FirestoreStore(db),readAuthIdentity:async uid=>{
      const user=await getAuth().getUser(uid);return{uid:user.uid,email:user.email??'',emailVerified:user.emailVerified,disabled:user.disabled,tokensValidAfterMillis:user.tokensValidAfterTime?Date.parse(user.tokensValidAfterTime):0};
    }},request as unknown as InsightsRequest):undefined;
    return await module9MemberCommand(new FirestoreStore(db), request.auth, request.data, Date.now, {
      projectRecommendation,
      list: async (org, uid, afterId) => {
        let query = db.collection(`orgs/${org}/notifications`).where('recipientId', '==', uid).orderBy('createdAtMillis', 'desc').orderBy(FieldPath.documentId(), 'desc');
        if (afterId) {
          const cursor = await db.doc(`orgs/${org}/notifications/${afterId}`).get();
          if (!cursor.exists || cursor.data()?.recipientId !== uid) throw new Error('Invalid notification cursor');
          query = query.startAfter(cursor);
        }
        return (await query.limit(31).get()).docs.map(d => ({ id: d.id, data: d.data() }));
      },
    });
  } catch (e) { throw coachCommandError(e); }
});
