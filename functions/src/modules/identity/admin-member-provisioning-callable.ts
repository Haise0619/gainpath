import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { warn } from 'firebase-functions/logger';
import { defineSecret, defineString } from 'firebase-functions/params';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { coachCommandError } from '../coaching/coach-profile-callables';
import { FirestoreStore } from '../../platform/firestore/firestore-store';
import { AdminMemberProvisioning } from './admin-member-provisioning';
import { BrevoEmailService } from './recovery-email';

const key = defineSecret('BREVO_API_KEY');
const sender = defineString('BREVO_SENDER_EMAIL');
const logo = defineString('PASSWORD_RECOVERY_LOGO_URL', {default: ''});
export const adminMemberProvisioning = onCall({
  region: 'asia-southeast1', enforceAppCheck: true, secrets: [key],
}, async request => {
  if (!request.data || typeof request.data !== 'object' || Array.isArray(request.data)) {
    throw new HttpsError('invalid-argument', 'Invalid member setup request.');
  }
  try {
    return await new AdminMemberProvisioning(new FirestoreStore(getFirestore()), getAuth(),
      new BrevoEmailService(key.value(), sender.value()), logo.value(), Date.now,
      stage => warn('Admin member provisioning', {stage})).execute(request.auth, request.data);
  } catch (error) {
    throw coachCommandError(error);
  }
});
