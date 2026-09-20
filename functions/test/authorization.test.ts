import { expect, it } from 'vitest';
import { requireBranchAccess, requireVerifiedEmail } from '../src/platform/auth-context';

it('does not let staff bypass branch assignments', () => {
  expect(() => requireBranchAccess({ role: 'staff', status: 'active', branchIds: ['a'] }, 'b')).toThrow();
});
it('allows assigned staff and organization admins', () => {
  expect(() => requireBranchAccess({ role: 'staff', status: 'active', branchIds: ['a'] }, 'a')).not.toThrow();
  expect(() => requireBranchAccess({ role: 'admin', status: 'active', branchIds: [] }, 'a')).not.toThrow();
});
it('requires a verified email claim for protected operations', () => {
  expect(() => requireVerifiedEmail(undefined)).toThrow();
  expect(() => requireVerifiedEmail({ token: { email_verified: false } })).toThrow();
  expect(() => requireVerifiedEmail({ token: { email_verified: true } })).not.toThrow();
});
