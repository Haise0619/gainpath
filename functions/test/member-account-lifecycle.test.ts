import { describe, expect, it } from 'vitest';
import { MemoryStore } from './memory-store';
import type { DocumentStore } from '../src/platform/firestore/store';
import { cancelMemberDeactivation, readMemberAccountLifecycle, requestMemberDeactivation } from '../src/modules/identity/member-account-lifecycle';

const NOW = 1_800_000_000_123;
const DAY = 86_400_000;
function fixture(approved = true) {
  const store = new MemoryStore();
  store.documents.set('orgs/org', { status: 'active' });
  store.documents.set('users/member', { organizationId: 'org', createdAtMillis: 1, displayName: 'Keep', contactDetails: 'Private', memberPhotoPath: 'keep' });
  store.documents.set('orgs/org/members/member', { organizationId: 'org', userId: 'member', role: 'member', status: 'active', createdAtMillis: 2, goals: ['keep'] });
  let now = NOW;
  let revocations = 0;
  let failRevoke = false;
  const dependencies = { clock: () => now, grace30DaysApproved: approved, revokeRefreshTokens: async () => { revocations++; if (failRevoke) throw new Error('offline'); } };
  const auth = () => ({ uid: 'member', token: { email_verified: true, auth_time: Math.floor(now / 1000) } });
  return { store, dependencies, auth, setNow: (value: number) => { now = value; }, revocations: () => revocations, failRevoke: (value: boolean) => { failRevoke = value; } };
}
const command = (requestId = 'request_0001', expectedRevision = 0) => ({ schemaVersion: 1, requestId, expectedRevision });

describe('trusted Member account lifecycle', () => {
  it('blocks membership immediately, retains all records and retries a request without a second transition', async () => {
    const f = fixture();
    const result = await requestMemberDeactivation(f.store, f.auth(), command(), f.dependencies);
    expect(result).toMatchObject({ state: 'pendingDeletion', revision: 1, requestedAtMillis: NOW, retentionEndsAtMillis: NOW + 30 * DAY, sessionRevocationPending: false });
    expect(f.store.documents.get('users/member')).toMatchObject({ createdAtMillis: 1, displayName: 'Keep', contactDetails: 'Private', memberPhotoPath: 'keep' });
    expect(f.store.documents.get('orgs/org/members/member')).toMatchObject({ status: 'pendingDeletion', createdAtMillis: 2, goals: ['keep'] });
    const retry = await requestMemberDeactivation(f.store, f.auth(), command(), f.dependencies);
    expect(retry.revision).toBe(1);
    expect(f.revocations()).toBe(1);
    expect(f.store.documents.size).toBe(4);
  });
  it('requires fresh post-deactivation authentication to restore within the approved window', async () => {
    const f = fixture(); const oldAuth = f.auth();
    await requestMemberDeactivation(f.store, oldAuth, command(), f.dependencies);
    f.setNow(NOW + 65 * 60_000);
    await expect(cancelMemberDeactivation(f.store, oldAuth, command('restore_0001', 1), f.dependencies)).rejects.toMatchObject({ code: 'unauthenticated' });
    const restored = await cancelMemberDeactivation(f.store, f.auth(), command('restore_0001', 1), f.dependencies);
    expect(restored).toMatchObject({ state: 'active', revision: 2, sessionNotBeforeSeconds: Math.floor(NOW / 1000) + 1 });
    await expect(requestMemberDeactivation(f.store, oldAuth, command('request_old1', 2), f.dependencies)).rejects.toMatchObject({ code: 'unauthenticated' });
    expect(f.store.documents.get('orgs/org/members/member')?.status).toBe('active');
    expect(f.revocations()).toBe(1);
    const replay = await requestMemberDeactivation(f.store, f.auth(), command(), f.dependencies);
    expect(replay.state).toBe('active'); expect(replay.revision).toBe(2); expect(f.revocations()).toBe(1);
  });
  it('recovers a committed request after revocation failure without resetting its deadline', async () => {
    const f = fixture(); f.failRevoke(true);
    await expect(requestMemberDeactivation(f.store, f.auth(), command(), f.dependencies)).rejects.toMatchObject({ code: 'unavailable' });
    expect(f.store.documents.get('orgs/org/members/member')?.status).toBe('pendingDeletion');
    f.setNow(NOW + 2000);
    await expect(cancelMemberDeactivation(f.store, f.auth(), command('restore_0001', 1), f.dependencies)).rejects.toMatchObject({ code: 'failed-precondition' });
    const pending = await readMemberAccountLifecycle(f.store, f.auth(), { schemaVersion: 1 }, f.dependencies);
    expect(pending).toMatchObject({ state: 'pendingDeletion', sessionRevocationPending: true, lastRequestId: 'request_0001' });
    f.failRevoke(false); f.setNow(NOW + 90_000);
    const result = await readMemberAccountLifecycle(f.store, f.auth(), { schemaVersion: 1 }, f.dependencies);
    expect(result).toMatchObject({ requestedAtMillis: NOW, retentionEndsAtMillis: NOW + 30 * DAY, revision: 1, sessionRevocationPending: false });
  });
  it('defaults to unapproved retention without a purge date or reactivation promise', async () => {
    const f = fixture(false);
    const result = await requestMemberDeactivation(f.store, f.auth(), command(), f.dependencies);
    expect(result).toMatchObject({ policy: 'pendingApproval', retentionEndsAtMillis: null, reactivationAllowed: false });
    f.setNow(NOW + 2000);
    await expect(cancelMemberDeactivation(f.store, f.auth(), command('restore_0001', 1), f.dependencies)).rejects.toMatchObject({ code: 'failed-precondition' });
  });
  it('never restores expired or policy-disabled requests and never purges records', async () => {
    const f = fixture(); await requestMemberDeactivation(f.store, f.auth(), command(), f.dependencies);
    f.setNow(NOW + 90_000); f.dependencies.grace30DaysApproved = false;
    await expect(cancelMemberDeactivation(f.store, f.auth(), command('restore_0001', 1), f.dependencies)).rejects.toMatchObject({ code: 'failed-precondition' });
    f.dependencies.grace30DaysApproved = true;
    f.setNow(NOW + 30 * DAY);
    await expect(cancelMemberDeactivation(f.store, f.auth(), command('restore_0001', 1), f.dependencies)).rejects.toMatchObject({ code: 'failed-precondition' });
    expect(f.store.documents.size).toBe(4);
    expect(f.store.documents.get('orgs/org/members/member')?.status).toBe('pendingDeletion');
  });
  it('rejects stale revisions and conflicting receipt reuse without mutation', async () => {
    const f = fixture();
    await expect(requestMemberDeactivation(f.store, f.auth(), command('request_0001', 8), f.dependencies)).rejects.toMatchObject({ code: 'aborted' });
    await requestMemberDeactivation(f.store, f.auth(), command(), f.dependencies);
    await expect(requestMemberDeactivation(f.store, f.auth(), command('request_0001', 1), f.dependencies)).rejects.toMatchObject({ code: 'already-exists' });
    expect(f.store.documents.size).toBe(4);
  });
  it('rejects unverified, old, absent or future authentication and client authority fields', async () => {
    const f = fixture();
    for (const auth of [undefined, { uid: 'member', token: { email_verified: false, auth_time: NOW / 1000 } }, { uid: 'member', token: { email_verified: true, auth_time: Math.floor(NOW / 1000) - 301 } }, { uid: 'member', token: { email_verified: true, auth_time: Math.floor(NOW / 1000) + 1 } }]) {
      await expect(requestMemberDeactivation(f.store, auth, command(), f.dependencies)).rejects.toBeDefined();
    }
    for (const extra of [{ role: 'admin' }, { organizationId: 'other' }, { userId: 'other' }, { retentionEndsAtMillis: NOW }, { status: 'active' }]) {
      await expect(requestMemberDeactivation(f.store, f.auth(), { ...command(), ...extra }, f.dependencies)).rejects.toMatchObject({ code: 'invalid-argument' });
    }
    expect(f.store.documents.size).toBe(3); expect(f.revocations()).toBe(0);
  });
  it('fails closed for malformed lifecycle, role/status/org drift and missing canonical records', async () => {
    for (const patch of [{ role: 'admin' }, { status: 'suspended' }, { organizationId: 'foreign' }, { userId: 'foreign' }]) {
      const f = fixture(); Object.assign(f.store.documents.get('orgs/org/members/member')!, patch);
      await expect(requestMemberDeactivation(f.store, f.auth(), command(), f.dependencies)).rejects.toMatchObject({ code: 'permission-denied' });
    }
    for (const value of [null, {}, { schemaVersion: 1, state: 'active', revision: 0 }]) {
      const f = fixture(); f.store.documents.get('users/member')!.accountLifecycle = value;
      await expect(readMemberAccountLifecycle(f.store, f.auth(), { schemaVersion: 1 }, f.dependencies)).rejects.toMatchObject({ code: 'failed-precondition' });
    }
    const f = fixture(); f.store.documents.delete('users/member');
    await expect(readMemberAccountLifecycle(f.store, f.auth(), { schemaVersion: 1 }, f.dependencies)).rejects.toMatchObject({ code: 'permission-denied' });
    const org = fixture(); org.store.documents.get('orgs/org')!.status = 'suspended';
    await expect(requestMemberDeactivation(org.store, org.auth(), command(), org.dependencies)).rejects.toMatchObject({ code: 'permission-denied' });
    const other = fixture();
    await expect(requestMemberDeactivation(other.store, { ...other.auth(), uid: 'other' }, command(), other.dependencies)).rejects.toMatchObject({ code: 'permission-denied' });
  });
  it('serializes concurrent request IDs so only one transition wins', async () => {
    const f = fixture();
    const results = await Promise.allSettled(['request_0001', 'request_0002'].map(id => requestMemberDeactivation(f.store, f.auth(), command(id), f.dependencies)));
    expect(results.filter(result => result.status === 'fulfilled')).toHaveLength(1);
    expect(f.store.documents.get('users/member')?.accountLifecycle).toMatchObject({ revision: 1 });
    expect(f.store.documents.size).toBe(4);
  });
  it('fences concurrent cleanup retries and disallows restoration until revocation and its lease settle', async () => {
    const f = fixture();
    let finish!: () => void;
    let started!: () => void;
    const inFlight = new Promise<void>(resolve => { started = resolve; });
    f.dependencies.revokeRefreshTokens = async () => { started(); await new Promise<void>(resolve => { finish = resolve; }); };
    const request = requestMemberDeactivation(f.store, f.auth(), command(), f.dependencies);
    await inFlight;
    const snapshot = await readMemberAccountLifecycle(f.store, f.auth(), { schemaVersion: 1 }, f.dependencies);
    expect(snapshot.sessionRevocationPending).toBe(true);
    f.setNow(NOW + 2000);
    await expect(cancelMemberDeactivation(f.store, f.auth(), command('restore_0001', 1), f.dependencies)).rejects.toMatchObject({ code: 'failed-precondition' });
    finish(); await request;
    const settled = await readMemberAccountLifecycle(f.store, f.auth(), { schemaVersion: 1 }, f.dependencies);
    expect(settled).toMatchObject({ sessionRevocationPending: false, reactivationAllowed: false, reactivationAvailableAtMillis: NOW + 2000 + 65 * 60_000 });
    f.setNow(NOW + 2000 + 65 * 60_000);
    expect((await cancelMemberDeactivation(f.store, f.auth(), command('restore_0001', 1), f.dependencies)).state).toBe('active');
  });
  it('resumes after Auth succeeds but acknowledgement is interrupted, preserving the one request receipt', async () => {
    const f = fixture(); let calls = 0;
    const interrupted: DocumentStore = { transact: work => {
      calls++; if (calls === 3) return Promise.reject(new Error('acknowledgement interrupted'));
      return f.store.transact(work);
    } };
    await expect(requestMemberDeactivation(interrupted, f.auth(), command(), f.dependencies)).rejects.toThrow('acknowledgement interrupted');
    expect(f.revocations()).toBe(1);
    expect(f.store.documents.get('orgs/org/members/member')?.status).toBe('pendingDeletion');
    f.setNow(NOW + 90_000);
    const recovered = await readMemberAccountLifecycle(f.store, f.auth(), { schemaVersion: 1 }, f.dependencies);
    expect(recovered).toMatchObject({ revision: 1, requestedAtMillis: NOW, sessionRevocationPending: false });
    expect(f.store.documents.size).toBe(4); expect(f.revocations()).toBe(2);
  });
  it('rejects inconsistent pending/active state and malformed lifecycle fields', async () => {
    for (const patch of [{ revision: Number.MAX_SAFE_INTEGER + 1 }, { policy: 'unknown' }, { retentionEndsAtMillis: NOW + DAY }, { sessionNotBeforeSeconds: 0 }, { state: 'active' }, { revocationPending: 'yes' }, { revocationLeaseUntilMillis: -1 }, { revocationAttemptId: '../foreign' }]) {
      const f = fixture(); await requestMemberDeactivation(f.store, f.auth(), command(), f.dependencies);
      Object.assign(f.store.documents.get('users/member')!.accountLifecycle as object, patch);
      await expect(readMemberAccountLifecycle(f.store, f.auth(), { schemaVersion: 1 }, f.dependencies)).rejects.toMatchObject({ code: 'failed-precondition' });
    }
  });
  it('starts the security wait when delayed session revocation completes, not when requested', async () => {
    const f = fixture(); f.failRevoke(true);
    await expect(requestMemberDeactivation(f.store, f.auth(), command(), f.dependencies)).rejects.toMatchObject({ code: 'unavailable' });
    f.setNow(NOW + 2 * 60 * 60_000); f.failRevoke(false);
    const recovered = await readMemberAccountLifecycle(f.store, f.auth(), { schemaVersion: 1 }, f.dependencies);
    expect(recovered).toMatchObject({ reactivationAllowed: false, reactivationAvailableAtMillis: NOW + (120 + 65) * 60_000 });
    await expect(cancelMemberDeactivation(f.store, f.auth(), command('restore_0001', 1), f.dependencies)).rejects.toMatchObject({ code: 'failed-precondition' });
    f.setNow(NOW + (120 + 65) * 60_000);
    expect((await cancelMemberDeactivation(f.store, f.auth(), command('restore_0001', 1), f.dependencies)).state).toBe('active');
  });
});
