const assert = require('node:assert/strict');

// Pure proposal builder: deliberately has no Firebase dependency or write API.
// The eventual approved apply must re-read all sources in one transaction and
// match these revisions before creating the scope. Never overwrite an attestation.
function buildCoachReadScopeProposal(input) {
  const {organizationId: org, userId: uid, snapshots} = input;
  const id = /^[A-Za-z0-9_-]{1,128}$/;
  assert(typeof org === 'string' && id.test(org), 'Invalid organization ID');
  assert(typeof uid === 'string' && id.test(uid), 'Invalid user ID');
  assert(input.scopeExists !== true, 'Existing scope requires a separate reviewed refresh');
  const sources = ['user', 'membership', 'organization'];
  for (const name of sources) {
    assert(snapshots?.[name]?.data && typeof snapshots[name].data === 'object', `Missing ${name}`);
    assert(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,9})?Z$/.test(snapshots[name].updateTime ?? ''), `Missing source revision: ${name}`);
  }
  const {user, membership, organization} = snapshots;
  const member = membership.data;
  assert(user.data.organizationId === org && member.organizationId === org, 'Cross-organization sources');
  assert(organization.data.status === 'active' && member.status === 'active', 'Inactive authority');
  assert(['coach', 'admin'].includes(member.role), 'Unsupported role');
  assert(Array.isArray(member.branchIds) && member.branchIds.every(id => typeof id === 'string'), 'Unvalidated branches');
  return {
    schemaVersion: 1, mode: 'PROPOSAL_ONLY_NO_WRITES',
    sourcePreconditions: sources.map((key, i) => ({
      path: [`users/${uid}`, `orgs/${org}/members/${uid}`, `orgs/${org}`][i], updateTime: snapshots[key].updateTime,
    })),
    record: {path: `orgs/${org}/coachReadScopes/${uid}`, exists: false, data: {
      schemaVersion: 1, organizationId: org, userId: uid,
      role: member.role, validatedBranchIds: [...member.branchIds],
    }},
  };
}
module.exports = {buildCoachReadScopeProposal};
