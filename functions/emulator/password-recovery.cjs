const assert = require('node:assert/strict');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');
const { PasswordRecovery } = require('../lib/modules/identity/password-recovery');

async function main() {
  const projectId = 'demo-gainpath';
  assert.ok(process.env.FIREBASE_AUTH_EMULATOR_HOST);
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
  initializeApp({ projectId });
  const db = getFirestore();
  const auth = getAuth();
  let now = Date.now();
  const messages = [];
  const flow = new PasswordRecovery(
    db, auth, { async send(message) { messages.push(message); } },
    'emulator-only-reset-key-32-characters', '', stage => assert.fail(stage), () => now,
  );
  const email = 'recovery@example.test';
  const other = 'other@example.test';
  const original = 'BeforeReset12';
  const password = 'NewPassword12';
  const user = await auth.createUser({ email, password: original, emailVerified: true });
  const otherUser = await auth.createUser({ email: other, password: original });
  for (const account of [user, otherUser]) {
    await db.doc('users/' + account.uid).set({ organizationId: 'gym', points: 30 });
    await db.doc('orgs/gym/members/' + account.uid)
      .set({ role: 'member', organizationId: 'gym', status: 'active' });
  }
  const send = (address = email) => flow.execute({ operation: 'requestPasswordResetOtp', email: address });
  const verify = (challengeId, code) => flow.execute({ operation: 'verifyPasswordResetOtp', email, challengeId, code });
  const complete = (challengeId, resetToken, address = email) => flow.execute({
    operation: 'completePasswordReset', email: address, challengeId, resetToken, password,
    uid: otherUser.uid,
  });
  const otp = () => messages.at(-1).textContent.match(/^\d{6}$/m)?.[0];
  const rejected = promise => assert.rejects(promise, { code: 'failed-precondition' });
  const incorrect = () => otp() === '000000' ? '000001' : '000000';

  const unknown = await send('missing@example.test');
  assert.equal(messages.length, 0);
  const first = await send();
  assert.deepEqual(Object.keys(first), Object.keys(unknown));
  assert.match(otp(), /^\d{6}$/);
  assert.match(messages[0].htmlContent, new RegExp(otp()));
  assert.equal(messages[0].subject, 'Your GainPath password reset code');
  await send();
  assert.equal(messages.length, 1);
  const firstCode = otp();
  now += 31_000;
  const second = await send();
  await rejected(verify(first.challengeId, firstCode));

  for (let i = 0; i < 5; i++) await rejected(verify(second.challengeId, incorrect()));
  await rejected(verify(second.challengeId, otp()));

  now += 31_000;
  const third = await send();
  for (let i = 0; i < 5; i++) await rejected(verify(third.challengeId, incorrect()));
  now += 31_000;
  const fourth = await send();
  await rejected(verify(fourth.challengeId, otp()));
  now += 10 * 60_000;
  await rejected(verify(fourth.challengeId, otp()));
  await send();
  await send();
  assert.equal(messages.length, 5);

  now += 60 * 60_000;
  const expired = await send();
  now += 10 * 60_000;
  await rejected(verify(expired.challengeId, otp()));

  const challenge = await send();
  const attempts = await Promise.allSettled([
    verify(challenge.challengeId, otp()), verify(challenge.challengeId, otp()),
  ]);
  const verified = attempts.filter(result => result.status === 'fulfilled');
  assert.equal(verified.length, 1);
  const { resetToken } = verified[0].value;
  await rejected(complete(challenge.challengeId, resetToken, other));
  const resets = await Promise.allSettled([
    complete(challenge.challengeId, resetToken), complete(challenge.challengeId, resetToken),
  ]);
  assert.equal(resets.filter(result => result.status === 'fulfilled').length, 1);
  await rejected(complete(challenge.challengeId, resetToken));

  async function signIn(address, value) {
    const response = await fetch(
      'http://' + process.env.FIREBASE_AUTH_EMULATOR_HOST +
      '/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake',
      { method: 'POST', headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: address, password: value, returnSecureToken: true }) },
    );
    return response.json();
  }
  assert.ok((await signIn(email, original)).error);
  assert.equal((await signIn(email, password)).localId, user.uid);
  assert.equal((await signIn(other, original)).localId, otherUser.uid);
  assert.equal((await auth.getUser(user.uid)).emailVerified, true);
  assert.equal((await db.doc('users/' + user.uid).get()).get('points'), 30);

  const adminEmail = 'admin@example.test';
  const admin = await auth.createUser({ email: adminEmail, password: original });
  await db.doc('users/' + admin.uid).set({ organizationId: 'gym' });
  await db.doc('orgs/gym/members/' + admin.uid)
    .set({ role: 'admin', organizationId: 'gym', status: 'active' });
  const before = messages.length;
  await send(adminEmail);
  assert.equal(messages.length, before);
  now += 31_000;
  const tokenChallenge = await send();
  const { resetToken: expiredToken } = await verify(tokenChallenge.challengeId, otp());
  now += 10 * 60_000;
  await rejected(complete(tokenChallenge.challengeId, expiredToken));

  const quotaRef = db.doc('passwordRecovery/delivery-quota');
  await quotaRef.set({ hours: { [Math.floor(now / 3600000)]: 250 } });
  const sentBeforeQuota = messages.length;
  await send(other);
  assert.equal(messages.length, sentBeforeQuota);
  const protectedResponse = await fetch(
    'http://' + process.env.FIRESTORE_EMULATOR_HOST +
    '/v1/projects/' + projectId + '/databases/(default)/documents/passwordRecovery/delivery-quota',
  );
  assert.equal(protectedResponse.status, 403);
  console.log('Password recovery Auth/Firestore emulator checks passed.');
}

main().catch(error => { console.error(error); process.exitCode = 1; });
