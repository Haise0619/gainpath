import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { warn } from 'firebase-functions/logger';
import { defineSecret, defineString } from 'firebase-functions/params';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { PasswordRecovery } from './password-recovery';
import { BrevoEmailService } from './recovery-email';

const digestKey = defineSecret('PASSWORD_RECOVERY_HMAC_KEY');
const brevoKey = defineSecret('BREVO_API_KEY');
const sender = defineString('BREVO_SENDER_EMAIL');
const logo = defineString('PASSWORD_RECOVERY_LOGO_URL', { default: '' });

export const passwordRecovery = onCall({
  region: 'asia-southeast1',
  enforceAppCheck: true,
  secrets: [digestKey, brevoKey],
}, async request => {
  try {
    const key = digestKey.value();
    if (key.length < 32) throw new Error('Missing password recovery key');
    return await new PasswordRecovery(
      getFirestore(), getAuth(), new BrevoEmailService(brevoKey.value(), sender.value()),
      key, logo.value(), stage => warn('Password recovery operation failed', { stage }),
    ).execute(request.data);
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    warn('Password recovery operation failed', { stage: 'storage' });
    throw new HttpsError('unavailable', 'Password recovery is temporarily unavailable.');
  }
});
