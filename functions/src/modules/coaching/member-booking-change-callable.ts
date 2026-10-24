import { getFirestore } from 'firebase-admin/firestore';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { coachCommandError } from './coach-profile-callables';
import { readCoachIdentity } from './coach-identity-reader';
import { memberBookingChange, memberReschedulingOptions } from './member-booking-change-service';
import { requireVerifiedEmail } from '../../platform/auth-context';

export const memberBookingChangeCommand = onCall({enforceAppCheck:true},async request=>{
  if(!request.app)throw new HttpsError('unauthenticated','App verification is required.');
  try{
    requireVerifiedEmail(request.auth);
    const store=new FirestoreStore(getFirestore());
    return request.data?.action==='options'
      ? await memberReschedulingOptions(store,request.auth,request.data,readCoachIdentity)
      : await memberBookingChange(store,request.auth,request.data,readCoachIdentity);
  }catch(error){throw coachCommandError(error);}
});
