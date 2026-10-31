import {getFirestore,FieldPath} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {requireVerifiedEmail} from '../../platform/auth-context';
import {DomainError} from '../../platform/errors';
import {FirestoreStore} from '../../platform/firestore/firestore-store';
import {InputValidationError} from '../../platform/validation';
import {freshRewardAuth, rewardsOrganization} from './reward-command-security';
import {miniGameRounds} from './mini-game-rounds';
import {miniGameCompetitionEnvelope} from './mini-game-competition';

/** Owned round timing only; neither competition nor timing grants Reward Points. */
export const miniGameRoundCommand = onCall({region:'asia-southeast1', enforceAppCheck:true,
  timeoutSeconds:30, maxInstances:5, memory:'512MiB', concurrency:1}, async request => {
  try {
    if (!request.app) throw new DomainError('unauthenticated', 'App verification required.');
    requireVerifiedEmail(request.auth);
    const org = rewardsOrganization.value();
    if (!org || (request.data as Record<string,unknown> | null)?.organizationId !== org) throw new DomainError('permission-denied','Round organization unavailable.');
    const db=getFirestore();
    if((request.data as Record<string,unknown>)?.action==='competition'){return await miniGameCompetitionEnvelope(new FirestoreStore(db),request.auth,request.data,{freshAuth:freshRewardAuth,rows:async(gameId,after,limit)=>{let q=db.collection(`orgs/${org}/miniGameScoreBests`).where('gameId','==',gameId).orderBy(FieldPath.documentId()).limit(limit);if(after)q=q.startAfter(after);return(await q.get()).docs.map(d=>({id:d.id,data:d.data()}));}});}
    return await miniGameRounds(new FirestoreStore(db), request.auth, request.data, {freshAuth:freshRewardAuth});
  } catch (e) {
    if (e instanceof DomainError) throw new HttpsError(e.code,e.message);
    if (e instanceof InputValidationError) throw new HttpsError('invalid-argument',e.message);
    throw new HttpsError('unavailable','Round timing could not be confirmed. Retry the same command.');
  }
});
