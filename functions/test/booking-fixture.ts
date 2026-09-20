export const now = Date.parse('2026-10-01T00:00:00Z');
export const start = Date.parse('2026-10-02T02:00:00Z');
export const command = { schemaVersion: 1 as const, requestId: 'request-1', organizationId: 'org-1',
  branchId: 'branch-1', coachId: 'coach-1', memberId: 'member-1', startAtMillis: start, durationMinutes: 60 as const };
export const seeds = {
  'orgs/org-1/members/member-1': { role: 'member', status: 'active', branchIds: ['branch-1', 'branch-2'] },
  'orgs/org-1/members/coach-1': { role: 'coach', status: 'active', branchIds: ['branch-1'] },
  'orgs/org-1/members/staff-1': { role: 'staff', status: 'active', branchIds: ['branch-2'] },
  'orgs/org-1/coaches/coach-1': { status: 'published', branchIds: ['branch-1'] },
  'orgs/org-1/branches/branch-1': { status: 'active' },
  'orgs/org-1/settings/booking': { schemaVersion: 1, policyVersion: 'booking-v1', timeZone: 'Asia/Kuala_Lumpur',
    maxActiveBookingsPerMemberPerDay: 1, holdMinutes: 15 },
  'orgs/org-1/coachAvailability/coach-1/days/2026-10-02': { schemaVersion: 1,
    windows: [{ branchId: 'branch-1', startAtMillis: start, endAtMillis: start + 4 * 3600000 }] },
};
