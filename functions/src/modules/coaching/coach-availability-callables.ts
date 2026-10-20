import { getFirestore } from 'firebase-admin/firestore';
import { onCall } from 'firebase-functions/v2/https';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { coachCommandError } from './coach-profile-callables';
import { getCoachAvailabilityService, saveCoachAvailabilityDayService, getCoachRosterService, saveCoachRosterService } from './coach-availability-service';

export const getCoachRosterCommand = onCall({ enforceAppCheck: true }, async request => {
  try { return await getCoachRosterService(new FirestoreStore(getFirestore()), request.auth, request.data); }
  catch (error) { throw coachCommandError(error); }
});
export const saveCoachRosterCommand = onCall({ enforceAppCheck: true }, async request => {
  try { return await saveCoachRosterService(new FirestoreStore(getFirestore()), request.auth, request.data); }
  catch (error) { throw coachCommandError(error); }
});

export const getCoachAvailabilityCommand = onCall(async request => {
  try { return await getCoachAvailabilityService(new FirestoreStore(getFirestore()), request.auth, request.data); }
  catch (error) { throw coachCommandError(error); }
});
export const saveCoachAvailabilityDayCommand = onCall(async request => {
  try { return await saveCoachAvailabilityDayService(new FirestoreStore(getFirestore()), request.auth, request.data); }
  catch (error) { throw coachCommandError(error); }
});
