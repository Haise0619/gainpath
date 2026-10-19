import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertFails, type RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';
import { beforeAll, afterAll, it } from 'vitest';
import { seeds } from '../test/booking-fixture';

let env: RulesTestEnvironment;
beforeAll(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw Error('Emulator required.');
  const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(':');
  env = await initializeTestEnvironment({ projectId: 'demo-gainpath', firestore: {
    host, port: Number(port), rules: readFileSync(process.env.MODULE9_RULES_PATH ?? '../firebase/firestore.rules', 'utf8'),
  } });
});
afterAll(async () => env?.cleanup());
it('clients cannot bypass the callable to read or overwrite messages or sequence state', async () => {
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    for (const [path, data] of Object.entries(seeds)) await setDoc(doc(db, path), data);
    await setDoc(doc(db, 'users/admin-1'), { organizationId: 'org-1' });
    await setDoc(doc(db, 'orgs/org-1/members/admin-1'), { organizationId: 'org-1', status: 'active', role: 'admin', branchIds: [] });
    await setDoc(doc(db, 'orgs/org-1/bookings/booking-1'), { memberId: 'member-1', coachId: 'coach-1', branchId: 'branch-1', status: 'pending_hold' });
    await setDoc(doc(db, 'orgs/org-1/bookings/booking-1/messages/1'), { sequence: 1, senderRole: 'member', text: 'Private fixture question', sentAtMillis: 1 });
    await setDoc(doc(db, 'orgs/org-1/bookings/booking-1/communicationState/current'), { schemaVersion: 1, count: 1 });
  });
  for (const uid of ['member-1', 'coach-1', 'admin-1']) {
    const db = env.authenticatedContext(uid, { email_verified: true }).firestore();
    for (const suffix of ['messages/1', 'communicationState/current']) {
      const ref = doc(db, `orgs/org-1/bookings/booking-1/${suffix}`);
      await assertFails(getDoc(ref));
      await assertFails(setDoc(ref, { schemaVersion: 1, text: 'Forged', sequence: 1 }));
    }
  }
});
