import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertFails, assertSucceeds, type RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, doc, documentId, getDoc, getDocs, limit, orderBy, query, setDoc, updateDoc, where } from 'firebase/firestore';
import { afterAll, beforeAll, beforeEach, expect, it } from 'vitest';
let env: RulesTestEnvironment;
const root='orgs/directory-org/members';
const client=(uid:string, verified=true)=>env.authenticatedContext(uid,{email_verified:verified}).firestore();
const list=(db:ReturnType<typeof client>,path=root)=>getDocs(query(collection(db,path),where('role','==','member'),orderBy(documentId()),limit(101)));
beforeAll(async()=>{
  if(!process.env.FIRESTORE_EMULATOR_HOST)throw Error('Isolated Firestore emulator required');
  env=await initializeTestEnvironment({projectId:'demo-gainpath',firestore:{rules:readFileSync(process.env.DIRECTORY_RULES_FILE||'../firebase/firestore.rules','utf8')}});
});
beforeEach(async()=>{
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context=>{
    for(const [id,role] of [['admin','admin'],['member','member'],['coach','coach']]){
      await setDoc(doc(context.firestore(),`users/${id}`),{organizationId:'directory-org'});
      await setDoc(doc(context.firestore(),`${root}/${id}`),{organizationId:'directory-org',displayName:id,email:`${id}@example.test`,role,status:'active',branchIds:['main']});
    }
  });
});
afterAll(async()=>{await env?.cleanup();});
it('Admin reads the existing member-only cursor query',async()=>{
  const rows=await assertSucceeds(list(client('admin')));
  expect(rows.docs.map(d=>d.id)).toEqual(['member']);
});
it('Member, Coach and anonymous users cannot enumerate the member directory',async()=>{
  for(const id of ['member','coach'])await assertFails(list(client(id)));
  await assertFails(list(env.unauthenticatedContext().firestore()));
});
it('foreign organization, unverified and suspended Admin reads are denied',async()=>{
  await assertFails(list(client('admin'),'orgs/another-org/members'));
  await assertFails(list(client('admin',false)));
  await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),`${root}/admin`),{status:'suspended'}));
  await assertFails(list(client('admin')));
});
it('directory access grants neither lifecycle writes nor another user private data',async()=>{
  const db=client('admin');
  await assertFails(updateDoc(doc(db,`${root}/member`),{status:'suspended'}));
  await assertFails(updateDoc(doc(db,`${root}/member`),{role:'admin'}));
  await assertFails(getDoc(doc(db,'users/member')));
});
