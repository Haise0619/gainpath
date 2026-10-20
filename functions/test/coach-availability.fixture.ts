export const org = 'b2-org', root = `orgs/${org}`, now = Date.parse('2026-10-14T16:10:00Z');
export const date = '2026-10-16', start = Date.parse('2026-10-16T02:00:00Z');
export const auth = (uid: string, verified = true) => ({ uid, token: { email_verified: verified } });
export const windows = [{ branchId: 'main', startAtMillis: start, endAtMillis: start + 3600000 }];
export function seeds() {
  return {
    [root]: { status: 'active' }, [`${root}/branches/main`]: { status: 'active' }, [`${root}/branches/other`]: { status: 'active' },
    [`${root}/settings/booking`]: { schemaVersion: 1, policyVersion: 'booking-v1', timeZone: 'Asia/Kuala_Lumpur', maxActiveBookingsPerMemberPerDay: 2, holdMinutes: 15 },
    [`${root}/coaches/coach`]: { status: 'published', branchIds: ['main', 'other'] },
    ...Object.fromEntries(['coach', 'second-coach', 'member', 'admin', 'staff'].flatMap(uid => [
      [`users/${uid}`, { organizationId: org }],
      [`${root}/members/${uid}`, { organizationId: org, status: 'active', role: uid.includes('coach') ? 'coach' : uid, branchIds: uid === 'member' ? ['main'] : ['main', 'other'] }],
    ])),
  };
}
export const read = (coachId = 'coach') => ({ schemaVersion: 1, organizationId: org, coachId, dayCount: 7 });
export const save = (requestId = 'save', expectedRevision = 0, next = windows) => ({ schemaVersion: 1, organizationId: org, requestId, localDate: date, expectedRevision, expectedPolicyVersion: 'booking-v1', expectedTimeZone: 'Asia/Kuala_Lumpur', expectedCoachBranchIds: ['main', 'other'], windows: next });
