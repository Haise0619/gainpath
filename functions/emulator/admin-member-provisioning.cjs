const assert = require('node:assert/strict');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');
const { FirestoreStore } = require('../lib/platform/firestore/firestore-store');
const { AdminMemberProvisioning } = require('../lib/modules/identity/admin-member-provisioning');
const { resolveMembershipEntitlement } = require('../lib/modules/commerce/membership-entitlement');
const { provisionMember } = require('../lib/modules/identity/member-provisioning');

async function main() {
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST && process.env.FIREBASE_AUTH_EMULATOR_HOST);
  const projectId = 'demo-gainpath';
  initializeApp({projectId});
  const db = getFirestore(), auth = getAuth(), store = new FirestoreStore(db);
  const organizationId = 'gainpath', root = 'orgs/gainpath';
  const admin = { uid: 'admin', token: { email_verified: true } };
  const messages = [];
  let now = Date.now(), failEmail = true;
  const service = new AdminMemberProvisioning(store, auth, {async send(message) {
    if (failEmail) throw Error('test provider timeout');
    messages.push(message);
  }}, '', () => now);
  async function put(path, data) { await db.doc(path).set(data); }
  await put(root, {status:'active'});
  await put('orgs/other', {status:'active'});
  await put(root+'/branches/main', {status:'active', displayName:'Main Branch'});
  await put(root+'/branches/east', {status:'active', displayName:'GainPath East'});
  await put(root+'/branches/closed', {status:'inactive', displayName:'Closed Branch'});
  await put('orgs/other/branches/foreign', {status:'active', displayName:'Foreign Branch'});
  for (const role of ['admin','member','coach','staff']) {
    await put('users/'+role, {organizationId, role});
    await put(root+'/members/'+role, {organizationId,role,userId:role,status:'active',branchIds:['main']});
  }
  const input = {schemaVersion:1,organizationId,action:'create',requestId:'fixture-request',
    displayName:'Fixture <Member>',email:'NEW@example.test',phoneNumber:'+60 12 345 6789',homeBranchId:'east'};
  const denied = (promise, code) => assert.rejects(promise,{code});
  await denied(service.execute(undefined,input),'unauthenticated');
  for (const uid of ['member','coach','staff']) {
    await denied(service.execute({...admin,uid}, input),'permission-denied');
  }
  await denied(service.execute({...admin,token:{}},input),'permission-denied');
  await denied(service.execute(admin,{...input,organizationId:'other',homeBranchId:'foreign'}),'permission-denied');
  for (const homeBranchId of ['foreign','closed','absent']) {
    await denied(service.execute(admin,{...input,homeBranchId}),'failed-precondition');
  }
  await denied(service.execute(admin,{...input,role:'admin'}),'invalid-argument');
  const existing = await auth.createUser({uid:'existing-coach',email:'coach@example.test',displayName:'Original Coach',
    password:'OriginalCoachPassword',emailVerified:true});
  await denied(service.execute(admin,{...input,email:existing.email}),'already-exists');
  const existingAfter = await auth.getUser(existing.uid);
  assert.equal(existingAfter.displayName,existing.displayName);
  assert.equal(existingAfter.emailVerified,true);

  // Simulate the exact boundary after Firebase Auth exists and before Firestore links records.
  let interrupted = false;
  const flaky = {transact: work => store.transact(tx => work({
    get: path => tx.get(path),
    set: (path,data) => tx.set(path,data),
    create: (path,data) => {
      if (!interrupted && path.startsWith('users/member-')) {
        interrupted = true;
        throw Error('fixture transaction failure');
      }
      tx.create(path,data);
    },
  }))};
  const partial = new AdminMemberProvisioning(flaky,auth,{send: async () => assert.fail('setup email before commit')});
  await assert.rejects(partial.execute(admin,input), /fixture transaction failure/);
  const pendingAuth = await auth.getUserByEmail('new@example.test');
  assert.equal(pendingAuth.disabled,true);
  assert.equal((await db.doc('users/'+pendingAuth.uid).get()).exists,false);

  const result = await service.execute(admin,{...input,requestId:'recovery-request'});
  const uid = result.memberId;
  assert.equal(uid,pendingAuth.uid);
  assert.equal(result.delivery,'failed');
  assert.equal(result.accountStatus,'pending');
  assert.equal(result.branchName,'GainPath East');
  const user = (await db.doc('users/'+uid).get()).data(), member = (await db.doc(root+'/members/'+uid).get()).data();
  assert.equal(user.homeBranchId,'east');
  assert.equal(user.primaryBranchId,'east');
  assert.equal(user.selectedBranchId,undefined);
  assert.equal(user.phoneNumber,'+60123456789');
  assert.equal(member.role,'member');
  assert.equal(member.userId,uid);
  assert.deepEqual(member.branchIds,['east']);
  assert.equal((await auth.getUser(uid)).emailVerified,false);
  const again = await service.execute(admin,input);
  assert.equal(again.memberId,uid);
  assert.equal(again.delivery,'failed');
  await denied(service.execute(admin,{...input,requestId:'different-request'}),'already-exists');
  const describe = () => service.execute(admin,{schemaVersion:1,organizationId,action:'describe',memberIds:[uid]});
  const pending = (await describe()).members[0];
  assert.equal(pending.accountStatus,'pendingSetup');
  assert.equal(pending.membership,'free');
  assert.equal(pending.canResend,true);
  const resend = {schemaVersion:1,organizationId,action:'resend',memberId:uid};
  assert.equal((await service.execute(admin,resend)).delivery,'rate_limited');
  failEmail = false;
  now += 61_000;
  const attempts = await Promise.all([service.execute(admin,resend),service.execute(admin,resend)]);
  assert.equal(attempts.filter(result => result.delivery==='sent').length,1);
  assert.equal(messages.length,1);
  assert.equal(messages[0].subject,'Welcome to GainPath — Set up your account');
  assert.match(messages[0].htmlContent,/Fixture &lt;Member&gt;/);
  assert(!messages[0].htmlContent.includes('Fixture <Member>'));
  assert.equal(messages[0].to,'new@example.test');
  assert.equal((await auth.getUserByEmail('new@example.test')).uid,uid);
  const [,setup] = messages[0].textContent.match(/Set your password: (\S+)/);
  const [,verify] = messages[0].textContent.match(/Verify your email: (\S+)/);
  const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  async function rest(api, data) {
    const result = await fetch('http://'+authHost+'/identitytoolkit.googleapis.com/v1/'+api+'?key=fake',{
      method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(data),
    });
    return result.json();
  }
  const password = 'FixtureNewPassword22';
  const oobCode = new URL(setup).searchParams.get('oobCode');
  assert(oobCode);
  assert.equal((await rest('accounts:resetPassword',{oobCode,newPassword:password})).email,'new@example.test');
  assert.ok((await rest('accounts:resetPassword',{oobCode,newPassword:password})).error);
  if (!(await auth.getUser(uid)).emailVerified) {
    assert.equal((await rest('accounts:update',{oobCode:new URL(verify).searchParams.get('oobCode')})).emailVerified,true);
  }
  const signedIn = await rest('accounts:signInWithPassword',{email:'new@example.test',password,returnSecureToken:true});
  assert.equal(signedIn.localId,uid);
  const token = JSON.parse(Buffer.from(signedIn.idToken.split('.')[1],'base64url'));
  assert.equal(token.email_verified,true);
  await denied(service.execute({uid,token},{...input,requestId:'forbidden'}),'permission-denied');
  const entitlement = await store.transact(tx=>resolveMembershipEntitlement(tx,{uid,token},organizationId,now));
  assert.equal(entitlement.effectiveTier,'free');
  assert.equal((await db.doc(root+'/membershipAccounts/'+uid).get()).exists,false);
  assert.equal((await db.collection(root+'/transactions').get()).empty,true);
  const complete = (await describe()).members[0];
  assert.equal(complete.accountStatus,'active');
  assert.equal(complete.canResend,false);
  await service.execute(admin,resend);
  assert.equal(messages.length,1);
  await provisionMember(store,{userId:'self-registration',email:'self@example.test',displayName:'Self Registration'});
  const self = (await db.doc(root+'/members/self-registration').get()).data();
  assert.deepEqual(self.branchIds,['main']);
  assert.equal(self.role,'member');
  console.log('Admin member provisioning Auth/Firestore emulator flow passed.');
}
main().catch(error => {console.error(error);process.exitCode=1;});
