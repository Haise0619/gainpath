import { afterEach, expect, it } from 'vitest';
import { MemoryStore } from './memory-store';
import { changeCoachCertification, getCoachCertifications } from '../src/modules/coaching/coach-certification-service';
import { getCoachAccountSettings, saveCoachAccountSettings } from '../src/modules/coaching/coach-account-service';
import { saveCoachProfile, setCoachDirectoryStatus } from '../src/modules/coaching/coach-profile-service';
const auth = (uid = 'coach') => ({ uid, token: { email_verified: true } });
const base = { schemaVersion: 1, organizationId: 'o' }, id = 'a'.repeat(32);
const upload = async () => ({ generation: '1', contentType: 'application/pdf', size: 20 });
function setup() { const store = new MemoryStore(); store.documents.set('orgs/o', { status: 'active' }); store.documents.set('orgs/o/branches/main', { status: 'active' }); for (const [uid, role] of [['coach','coach'],['other','coach'],['admin','admin'],['member','member']]) { store.documents.set(`users/${uid}`, { organizationId: 'o' }); store.documents.set(`orgs/o/members/${uid}`, { organizationId: 'o', role, status: 'active', branchIds: ['main'] }); } return store; }
const submit = { ...base, requestId: 'submit', certificationId: id, title: 'Certificate', issuer: 'Issuer', storagePath: `orgs/o/coachCertifications/coach/${id}` };
const review = { ...base, requestId: 'review', certificationId: id, coachId: 'coach', expectedRevision: 1, decision: 'approve' };
afterEach(() => { delete process.env.COACH_CERTIFICATION_ELIGIBILITY_ENABLED; });
it('submits verified uploads, replays without revalidation and keeps immutable reviewed history', async () => {
 const store = setup(); let calls = 0; const validator = async () => { calls++; return upload(); };
 await changeCoachCertification(store, auth(), submit, 'submit', validator, () => 10);
 await changeCoachCertification(store, auth(), submit, 'submit', validator); expect(calls).toBe(1);
 await changeCoachCertification(store, auth('admin'), review, 'review', upload, () => 20);
 const data = await getCoachCertifications(store, auth(), { ...base, certificationId: id }); expect(data).toMatchObject({ approvedCount: 1, certificationVerified: true });
 expect(data.certifications[0]).toMatchObject({ status: 'approved', revision: 2, history: [{ actorId: 'admin' }, { status: 'pending' }] });
 expect(store.documents.get(`orgs/o/coachProfiles/coach/certifications/${id}/history/1`)).toMatchObject({ status: 'pending', actorId: 'coach' });
 await expect(changeCoachCertification(store, auth('admin'), { ...review, requestId: 'stale' }, 'review', upload)).rejects.toMatchObject({ code: 'aborted' });
 await expect(changeCoachCertification(store, auth('admin'), { ...review, requestId: 'reject', expectedRevision: 2, decision: 'reject' }, 'review', upload)).rejects.toThrow();
});
it('authorizes before storage validation; rejects cross-owner paths and private reads', async () => {
 const store = setup(); const validator = async () => { throw Error('must not call'); };
 await expect(changeCoachCertification(store, auth('member'), { ...submit, storagePath: `orgs/o/coachCertifications/member/${id}` }, 'submit', validator)).rejects.toMatchObject({ code: 'permission-denied' });
 await expect(changeCoachCertification(store, auth('other'), submit, 'submit', validator)).rejects.toThrow('Invalid upload path');
 await expect(getCoachCertifications(store, auth('other'), { ...base, coachId: 'coach' })).rejects.toMatchObject({ code: 'permission-denied' });
});
it('keeps BR5 opt-in; opted in archive atomically deactivates public listing', async () => {
 const store = setup(); store.documents.set('orgs/o/coaches/coach', { status: 'published', revision: 4 });
 await changeCoachCertification(store, auth(), submit, 'submit', upload);
 await changeCoachCertification(store, auth('admin'), review, 'review', upload);
 expect(store.documents.get('orgs/o/coaches/coach')?.status).toBe('published');
 process.env.COACH_CERTIFICATION_ELIGIBILITY_ENABLED = 'true';
 await changeCoachCertification(store, auth(), { ...base, requestId: 'archive', certificationId: id, expectedRevision: 2 }, 'archive', upload);
 expect(store.documents.get('orgs/o/coaches/coach')).toMatchObject({ status: 'inactive', revision: 7, certificationVerified: false, approvedCertificationCount: 0 });
});
it('claims normalized phone atomically, prevents reuse, supports revision and receipt replay', async () => {
 const store = setup(); const prefs = { newBookings: true, cancellations: false, reminders: true };
 expect(await getCoachAccountSettings(store, auth(), base)).toMatchObject({ revision: 0 });
 const save = { ...base, requestId: 'phone', expectedRevision: 0, contactPhone: '+60 123456789', coachNotificationPreferences: prefs };
 const result = await saveCoachAccountSettings(store, auth(), save); expect(result.contactPhone).toBe('+60123456789');
 expect(await saveCoachAccountSettings(store, auth(), save)).toEqual(result);
 await expect(saveCoachAccountSettings(store, auth('other'), save)).rejects.toMatchObject({ code: 'already-exists' });
 await expect(saveCoachAccountSettings(store, auth(), { ...save, requestId: 'stale' })).rejects.toMatchObject({ code: 'aborted' });
});
it('supports optional profile display fields and explicit gated publication', async () => {
 const store = setup(); await saveCoachProfile(store, auth(), { ...base, requestId:'profile', expectedRevision:0, patch: { displayName:'Coach', specialty:'Fitness', bio:'', specializationTags:['Fitness'], yearsExperience:2, consultationFeeMinor:12500, photoPath:`orgs/o/coachProfilePhotos/coach/${id}` } });
 process.env.COACH_CERTIFICATION_ELIGIBILITY_ENABLED = 'true';
 const command = { ...base, requestId:'publish', coachId:'coach', action:'publish', expectedProfileRevision:1, expectedPublicRevision:0, expectedCoachBranchIds:['main'] };
 const identity = async () => ({ exists:true, disabled:false, emailVerified:true });
 await expect(setCoachDirectoryStatus(store, auth('admin'), command, identity)).rejects.toMatchObject({ code:'failed-precondition' });
 delete process.env.COACH_CERTIFICATION_ELIGIBILITY_ENABLED;
 await setCoachDirectoryStatus(store, auth('admin'), command, identity);
 expect(store.documents.get('orgs/o/coaches/coach')).toMatchObject({ consultationFeeMinor:12500 });
});



it('paginates bounded certification lists and loads audit only for selected detail', async () => {
 const store = setup(), ids = Array.from({length:21}, (_, i) => i.toString(16).padStart(32,'0'));
 store.documents.set('orgs/o/coachProfiles/coach/certificationState/current', { certificationIds:ids, approvedCount:0 });
 for (const id of ids) store.documents.set(`orgs/o/coachProfiles/coach/certifications/${id}`, { id,revision:1,status:'pending' });
 const page = await getCoachCertifications(store, auth(), base); expect(page.certifications).toHaveLength(20); expect(page.nextCursor).toBe(ids[19]); expect(page.certifications[0].history).toEqual([]);
 const next = await getCoachCertifications(store, auth(), {...base, afterId:page.nextCursor}); expect(next.certifications).toHaveLength(1); expect(next.nextCursor).toBeNull();
});
it('saves preferences with optional blank phone and releases prior phone claim', async () => {
 const store = setup(), preferences = { newBookings:true,cancellations:true,reminders:false };
 const command = {...base,requestId:'empty',expectedRevision:0,contactPhone:'',coachNotificationPreferences:preferences};
 expect(await saveCoachAccountSettings(store,auth(),command,()=>10)).toMatchObject({contactPhone:'',updatedAtMillis:10});
 expect([...store.documents.keys()].some(p=>p.startsWith('phoneClaims/'))).toBe(false);
 await saveCoachAccountSettings(store,auth(),{...command,requestId:'phone',expectedRevision:1,contactPhone:'+60123456789'});
 await saveCoachAccountSettings(store,auth(),{...command,requestId:'clear',expectedRevision:2});
 await saveCoachAccountSettings(store,auth('other'),{...command,requestId:'reuse',expectedRevision:0,contactPhone:'+60123456789'});
 expect(store.documents.get('users/coach')?.contactPhone).toBe('');
});
import { getCoachPublishedPhoto } from '../src/modules/coaching/coach-photo-service';
it('published photo proxy authorizes before download and rechecks revocation after download', async () => {
 const store = setup(), path = `orgs/o/coachProfilePhotos/coach/${id}`;
 store.documents.set('orgs/o/coaches/coach',{status:'published',certificationVerified:true,approvedCertificationCount:1,revision:1,photoPath:path});
 const command = {...base,coachId:'coach'};
 expect(await getCoachPublishedPhoto(store,auth('member'),command,async () => ({contentType:'image/png',bytesBase64:'bytes'}))).toMatchObject({photoPath:path,bytesBase64:'bytes'});
 await expect(getCoachPublishedPhoto(store,auth('member'),command,async () => {store.documents.get('orgs/o/members/member')!.status='inactive';return {contentType:'image/png',bytesBase64:'bytes'};})).rejects.toMatchObject({code:'permission-denied'});
});
it('published photo proxy rejects private listings, unsafe paths and caller supplied paths', async () => {
 const store=setup(), command={...base,coachId:'coach'}, download=async()=>{throw Error('must not download');};
 await expect(getCoachPublishedPhoto(store,auth('member'),command,download)).rejects.toMatchObject({code:'not-found'});
 store.documents.set('orgs/o/coaches/coach',{status:'published',certificationVerified:true,approvedCertificationCount:1,revision:1,photoPath:'orgs/o/coachProfilePhotos/other/' + id});
 await expect(getCoachPublishedPhoto(store,auth('member'),command,download)).rejects.toMatchObject({code:'failed-precondition'});
 await expect(getCoachPublishedPhoto(store,auth('member'),{...command,photoPath:'arbitrary'},download)).rejects.toThrow();
});
