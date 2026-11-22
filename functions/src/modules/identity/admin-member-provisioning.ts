import { randomBytes } from 'node:crypto';
import type { Auth } from 'firebase-admin/auth';
import { requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import { readAll, type DocumentStore, type TransactionPort } from '../../platform/firestore/store';
import { keyOf } from '../../platform/idempotency';
import { requiredIdentifier } from '../../platform/validation';
import { readVerifiedTargetMembershipEntitlement } from '../commerce/membership-entitlement';
import { authorizeAdminReport } from '../analytics/admin-reporting';
import { canonicalMemberRecords, validatedInput } from './member-provisioning';
import type { EmailService } from './recovery-email';

type Actor = Parameters<typeof authorizeAdminReport>[1];
type AuthPort = Pick<Auth, 'createUser' | 'getUser' | 'updateUser' |
  'generatePasswordResetLink' | 'generateEmailVerificationLink' | 'getUsers'>;
const minute = 60_000;
const hour = 60 * minute;
const authCode = (error: unknown) => (error as {code?: string} | null)?.code;
const fail = () => new DomainError('failed-precondition', 'This member setup needs Admin review.');
const setupPath = (org: string, uid: string) => `orgs/${org}/commandReceipts/${keyOf('adminMemberSetup', uid)}`;

const escapeHtml = (text: string) => text.replace(/[&<>"']/g, part =>
  ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[part]!));

export function memberSetupEmail(to: string, name: string, setup: string, verify?: string, logo = '') {
  const safeLogo = /^https:\/\/[a-z0-9.-]+\/[a-z0-9_./%-]+$/i.test(logo)
    ? `<img src="${escapeHtml(logo)}" alt="" width="44" style="display:block;margin-bottom:8px;">` : '';
  return {
    to,
    subject: 'Welcome to GainPath — Set up your account',
    textContent: [
      `Welcome to GainPath, ${name}.`,
      `Set your password: ${setup}`,
      ...(verify ? [`Verify your email: ${verify}`] : []),
      'Then sign in to the GainPath app. Your Free membership is ready once setup is complete.',
      'These secure links expire. If a link has expired, ask your gym administrator for a new setup email. Do not share these links.',
    ].join('\n\n'),
    htmlContent: `<!doctype html><html lang="en"><head><meta name="viewport" content="width=device-width, initial-scale=1"><meta charset="utf-8"></head>
<body style="margin:0;background:#f4effb;font-family:Arial,sans-serif;color:#231937;">
<table role="presentation" width="100%" cellspacing="0" cellpadding="0"><tr><td align="center" style="padding:24px 12px;">
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" bgcolor="#ffffff" style="max-width:520px;"><tr><td style="padding:26px;border-top:4px solid #f59442;">
${safeLogo}<strong style="color:#6524c5;font-size:20px;">GainPath</strong><h1 style="font-size:25px;">Welcome, ${escapeHtml(name)}</h1>
<p style="line-height:1.5;">Your gym created a GainPath Free account for you. Set a password, verify your email if prompted, and sign in to the GainPath app.</p>
<p style="margin:24px 0;"><a href="${escapeHtml(setup)}" style="display:inline-block;background:#6524c5;color:white;padding:12px 16px;border-radius:8px;text-decoration:none;font-weight:bold;">Set your password</a></p>
${verify ? `<p><a href="${escapeHtml(verify)}" style="color:#6524c5;">Verify your email</a></p>` : ''}
<p style="line-height:1.5;">These links expire. Ask your gym administrator for a new setup email if needed. Keep these links private.</p>
<p>The GainPath Team</p></td></tr></table></td></tr></table></body></html>`,
  };
}

export class AdminMemberProvisioning {
  constructor(private readonly store: DocumentStore, private readonly auth: AuthPort,
    private readonly email: EmailService, private readonly logo = '',
    private readonly clock = Date.now, private readonly report: (stage: string) => void = () => {}) {}

  private async identity(uid: string) {
    try { return await this.auth.getUser(uid); }
    catch (error) { if (authCode(error) !== 'auth/user-not-found') throw error; }
  }

  private async branch(tx: TransactionPort, org: string, id: string) {
    const data = await tx.get(`orgs/${org}/branches/${id}`);
    if (data?.status !== 'active' || (data.organizationId !== undefined && data.organizationId !== org) ||
        typeof data.displayName !== 'string' || !data.displayName.trim()) {
      throw new DomainError('failed-precondition', 'Select an active home branch in your organization.');
    }
    return data.displayName;
  }

  private fields(input: Record<string, unknown>, allowed: string[]) {
    if (input.schemaVersion !== 1 || Object.keys(input).some(key =>
      !['schemaVersion', 'organizationId', 'action', ...allowed].includes(key))) {
      throw new DomainError('invalid-argument', 'Invalid member setup request.');
    }
  }

  async execute(actor: Actor | undefined, input: Record<string, unknown>) {
    requireVerifiedEmail(actor);
    const org = requiredIdentifier(input.organizationId, 'organizationId');
    const admin = actor!;
    if (input.action === 'describe') return this.describe(admin, org, input);
    if (input.action === 'create') return this.create(admin, org, input);
    if (input.action === 'resend') {
      this.fields(input, ['memberId']);
      const uid = requiredIdentifier(input.memberId, 'memberId');
      return this.deliver(admin, org, uid, true);
    }
    throw new DomainError('invalid-argument', 'Unsupported member setup action.');
  }

  private async describe(actor: Actor, org: string, input: Record<string, unknown>) {
    this.fields(input, ['memberIds']);
    if (!Array.isArray(input.memberIds) || input.memberIds.length > 25) {
      throw new DomainError('invalid-argument', 'Select up to 25 members.');
    }
    const ids = [...new Set(input.memberIds.map(id => requiredIdentifier(id, 'memberId')))];
    const root = `orgs/${org}`;
    const scoped = await this.store.transact(async tx => {
      await authorizeAdminReport(tx, actor, org);
      const members = await readAll(tx, ids.map(uid => `${root}/members/${uid}`));
      return ids.filter((_, index) => members[index]?.role === 'member' &&
        members[index]?.organizationId === org);
    });
    const identities = scoped.length ? (await this.auth.getUsers(scoped.map(uid => ({uid})))).users : [];
    const identityMap = new Map(identities.map(identity => [identity.uid, identity]));
    return this.store.transact(async tx => {
      await authorizeAdminReport(tx, actor, org);
      const rows = await Promise.all(scoped.map(async uid => {
        const [user, member, receipt, account] = await readAll(tx, [
          `users/${uid}`, `${root}/members/${uid}`, setupPath(org, uid), `${root}/membershipAccounts/${uid}`,
        ]);
        if (user?.organizationId !== org || member?.organizationId !== org || member.role !== 'member') return;
        const identity = identityMap.get(uid);
        const recordedBranch = user.homeBranchId ?? user.primaryBranchId;
        const branch = typeof recordedBranch === 'string' && /^[a-zA-Z0-9_-]{1,128}$/.test(recordedBranch)
          ? await tx.get(`${root}/branches/${recordedBranch}`) : undefined;
        const active = member.status === 'active';
        const invitation = receipt?.stage === 'ready' || receipt?.stage === 'linked';
        const pendingSetup = invitation && !(identity?.emailVerified && identity.metadata.lastSignInTime);
        let tier: string | null = active && identity && !identity.disabled && !account ? 'free' : null;
        if (active && identity && !identity.disabled && identity.emailVerified) {
          const entitlement = await readVerifiedTargetMembershipEntitlement(tx, uid, org, this.clock(), {
            exists: true, disabled: identity.disabled, emailVerified: identity.emailVerified,
          }).catch(error => {
            if (!(error instanceof DomainError) || error.code !== 'permission-denied') throw error;
          });
          tier = entitlement?.effectiveTier ?? null;
        }
        return {memberId: uid, homeBranchId: branch ? recordedBranch : null,
          branchName: typeof branch?.displayName === 'string' ? branch.displayName : null,
          accountStatus: !active ? member.status : !identity ? 'unknown' : identity.disabled
            ? 'disabled' : pendingSetup ? 'pendingSetup' : 'active',
          membership: tier,
          canResend: active && receipt?.stage === 'ready' && !!identity && !identity.disabled && pendingSetup,
        };
      }));
      return {members: rows.filter(Boolean)};
    });
  }

  private async create(actor: Actor, org: string, input: Record<string, unknown>) {
    this.fields(input, ['requestId', 'displayName', 'email', 'phoneNumber', 'homeBranchId']);
    const request = requiredIdentifier(input.requestId, 'requestId');
    const home = requiredIdentifier(input.homeBranchId, 'homeBranchId');
    const normalized = validatedInput({
      userId: request, email: typeof input.email === 'string' ? input.email : '',
      displayName: typeof input.displayName === 'string' ? input.displayName : '',
    });
    const uid = 'member-' + keyOf(org, normalized.email);
    const record = {...normalized, userId: uid};
    if (input.phoneNumber !== undefined && typeof input.phoneNumber !== 'string') {
      throw new DomainError('invalid-argument', 'Enter a valid phone number.');
    }
    const phone = (input.phoneNumber as string | undefined)?.trim().replace(/[ ()-]/g, '') || '';
    if (phone && !/^\+?[0-9]{7,15}$/.test(phone)) {
      throw new DomainError('invalid-argument', 'Enter a valid phone number.');
    }
    const fingerprint = keyOf(record.email, record.displayName, home, phone);
    const receipt = setupPath(org, uid);
    const user = `users/${uid}`, member = `orgs/${org}/members/${uid}`;
    const reserved = await this.store.transact(async tx => {
      await authorizeAdminReport(tx, actor, org);
      const prior = await tx.get(receipt);
      if (prior && (prior.fingerprint !== fingerprint ||
          (prior.stage === 'ready' && (prior.requestId !== request || prior.actorId !== actor.uid)))) {
        throw new DomainError('already-exists', 'An account or pending setup already uses this email address.');
      }
      if (prior?.stage === 'ready' || prior?.stage === 'linked') return prior.stage;
      const branchName = await this.branch(tx, org, home);
      if (!prior) tx.create(receipt, {
        schemaVersion: 1, fingerprint, memberId: uid, actorId: actor.uid, requestId: request,
        stage: 'reserved', email: record.email, displayName: record.displayName,
        homeBranchId: home, branchName, createdAtMillis: this.clock(),
      });
      return 'reserved';
    });
    if (reserved === 'ready') return this.deliver(actor, org, uid, false);
    let identity = await this.identity(uid);
    if (!identity) {
      if (reserved !== 'reserved') throw fail();
      try {
        identity = await this.auth.createUser({
          uid, email: record.email, displayName: record.displayName,
          password: randomBytes(32).toString('base64url'), disabled: true, emailVerified: false,
        });
      } catch (error) {
        if (!['auth/email-already-exists','auth/uid-already-exists'].includes(String(authCode(error)))) throw error;
        identity = await this.identity(uid);
        if (!identity) throw new DomainError('already-exists', 'An account already uses this email address.');
      }
    }
    if (identity.email?.toLowerCase() !== record.email) throw fail();
    const createdIdentity = identity;
    await this.store.transact(async tx => {
      await authorizeAdminReport(tx, actor, org);
      const prior = await tx.get(receipt);
      if (prior?.fingerprint !== fingerprint) throw fail();
      if (prior.stage !== 'reserved') return;
      if (!createdIdentity.disabled || createdIdentity.emailVerified || await tx.get(user) ||
          await tx.get(member) || await tx.get(`datasetAssignments/${uid}`)) throw fail();
      const branchName = await this.branch(tx, org, home);
      const now = this.clock();
      const records = canonicalMemberRecords(record, org, home, now);
      tx.create(user, {...records.user, homeBranchId: home, ...(phone ? {phoneNumber: phone} : {})});
      tx.create(member, records.member);
      tx.set(receipt, {...prior, branchName, stage: 'linked', linkedAtMillis: now});
    });
    const enabling = await this.store.transact(async tx => {
      await authorizeAdminReport(tx, actor, org);
      const prior = await tx.get(receipt);
      if (prior?.stage === 'ready') return false;
      if (prior?.stage !== 'linked' || prior.fingerprint !== fingerprint) throw fail();
      if (createdIdentity.disabled && Number(prior.enableAfterMillis ?? 0) > this.clock()) {
        throw new DomainError('aborted', 'Member setup is still processing. Retry this request shortly.');
      }
      tx.set(receipt, {...prior, enableAfterMillis: this.clock() + minute});
      return true;
    });
    if (enabling) {
      const current = await this.identity(uid);
      if (!current || current.email?.toLowerCase() !== record.email) throw fail();
      if (current.disabled) await this.auth.updateUser(uid, {disabled: false});
      await this.store.transact(async tx => {
        const prior = await tx.get(receipt);
        if (prior?.stage === 'linked') tx.set(receipt, {...prior, stage: 'ready', readyAtMillis: this.clock()});
      });
    }
    return this.deliver(actor, org, uid, false);
  }

  private async deliver(actor: Actor, org: string, uid: string, resend: boolean) {
    const receipt = setupPath(org, uid);
    // Authorize before reading any Firebase Auth identity.
    await this.store.transact(tx => authorizeAdminReport(tx, actor, org));
    const identity = await this.identity(uid);
    const work = await this.store.transact(async tx => {
      await authorizeAdminReport(tx, actor, org);
      const prior = await tx.get(receipt);
      const m = await tx.get(`orgs/${org}/members/${uid}`);
      const u = await tx.get(`users/${uid}`);
      if (!prior || prior.stage !== 'ready' || prior.memberId !== uid || !identity ||
          identity.email?.toLowerCase() !== prior.email ||
          u?.organizationId !== org || m?.organizationId !== org || m.role !== 'member' ||
          typeof prior.email !== 'string' || typeof prior.displayName !== 'string') throw fail();
      const complete = identity.emailVerified && Boolean(identity.metadata.lastSignInTime);
      const info = {memberId: uid, displayName: prior.displayName, email: prior.email,
        homeBranchId: prior.homeBranchId, branchName: prior.branchName,
        accountStatus: identity.disabled ? 'disabled' : complete ? 'complete' : 'pending',
        delivery: typeof prior.delivery === 'string' ? prior.delivery : 'pending'};
      const now = this.clock();
      const last = Number(prior.lastAttemptAt ?? 0);
      if (complete || identity.disabled || m.status !== 'active' || u.accountLifecycle !== undefined
          || (!resend && last > 0)) return {info};
      const attempts = (Array.isArray(prior.attempts) ? prior.attempts : []).filter(
        (at): at is number => typeof at === 'number' && at > now - hour);
      if ((last > 0 && last > now - minute) || attempts.length >= 3) return {info: {...info, delivery: 'rate_limited'}};
      const quotaPath = 'memberSetupQuota/delivery';
      const quota = (await tx.get(quotaPath))?.buckets as Record<string, number> | undefined;
      const bucket = Math.floor(now / hour);
      const recent = Object.fromEntries(Object.entries(quota ?? {}).filter(([key]) => Number(key) >= bucket - 24));
      if (Object.values(recent).reduce((sum, n) => sum + n, 0) >= 40) {
        return {info: {...info, delivery: 'rate_limited'}};
      }
      recent[bucket] = (recent[bucket] ?? 0) + 1;
      tx.set(quotaPath, {buckets: recent});
      tx.set(receipt, {...prior, lastAttemptAt: now, attempts: [...attempts, now], delivery: 'pending'});
      return {info, attempt: now};
    });
    if (work.attempt === undefined) return work.info;
    let delivery = 'sent';
    try {
      const email = work.info.email;
      const setup = await this.auth.generatePasswordResetLink(email);
      const verify = identity!.emailVerified ? undefined : await this.auth.generateEmailVerificationLink(email);
      const current = await this.identity(uid);
      if (!current || current.disabled || current.email?.toLowerCase() !== email) throw fail();
      await this.email.send(memberSetupEmail(email, work.info.displayName, setup, verify, this.logo));
    } catch {
      this.report('setup_delivery');
      delivery = 'failed';
    }
    await this.store.transact(async tx => {
      const prior = await tx.get(receipt);
      if (prior?.lastAttemptAt === work.attempt) tx.set(receipt, {...prior, delivery});
    });
    return {...work.info, delivery};
  }
}
