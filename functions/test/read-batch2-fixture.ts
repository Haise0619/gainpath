import { ReadProbeStore } from './read-probe-store';
import type { PaymentAdminDependencies } from '../src/modules/commerce/booking-payment-admin';

export const org = 'batch-org';
export const auth = { uid: 'admin', token: { email_verified: true } };
export const input = { schemaVersion: 1, organizationId: org };
export const certificationId = 'a'.repeat(32);
export function fixture(delay = 0) {
  const store = new ReadProbeStore(delay);
  store.documents.set(`orgs/${org}`, { status: 'active' });
  for (const [id, role] of [['admin', 'admin'], ['coach', 'coach'], ['member', 'member']]) {
    store.documents.set(`users/${id}`, { organizationId: org });
    store.documents.set(`orgs/${org}/members/${id}`, { organizationId: org, role, status: 'active', branchIds: [], displayName: id });
  }
  const rows = Array.from({ length: 21 }, (_, i) => {
    const id = `payment${String(i).padStart(2, '0')}`;
    return { id, data: { schemaVersion: 1, organizationId: org, environment: 'sandbox', provider: 'billplz',
      bookingId: id, kind: 'CoachingBooking', memberId: 'member', coachId: 'coach', amountMinor: 100, currency: 'MYR', paymentStatus: 'cleared', fulfilmentStatus: 'confirmed' } };
  });
  for (const row of rows) store.documents.set(`orgs/${org}/transactions/${row.id}`, row.data);
  const unavailable = async (): Promise<never> => { throw Error('Read cannot call provider'); };
  const deps: PaymentAdminDependencies = { collectionId: 'fixture', bills: { get: unavailable, create: unavailable }, readIdentity: unavailable,
    reader: { list: async () => rows, events: async () => [{ id: 'event', data: { event: 'fixture', atMillis: 1, secret: 'private' } }] } };
  const ids = Array.from({ length: 21 }, (_, i) => i.toString(16).padStart(32, '0'));
  store.documents.set(`orgs/${org}/coachProfiles/coach/certificationState/current`, { certificationIds: [...ids, certificationId], approvedCount: 1, certificationVerified: true });
  for (const id of [...ids, certificationId]) store.documents.set(`orgs/${org}/coachProfiles/coach/certifications/${id}`, { certificationId: id, revision: 20, status: 'approved' });
  for (let v = 1; v <= 20; v++) store.documents.set(`orgs/${org}/coachProfiles/coach/certifications/${certificationId}/history/${v}`, { revision: v });
  const photoPath = `orgs/${org}/coachProfilePhotos/coach/${certificationId}`;
  store.documents.set(`orgs/${org}/coaches/coach`, { status: 'published', certificationVerified: true, approvedCertificationCount: 1, revision: 1, photoPath });
  return { store, rows, deps, photoPath };
}
