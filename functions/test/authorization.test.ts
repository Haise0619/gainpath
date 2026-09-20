import { expect, it } from 'vitest';
import { requireBranchAccess } from '../src/platform/auth-context';

it('does not let staff bypass branch assignments', () => {
  expect(() => requireBranchAccess({ role: 'staff', status: 'active', branchIds: ['a'] }, 'b')).toThrow();
});
it('allows assigned staff and organization admins', () => {
  expect(() => requireBranchAccess({ role: 'staff', status: 'active', branchIds: ['a'] }, 'a')).not.toThrow();
  expect(() => requireBranchAccess({ role: 'admin', status: 'active', branchIds: [] }, 'a')).not.toThrow();
});
