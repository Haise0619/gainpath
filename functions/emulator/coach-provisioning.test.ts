import { deleteApp, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { expect, it } from 'vitest';
import { FirestoreStore } from '../src/platform/firestore/firestore-store';
import { provisionCoach } from '../src/modules/identity/coach-provisioning';

it('sets up a real emulator Coach auth account, private draft and password reset', async () => {
  const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  if (!authHost?.startsWith('127.0.0.1:') || !process.env.FIRESTORE_EMULATOR_HOST?.startsWith('127.0.0.1:')) {
    throw new Error('Loopback Auth and Firestore emulators are required.');
  }
  const projectId = 'demo-gainpath';
  const app = initializeApp({projectId},'coach-provisioning');
  const db = getFirestore(app), auth = getAuth(app);
  const org = 'coach-provisioning-org';
  const email = 'coach@example.test';
  const action = (operation:string, data:object) => fetch(`http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:${operation}?key=fixture`,{
    method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data),
  });
  try {
    const batch = db.batch();
    batch.set(db.doc('users/admin'),{organizationId:org,role:'admin'});
    batch.set(db.doc(`orgs/${org}`),{status:'active'});
    batch.set(db.doc(`orgs/${org}/members/admin`),{organizationId:org,role:'admin',status:'active',branchIds:[]});
    for(const id of ['one','two']) batch.set(db.doc(`orgs/${org}/branches/${id}`),{status:'active'});
    await batch.commit();
    const {coachId} = await provisionCoach(new FirestoreStore(db),auth,{uid:'admin',token:{email_verified:true}},{
      action:'provisionCoach',organizationId:org,requestId:'setup',email,displayName:'Test Coach',
      specialty:'Strength',yearsExperience:4,consultationFeeMinor:10000,bio:'',specializationTags:['Strength'],branchIds:['one','two'],
    });
    expect(await auth.getUser(coachId)).toMatchObject({disabled:false,emailVerified:false,email});
    expect((await db.doc(`orgs/${org}/members/${coachId}`).get()).data()).toMatchObject({branchIds:['one','two'],role:'coach'});
    expect((await db.doc(`orgs/${org}/coaches/${coachId}`).get()).exists).toBe(false);
    expect((await action('sendOobCode',{requestType:'PASSWORD_RESET',email})).status).toBe(200);
    const codes = await (await fetch(`http://${authHost}/emulator/v1/projects/${projectId}/oobCodes`)).json() as {oobCodes:{email:string;oobCode:string}[]};
    const oobCode = codes.oobCodes.find(code => code.email === email)?.oobCode;
    expect(oobCode).toBeTruthy();
    const password = 'EmulatorOnly!95';
    expect((await action('resetPassword',{oobCode,newPassword:password})).status).toBe(200);
    expect((await action('signInWithPassword',{email,password,returnSecureToken:true})).status).toBe(200);
    await auth.updateUser(coachId,{disabled:true});
    expect((await action('signInWithPassword',{email,password,returnSecureToken:true})).status).toBe(400);
  } finally {
    await db.terminate();
    await deleteApp(app);
  }
});
