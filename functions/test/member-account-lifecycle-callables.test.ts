import { expect, it } from 'vitest';
import { lifecycleCommandError, requireCurrentLifecycleIdentity } from '../src/modules/identity/member-account-lifecycle-callables';
import { DomainError } from '../src/platform/errors';

const auth = { uid: 'member', token: { email_verified: true, email: 'member@example.test', auth_time: 1800000000 } };
const identity = { uid: 'member', disabled: false, emailVerified: true, email: 'member@example.test', tokensValidAfterTime: new Date(1800000000 * 1000).toUTCString() };
it('checks current Auth identity without allowing disabled, changed, unverified or revoked sessions', async () => {
  await expect(requireCurrentLifecycleIdentity(auth, async () => identity)).resolves.toBe(auth);
  for (const patch of [{ uid: 'foreign' }, { disabled: true }, { emailVerified: false }, { email: 'changed@example.test' }, { tokensValidAfterTime: new Date(1800000001 * 1000).toUTCString() }]) {
    await expect(requireCurrentLifecycleIdentity(auth, async () => ({ ...identity, ...patch }))).rejects.toMatchObject({ code: 'unauthenticated' });
  }
  await expect(requireCurrentLifecycleIdentity(undefined, async () => identity)).rejects.toMatchObject({ code: 'unauthenticated' });
  await expect(requireCurrentLifecycleIdentity(auth, async () => { throw { code: 'auth/user-not-found' }; })).rejects.toMatchObject({ code: 'unauthenticated' });
  await expect(requireCurrentLifecycleIdentity(auth, async () => { throw new Error('network'); })).rejects.toMatchObject({ code: 'unavailable' });
});
it('maps safe lifecycle failures without exposing unexpected private provider messages', () => {
  expect(lifecycleCommandError(new DomainError('unavailable', 'Retry shortly.')).code).toBe('unavailable');
  const mapped = lifecycleCommandError(new Error('PRIVATE_IDENTITY_BODY'));
  expect(mapped.code).toBe('internal'); expect(mapped.message).not.toContain('PRIVATE_IDENTITY_BODY');
});
