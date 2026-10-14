import { expect, it } from 'vitest';
import { coachCommandError } from '../src/modules/coaching/coach-profile-callables';
import { DomainError } from '../src/platform/errors';
import { InputValidationError } from '../src/platform/validation';
it('maps known safe failures and never exposes unexpected private request details', () => {
  expect(coachCommandError(new DomainError('aborted', 'Reload the profile.')).code).toBe('aborted');
  expect(coachCommandError(new InputValidationError('Unsupported field.')).code).toBe('invalid-argument');
  const mapped = coachCommandError(Error('PRIVATE_PROFILE_BODY'));
  expect(mapped.code).toBe('internal');
  expect(mapped.message).not.toContain('PRIVATE_PROFILE_BODY');
});
