import { describe, expect, it } from 'vitest';
import { MemoryStore } from './memory-store';
import { seeds, now } from './booking-fixture';
import { module9MemberCommand } from '../src/modules/coaching/module9-member-service';

function store() { const s = new MemoryStore(); for (const [p, d] of Object.entries(seeds)) s.documents.set(p, structuredClone(d)); return s; }
const auth = { uid: 'member-1', token: { email_verified: true } };
const base = { schemaVersion: 1, organizationId: 'org-1' };
describe('Module 9 Member controls', () => {
  it('defaults sharing off, permits explicit grant and revocation without changing upload consent', async () => {
    const s = store();
    expect(await module9MemberCommand(s, auth, { ...base, action: 'sharing' })).toMatchObject({ enabled: false, revision: 0 });
    expect(await module9MemberCommand(s, auth, { ...base, action: 'sharing', enabled: true, expectedRevision: 0 }, () => now)).toMatchObject({ enabled: true, revision: 1 });
    await expect(module9MemberCommand(s, auth, { ...base, action: 'sharing', enabled: false, expectedRevision: 0 })).rejects.toThrow('Sharing settings changed');
    expect(await module9MemberCommand(s, auth, { ...base, action: 'sharing', enabled: false, expectedRevision: 1 })).toMatchObject({ enabled: false, revision: 2 });
    expect(s.documents.has('orgs/org-1/workoutConsents/member-1')).toBe(false);
  });
  it('denies reading or marking another Member notification', async () => {
    const s = store(); s.documents.set('orgs/org-1/notifications/n1', { recipientId: 'other' });
    await expect(module9MemberCommand(s, auth, { ...base, action: 'readNotification', notificationId: 'n1' })).rejects.toThrow('Notification unavailable');
  });
});
import { module9MemberCommand as memberCommand } from '../src/modules/coaching/module9-member-service';
it('paginates the Member inbox without disclosing other recipients', async () => {
  const s = store(); let receivedAfter: string | undefined;
  const rows = Array.from({ length: 31 }, (_, i) => ({ id: `n${i}`, data: { schemaVersion: 1, recipientId: 'member-1', title: 'Session update', message: 'View bookings', createdAtMillis: now, read: false } }));
  const reader = { list: async (_org: string, _uid: string, afterId?: string) => { receivedAfter = afterId; return afterId ? rows.slice(30) : rows; } };
  const page = await memberCommand(s, auth, { ...base, action: 'inbox' }, () => now, reader);
  expect(page).toMatchObject({ nextAfterId: 'n29' });
  expect('records' in page && page.records?.length).toBe(30);
  const next = await memberCommand(s, auth, { ...base, action: 'inbox', afterId: 'n29' }, () => now, reader);
  expect(receivedAfter).toBe('n29'); expect(next).toMatchObject({ nextAfterId: null });
  await expect(memberCommand(s, auth, { ...base, action: 'inbox' }, () => now, { list: async () => [{ id: 'private', data: { ...rows[0].data, recipientId: 'another-member' } }] })).rejects.toThrow('requires review');
});
it('redacts recommendation notices unless protected projection is explicitly supplied',async()=>{
  const s=store(),id=`recommendation-${'a'.repeat(64)}`,data={schemaVersion:1,type:'recommendation',recipientId:'member-1',recommendationId:'a'.repeat(64),recommendationKind:'trainer',title:'Private learning context',message:'Private suggestion',createdAtMillis:now,read:false};
  const reader={list:async()=>[{id,data}]};
  const result=await memberCommand(s,auth,{...base,action:'inbox'},()=>now,reader);
  expect(JSON.stringify(result)).not.toContain('Private');expect('records'in result&&result.records?.[0].title).toBe('Recommendation unavailable');
  s.documents.set(`orgs/org-1/notifications/${id}`,data);
  await expect(memberCommand(s,auth,{...base,action:'readNotification',notificationId:id})).rejects.toThrow('protected recommendation service');
});
it('preserves a protected typed recommendation reference rather than discarding fields',async()=>{
  const s=store(),recommendationId='b'.repeat(64),id=`recommendation-${recommendationId}`,data={schemaVersion:1,type:'recommendation',recipientId:'member-1',recommendationId,recommendationKind:'content',title:'Original',message:'Original',createdAtMillis:now,read:false};
  const reader={list:async()=>[{id,data}],projectRecommendation:async()=>({title:'Suggested tutorial',message:'Review your suggestion',recommendation:{schemaVersion:1 as const,recommendationId,kind:'content' as const,state:'unavailable' as const,expiresAtMillis:now+1000,target:null}})};
  const result=await memberCommand(s,auth,{...base,action:'inbox'},()=>now,reader);
  expect(result).toMatchObject({records:[{id,title:'Suggested tutorial',recommendation:{recommendationId,kind:'content',state:'unavailable',target:null}}]});
});
it('cannot bypass recommendation redaction with a malformed type tag',async()=>{
  const s=store(),id=`recommendation-${'c'.repeat(64)}`,data={schemaVersion:1,type:['recommendation'],recipientId:'member-1',recommendationId:'c'.repeat(64),recommendationKind:'trainer',title:'PRIVATE source text',message:'PRIVATE goal',createdAtMillis:now,read:false};
  await expect(memberCommand(s,auth,{...base,action:'inbox'},()=>now,{list:async()=>[{id,data}]})).rejects.toThrow();
});
