import { createHash, createHmac, randomBytes, randomInt, timingSafeEqual } from 'node:crypto';
import type { Auth, UserRecord } from 'firebase-admin/auth';
import type { Firestore } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { type EmailService, passwordResetEmail } from './recovery-email';

const minute = 60_000;
const hour = 60 * minute;
const lifetime = 10 * minute;
const resendDelay = 30_000;
const invalidCode = () => new HttpsError('failed-precondition', 'Invalid or expired code.');
const invalidToken = () => new HttpsError('failed-precondition', 'Request a new verification code.');
const digest = (value: string) => createHash('sha256').update(value).digest('hex');
const matches = (expected: unknown, actual: string) =>
  typeof expected === 'string' && /^[a-f0-9]{64}$/.test(expected) &&
  timingSafeEqual(Buffer.from(expected, 'hex'), Buffer.from(actual, 'hex'));

export class PasswordRecovery {
  constructor(
    private readonly db: Firestore,
    private readonly auth: Auth,
    private readonly mail: EmailService,
    private readonly secret: string,
    private readonly logoUrl: string,
    private readonly report: (stage: string) => void,
    private readonly now = Date.now,
  ) {}

  private hmac(value: string) {
    return createHmac('sha256', this.secret).update(value).digest('hex');
  }

  private async eligible(user: UserRecord | undefined, email: string) {
    if (!user || user.disabled || user.email?.toLowerCase() !== email ||
        !user.providerData.some(provider => provider.providerId === 'password')) return false;
    const claims = user.customClaims;
    if (claims?.admin || claims?.staff || claims?.superAdmin ||
        (claims?.role && !['member', 'coach'].includes(String(claims.role)))) return false;
    const profile = (await this.db.doc(`users/${user.uid}`).get()).data();
    if (typeof profile?.organizationId !== 'string' || !profile.organizationId ||
        profile.organizationId.includes('/')) return false;
    const membership = (await this.db.doc(`orgs/${profile.organizationId}/members/${user.uid}`).get()).data();
    // Registration stores the authoritative role on the organization membership.
    return membership?.status === 'active' && ['member', 'coach'].includes(membership.role) &&
      membership.organizationId === profile.organizationId &&
      (profile.role === undefined || profile.role === membership.role);
  }

  async execute(input: unknown) {
    if (!input || typeof input !== 'object') throw new HttpsError('invalid-argument', 'Invalid request.');
    const { operation, email: rawEmail, challengeId, code, resetToken, password } =
      input as Record<string, unknown>;
    const email = typeof rawEmail === 'string' ? rawEmail.trim().toLowerCase() : '';
    if (email.length > 254 || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
      throw new HttpsError('invalid-argument', 'Enter a valid email address.');
    }
    const records = this.db.collection('passwordRecovery');
    const key = this.hmac(`email:${email}`);
    const ref = records.doc(key);

    if (operation === 'requestPasswordResetOtp') {
      const id = randomBytes(16).toString('hex');
      const otp = String(randomInt(1_000_000)).padStart(6, '0');
      let user: UserRecord | undefined;
      try {
        const account = await this.auth.getUserByEmail(email);
        if (await this.eligible(account, email)) user = account;
      } catch (error) {
        if ((error as { code?: string }).code !== 'auth/user-not-found') this.report('lookup');
      }
      const issued = await this.db.runTransaction(async tx => {
        const now = this.now();
        const previous = (await tx.get(ref)).data();
        const sent: number[] = (previous?.sent ?? []).filter((at: number) => now - at < hour);
        if (sent.length >= 5 || now - (sent.at(-1) ?? -Infinity) < resendDelay) return false;
        // Reserve provider capacity only when a message could actually be sent.
        if (user) {
          const quotaRef = records.doc('delivery-quota');
          const quota = (await tx.get(quotaRef)).data();
          const hours: Record<string, number> = quota?.hours ?? {};
          const currentHour = Math.floor(now / hour);
          const recent = Object.fromEntries(Object.entries(hours)
            .filter(([start]) => Number(start) >= currentHour - 24));
          if (Object.values(recent).reduce((total, count) => total + count, 0) >= 250) return false;
          recent[currentHour] = (recent[currentHour] ?? 0) + 1;
          tx.set(quotaRef, { hours: recent });
        }
        tx.set(ref, {
          challengeId: id,
          uid: user?.uid ?? null,
          otpDigest: this.hmac(`password-reset:${key}:${id}:${otp}`),
          expiresAt: now + lifetime,
          attempts: 0,
          failures: (previous?.failures ?? []).filter((at: number) => now - at < hour),
          sent: [...sent, now],
          status: 'issued',
        });
        return true;
      });
      if (issued && user) {
        try {
          await this.mail.send(passwordResetEmail(email, otp, this.logoUrl));
        } catch {
          this.report('delivery');
        }
      }
      return { challengeId: id, resendAfterSeconds: resendDelay / 1000 };
    }

    if (typeof challengeId !== 'string' || !/^[a-f0-9]{32}$/.test(challengeId)) {
      throw new HttpsError('invalid-argument', 'Invalid challenge.');
    }
    if (operation === 'verifyPasswordResetOtp') {
      if (typeof code !== 'string' || !/^\d{6}$/.test(code)) throw invalidCode();
      const token = randomBytes(32).toString('hex');
      const verified = await this.db.runTransaction(async tx => {
        const record = (await tx.get(ref)).data();
        const now = this.now();
        if (!record || record.challengeId !== challengeId || record.status !== 'issued' ||
            record.expiresAt <= now || record.attempts >= 5) return false;
        const failures: number[] = record.failures.filter((at: number) => now - at < hour);
        if (failures.length >= 10) return false;
        if (!record.uid || !matches(record.otpDigest,
          this.hmac(`password-reset:${key}:${challengeId}:${code}`))) {
          tx.update(ref, { attempts: record.attempts + 1, failures: [...failures, now] });
          return false;
        }
        tx.update(ref, {
          status: 'verified', otpDigest: null,
          tokenDigest: digest(`password-reset:${challengeId}:${token}`),
          tokenExpiresAt: now + lifetime,
        });
        return true;
      });
      if (!verified) throw invalidCode();
      return { resetToken: token };
    }

    if (operation === 'completePasswordReset') {
      if (typeof resetToken !== 'string' || !/^[a-f0-9]{64}$/.test(resetToken)) throw invalidToken();
      if (typeof password !== 'string' || password.length < 8 || Buffer.byteLength(password) > 4096) {
        throw new HttpsError('invalid-argument', 'Enter a password of at least 8 characters.');
      }
      const uid = await this.db.runTransaction(async tx => {
        const record = (await tx.get(ref)).data();
        if (!record?.uid || record.challengeId !== challengeId || record.status !== 'verified' ||
            record.tokenExpiresAt <= this.now() || !matches(record.tokenDigest,
              digest(`password-reset:${challengeId}:${resetToken}`))) throw invalidToken();
        // Consume before crossing the Firestore/Auth boundary, including uncertain Auth results.
        tx.update(ref, { status: 'consumed', tokenDigest: null });
        return record.uid as string;
      });
      try {
        if (!await this.eligible(await this.auth.getUser(uid), email)) throw invalidToken();
        await this.auth.updateUser(uid, { password });
        await this.auth.revokeRefreshTokens(uid);
      } catch {
        this.report('completion');
        throw new HttpsError('unavailable', 'Could not confirm the reset. Try signing in with the new password or request a new code.');
      }
      return { success: true };
    }
    throw new HttpsError('invalid-argument', 'Invalid operation.');
  }
}
