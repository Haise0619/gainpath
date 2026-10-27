import { getFirestore, FieldPath } from 'firebase-admin/firestore';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { DomainError } from '../../platform/errors';
import { InputValidationError } from '../../platform/validation';
import { readCoachIdentity } from '../coaching/coach-identity-reader';
import { rewardsCommand } from './verified-rewards-service';
import {rewardRequest, freshRewardAuth} from './reward-command-security';
import {readPointsHistory} from './points-history';
import {readEarnedPointsLeaderboard} from './earned-points-leaderboard';

/** One scoped command surface; source production and policy publication are deliberately separate. */
export const verifiedRewardsCommand = onCall({ region: 'asia-southeast1', enforceAppCheck: true, timeoutSeconds: 60, maxInstances: 5 }, async request => {
  try {
    const auth = await rewardRequest(request), db = getFirestore(), org = request.data.organizationId;
    if(request.data.action==='leaderboard'){
      const rows=async(root:string,after:string|undefined,limit:number,uid?:string)=>{
        let query=db.collection(root).orderBy(FieldPath.documentId()).limit(limit);
        if(uid)query=query.where('memberId','==',uid);
        if(after)query=query.startAfter(after);
        return (await query.get()).docs.map(d=>({id:d.id,data:d.data()}));
      };
      const result=await readEarnedPointsLeaderboard(new FirestoreStore(db),auth,request.data,{
        members:(after,limit)=>rows(`orgs/${org}/members`,after,limit),
        receipts:(uid,source,after,limit)=>source==='claims'
          ?rows(`orgs/${org}/appCheckInProfiles/${uid}/claims`,after,limit)
          :rows(`orgs/${org}/${source==='participation'?'miniGameParticipationAwards':'rewardAwards'}`,after,limit,uid),
      });
      await freshRewardAuth(auth);return result;
    }
    if(['pointsHistory','pointsHistoryAll'].includes(request.data.action)){
      const unified=request.data.action==='pointsHistoryAll';
      if(request.data.schemaVersion!==1||Object.keys(request.data).sort().join(',')!=='action,organizationId,schemaVersion')throw new InputValidationError('Invalid points history fields.');
      const result=await readPointsHistory(new FirestoreStore(db),auth,org,async()=>{
        const root=`orgs/${org}`;
        const [claims,awards,adjustments,redemptions,participation]=await Promise.all([
          db.collection(`${root}/appCheckInProfiles/${auth.uid}/claims`).orderBy(FieldPath.documentId()).limit(201).get(),
          ...['rewardAwards','rewardPointAdjustments','rewardRedemptions',...(unified?['miniGameParticipationAwards']:[])].map(c=>db.collection(`${root}/${c}`).where('memberId','==',auth.uid).orderBy(FieldPath.documentId()).limit(201).get())]);
        const rows=(s:typeof claims)=>s.docs.map(d=>({id:d.id,data:d.data()}));
        return {claims:rows(claims),awards:rows(awards),adjustments:rows(adjustments),redemptions:rows(redemptions),participation:participation?rows(participation):[]};
      });await freshRewardAuth(auth);
      if(unified)return result;
      // Preserve the installed legacy client's response contract.
      const {demoBalance:_,demoReconciled:__,...legacy}=result;
      return {...legacy,schemaVersion:1,entries:result.entries.map(({wallet,...e})=>({...e,source:e.source==='workout_reward'?'activity_reward':e.source}))};
    }
    const result = await rewardsCommand(new FirestoreStore(db), auth, request.data, readCoachIdentity, Date.now, {page: async (uid, after, limit) => {
      let q = db.collection(`orgs/${org}/rewardRedemptions`).where('memberId', '==', uid).orderBy(FieldPath.documentId()).limit(limit);
      if (after) q = q.startAfter(after);
      return (await q.get()).docs.map(d => ({id: d.id, data: d.data()}));
    }});
    await freshRewardAuth(auth); return result;
  } catch (error) {
    if (error instanceof DomainError) throw new HttpsError(error.code, error.message);
    if (error instanceof InputValidationError) throw new HttpsError('invalid-argument', error.message);
    throw new HttpsError('unavailable', 'Reward request could not be confirmed. Retry the same request.');
  }
});
