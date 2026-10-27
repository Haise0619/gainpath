import {readFileSync} from 'node:fs';
import {initializeTestEnvironment, assertFails} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc} from 'firebase/firestore';
import {expect, it} from 'vitest';

it('existing Rules keep mini-game policy, trusted evidence and shared counters server-only', async () => {
  if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:18088') throw Error('Isolated local emulator required');
  const env = await initializeTestEnvironment({projectId: 'demo-gainpath-mini-game-rewards',
    firestore: {host: '127.0.0.1', port: 18088, rules: readFileSync('../firebase/firestore.rules', 'utf8')}});
  const collections = ['miniGameRewardPolicies', 'miniGameRewardReleases', 'miniGameVerifiedRounds',
    'miniGameRewardDailyClaims', 'miniGameRewardAttemptClaims', 'miniGameRewardPolicyRequests'];
  try {
    await env.withSecurityRulesDisabled(async context => {
      for (const collection of collections) await setDoc(doc(context.firestore(), `orgs/gainpath/${collection}/forged`),
        {schemaVersion: 1, organizationId: 'gainpath', memberId: 'member', points: 20, enabled: true});
    });
    let rejected = 0;
    for (const uid of ['member', 'admin']) {
      const client = env.authenticatedContext(uid, {email_verified: true, role: uid === 'admin' ? 'Admin' : 'Member'}).firestore();
      for (const collection of collections) {
        const ref = doc(client, `orgs/gainpath/${collection}/forged`);
        await assertFails(getDoc(ref));
        await assertFails(setDoc(ref, {schemaVersion: 1, organizationId: 'gainpath', memberId: uid, points: 999, enabled: true}));
        rejected += 2;
      }
    }
    expect(rejected).toBe(24);
  } finally { await env.cleanup(); }
});
