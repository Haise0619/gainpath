const {test} = require('node:test');
const assert = require('node:assert/strict');
const {buildCoachReadScopeProposal} = require('./coach-read-scope.cjs');
function fixture() {
  const snapshot = data => ({data, updateTime: '2026-10-24T00:00:00.000000Z'});
  return {organizationId: 'o', userId: 'coach', snapshots: {
    user: snapshot({organizationId: 'o'}),
    membership: snapshot({organizationId: 'o', role: 'coach', status: 'active', branchIds: ['main']}),
    organization: snapshot({status: 'active'}),
  }};
}
test('prepares a create-only scope with all three source revision preconditions', () => {
  const proposal = buildCoachReadScopeProposal(fixture());
  assert.equal(proposal.mode, 'PROPOSAL_ONLY_NO_WRITES');
  assert.deepEqual(proposal.record, {path: 'orgs/o/coachReadScopes/coach', exists: false, data: {
    schemaVersion: 1, organizationId: 'o', userId: 'coach', role: 'coach', validatedBranchIds: ['main'],
  }});
  assert.deepEqual(proposal.sourcePreconditions.map(p => p.path), ['users/coach', 'orgs/o/members/coach', 'orgs/o']);
});
test('rejects non-string branches, invalid roles, inactive/cross-org sources and absent revisions', () => {
  for (const mutate of [
    x => x.snapshots.membership.data.branchIds = [123],
    x => x.snapshots.membership.data.branchIds = undefined,
    x => x.snapshots.membership.data.role = 'member',
    x => x.snapshots.membership.data.status = 'inactive',
    x => x.snapshots.membership.data.organizationId = 'foreign',
    x => x.snapshots.user.data.organizationId = 'foreign',
    x => x.snapshots.organization.data.status = 'inactive',
    x => delete x.snapshots.user.updateTime,
    x => x.userId = '../coach',
    x => x.scopeExists = true,
  ]) { const input = fixture(); mutate(input); assert.throws(() => buildCoachReadScopeProposal(input)); }
});
test('does not mutate input and excludes unrelated user and organization fields', () => {
  const input = fixture(); input.snapshots.user.data.private = 'not copied';
  const before = JSON.stringify(input), output = buildCoachReadScopeProposal(input);
  assert.equal(JSON.stringify(input), before);
  assert.equal(JSON.stringify(output).includes('not copied'), false);
  input.snapshots.membership.data.branchIds.push('new');
  assert.deepEqual(output.record.data.validatedBranchIds, ['main']);
});
