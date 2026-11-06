/** E-only loopback transport. Reuses pure fictional D/C source, never their SDK adapters. */
import {FieldPath, type Firestore} from 'firebase-admin/firestore';
import {DomainError} from '../src/platform/errors';
import type {QueuePageReader} from '../src/modules/recommendation/recommendation-queue-reader';
import type {NotificationReader} from '../src/modules/coaching/module9-member-service';
import {mintRecommendationEmulatorCapability} from '../src/modules/recommendation/recommendation-callable-readiness';
import {MODULE13_C_MEMBER} from './module13-c-integration.fixture';
export {createModule13DFixture as createModule13ESource, module13DFixtureDocuments as module13EFixtureDocuments, module13DLogicalClock as module13ELogicalClock} from './module13-d-integration.fixture';
export const MODULE13_E_PROJECT = 'demo-gainpath-module13-e';
export const MODULE13_E_HOST = '127.0.0.1:18115';
export const MODULE13_E_ROOT = 'orgs/synthetic-org';
export function guardModule13E(db?: Firestore): void {
  if (process.env.FIRESTORE_EMULATOR_HOST !== MODULE13_E_HOST || process.env.GCLOUD_PROJECT !== MODULE13_E_PROJECT || process.env.GOOGLE_CLOUD_PROJECT !== MODULE13_E_PROJECT) {
    throw new DomainError('failed-precondition', 'Dedicated E loopback demo emulator required.');
  }
  if (db) mintRecommendationEmulatorCapability(db);
}
export function createModule13EQueueReader(db: Firestore): QueuePageReader {
  return {readLeads: async (org, after, limit) => {
    guardModule13E(db);
    if (org !== 'synthetic-org' || (after !== null && !/^[a-f0-9]{64}$/.test(after)) || !Number.isSafeInteger(limit) || limit < 1 || limit > 101) throw new DomainError('invalid-argument', 'Invalid bounded E queue.');
    let query = db.collection(`${MODULE13_E_ROOT}/recommendationLeads`).orderBy(FieldPath.documentId()).limit(limit);
    if (after) query = query.startAfter(after);
    return (await query.get()).docs.map(d => ({id: d.id, data: d.data()}));
  }};
}
export function createModule13EInboxReader(db: Firestore): NotificationReader {
  return {list: async (org, uid, after) => {
    guardModule13E(db);
    if (org !== 'synthetic-org' || uid !== MODULE13_C_MEMBER) throw new DomainError('permission-denied', 'Fixture Member required.');
    let query = db.collection(`${MODULE13_E_ROOT}/notifications`).where('recipientId', '==', uid).orderBy('createdAtMillis', 'desc').orderBy(FieldPath.documentId(), 'desc').limit(31);
    if (after) {
      const cursor = await db.doc(`${MODULE13_E_ROOT}/notifications/${after}`).get();
      if (!cursor.exists || cursor.data()?.recipientId !== uid) throw new DomainError('permission-denied', 'Invalid owned cursor.');
      query = query.startAfter(cursor);
    }
    return (await query.get()).docs.map(d => ({id: d.id, data: d.data()}));
  }};
}
