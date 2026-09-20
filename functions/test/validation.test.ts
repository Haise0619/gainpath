import { describe, expect, it } from 'vitest';
import { parseCreateBookingHold } from '../src/platform/validation';

describe('create booking hold validation', () => {
  it('accepts a supported duration and preserves the request id', () => {
    const result = parseCreateBookingHold({
      schemaVersion: 1,
      memberId: 'member-1',
      requestId: 'request-123',
      organizationId: 'org-1',
      branchId: 'branch-1',
      coachId: 'coach-1',
      startAtMillis: Date.now() + 3600000,
      durationMinutes: 60,
    });

    expect(result.durationMinutes).toBe(60);
    expect(result.requestId).toBe('request-123');
  });

  it('rejects unsupported duration and malformed identifiers', () => {
    expect(() =>
      parseCreateBookingHold({
        requestId: '',
        organizationId: 'org-1',
        branchId: 'branch-1',
        coachId: 'coach-1',
        startAtMillis: Date.now(),
        durationMinutes: 45,
      }),
    ).toThrow();
  });

  it.each(['a/b', '..', ' x ', '', 'x\\y'])('rejects unsafe path identifier %s', (requestId) => {
    expect(() => parseCreateBookingHold({ schemaVersion: 1, memberId: 'member-1', requestId, organizationId: 'org-1',
      branchId: 'branch-1', coachId: 'coach-1', startAtMillis: 1800000000000, durationMinutes: 30 })).toThrow();
  });

  it('rejects unversioned commands', () => {
    expect(() => parseCreateBookingHold({ requestId: 'r', organizationId: 'o', branchId: 'b',
      coachId: 'c', startAtMillis: 1800000000000, durationMinutes: 30 })).toThrow();
  });
});
