import { expect, it, vi } from 'vitest';
import type { Auth } from 'firebase-admin/auth';
import { provisionCoach } from '../src/modules/identity/coach-provisioning';
import { MemoryStore } from './memory-store';

const input = {action:'provisionCoach',organizationId:'org',requestId:'setup-1',email:'coach@example.test',
  displayName:'Fixture Coach',specialty:'Strength',bio:'',specializationTags:['Strength'],yearsExperience:5,
  consultationFeeMinor:10000,branchIds:['east','west']};
const actor = {uid:'actor',token:{email_verified:true}};
function fixture(role = 'admin') {
  const store = new MemoryStore();
  store.documents.set('users/actor',{organizationId:'org',role});
  store.documents.set('orgs/org',{status:'active'});
  store.documents.set('orgs/org/members/actor',{organizationId:'org',role,status:'active',branchIds:[]});
  for (const id of input.branchIds) store.documents.set(`orgs/org/branches/${id}`,{status:'active'});
  const users = new Map<string, any>();
  const getUser = vi.fn(async (id: string) => {
    if (!users.has(id)) throw {code:'auth/user-not-found'};
    return users.get(id);
  });
  const createUser = vi.fn(async (record: any) => {
    if ([...users.values()].some(user => user.email === record.email)) throw {code:'auth/email-already-exists'};
    const {password, ...saved} = record;
    expect(password).toMatch(/^[A-Za-z0-9_-]{40,}$/);
    users.set(record.uid,saved);
    return saved;
  });
  const updateUser = vi.fn(async (id: string, patch: object) => {
    const next = {...users.get(id),...patch};
    users.set(id,next);
    return next;
  });
  const auth: Pick<Auth,'getUser'|'createUser'|'updateUser'> = {getUser,createUser,updateUser};
  return {store,auth,users,createUser,updateUser};
}

it('creates one unverified Coach with multiple assignments and an unpublished draft', async () => {
  const f = fixture();
  const {coachId} = await provisionCoach(f.store,f.auth,actor,input);
  expect(await provisionCoach(f.store,f.auth,actor,input)).toEqual({coachId});
  expect(f.users.get(coachId)).toMatchObject({emailVerified:false,disabled:false});
  expect(f.store.documents.get(`orgs/org/members/${coachId}`)).toMatchObject({role:'coach',branchIds:['east','west']});
  expect(f.store.documents.get(`orgs/org/coachProfiles/${coachId}`)).toMatchObject({specialty:'Strength',revision:1});
  expect(f.store.documents.has(`orgs/org/coaches/${coachId}`)).toBe(false);
  expect(f.createUser).toHaveBeenCalledTimes(1);
  expect(f.updateUser).toHaveBeenCalledTimes(1);
});
it.each(['coach','member'])('rejects %s before touching Auth',async role=>{
  const f=fixture(role);
  await expect(provisionCoach(f.store,f.auth,actor,input)).rejects.toMatchObject({code:'permission-denied'});
  expect(f.createUser).not.toHaveBeenCalled();
});
it('rejects an invalid branch and a supplied role',async ()=>{
  const f=fixture();
  await expect(provisionCoach(f.store,f.auth,actor,{...input,branchIds:['missing']})).rejects.toMatchObject({code:'failed-precondition'});
  await expect(provisionCoach(f.store,f.auth,actor,{...input,role:'admin'})).rejects.toMatchObject({code:'invalid-argument'});
  expect(f.createUser).not.toHaveBeenCalled();
});
it('never converts an existing account with the same email',async()=>{
  const f=fixture();f.users.set('existing',{email:input.email,disabled:false});
  await expect(provisionCoach(f.store,f.auth,actor,input)).rejects.toMatchObject({code:'already-exists'});
  expect(f.users.size).toBe(1);
  expect(f.updateUser).not.toHaveBeenCalled();
});
it('resumes a linked disabled account after an Auth enable failure',async()=>{
  const f=fixture();f.updateUser.mockRejectedValueOnce(new Error('temporary'));
  await expect(provisionCoach(f.store,f.auth,actor,input)).rejects.toThrow('temporary');
  expect([...f.users.values()][0].disabled).toBe(true);
  const {coachId}=await provisionCoach(f.store,f.auth,actor,input);
  expect(f.users.get(coachId).disabled).toBe(false);
  expect(f.createUser).toHaveBeenCalledTimes(1);
});
