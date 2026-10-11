import { describe, expect, it } from 'vitest';
import type { DocumentData, DocumentStore, TransactionPort } from '../src/platform/firestore/store';
import { DomainError } from '../src/platform/errors';
import { InputValidationError } from '../src/platform/validation';
import { publishRoutine } from '../src/modules/content/publish-routine';

class MemoryStore implements DocumentStore {
  readonly documents = new Map<string, DocumentData>();
  transactions = 0;

  async transact<T>(work: (tx: TransactionPort) => Promise<T>): Promise<T> {
    this.transactions++;
    const writes = new Map<string, DocumentData>();
    const tx: TransactionPort = {
      get: async path => this.documents.get(path),
      create: (path, data) => {
        if (this.documents.has(path) || writes.has(path)) throw new Error(`already exists: ${path}`);
        writes.set(path, data as DocumentData);
      },
      set: (path, data) => writes.set(path, data as DocumentData),
    };
    const result = await work(tx);
    for (const [path, data] of writes) this.documents.set(path, data);
    return result;
  }
}

const auth = (uid = 'staff-1', verified = true) => ({
  uid,
  token: { email_verified: verified },
});
const request = {
  schemaVersion: 1,
  requestId: 'publish-1',
  organizationId: 'org-1',
  blueprintId: 'blueprint-1',
};
const blueprint = {
  schemaVersion: 1,
  name: 'Strength basics',
  sessionDurationMin: 30,
  days: [{
    dayNumber: 1,
    exercises: [{ exerciseId: 'squat-1', sets: 3, reps: 8 }],
  }],
};
function setup(role = 'staff') {
  const store = new MemoryStore();
  store.documents.set('users/staff-1', { organizationId: 'org-1' });
  store.documents.set('orgs/org-1/members/staff-1', {
    role, status: 'active', branchIds: ['branch-1'],
  });
  store.documents.set('orgs/org-1/routineBlueprints/blueprint-1', blueprint);
  store.documents.set('orgs/org-1/exerciseVideos/squat-1', {
    exerciseName: 'Squat', muscleCategory: 'Lower body', videoUrl: '', isActive: true,
  });
  return store;
}

describe('publishRoutine', () => {
  it('publishes only a server-composed catalog projection for active staff', async () => {
    const store = setup();
    const result = await publishRoutine(store, auth(), request, () => 1000);
    expect(result).toMatchObject({ status: 'published', sourceBlueprintId: 'blueprint-1' });
    expect(store.documents.get('orgs/org-1/content/routine_blueprint-1')).toMatchObject({
      schemaVersion: 1,
      kind: 'routine',
      status: 'published',
      sourceBlueprintId: 'blueprint-1',
      title: 'Strength basics',
      estimatedMinutes: 30,
      exercises: [{ exerciseId: 'squat-1', name: 'Squat', sets: 3, reps: 8 }],
    });
  });

  it('rejects member, inactive, wrong-organization, and unverified callers', async () => {
    const memberStore = setup('member');
    await expect(publishRoutine(memberStore, auth(), request)).rejects.toMatchObject({ code: 'permission-denied' });
    const inactiveStore = setup();
    inactiveStore.documents.set('orgs/org-1/members/staff-1', { role: 'staff', status: 'suspended', branchIds: [] });
    await expect(publishRoutine(inactiveStore, auth(), request)).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(publishRoutine(setup(), auth('staff-1', false), request)).rejects.toMatchObject({ code: 'permission-denied' });
    const wrongOrg = setup();
    wrongOrg.documents.set('users/staff-1', { organizationId: 'other-org' });
    await expect(publishRoutine(wrongOrg, auth(), request)).rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('rejects unknown client fields and invalid exercise references before writing', async () => {
    const store = setup();
    await expect(publishRoutine(store, auth(), { ...request, status: 'published' }))
      .rejects.toBeInstanceOf(InputValidationError);
    store.documents.set('orgs/org-1/routineBlueprints/blueprint-1', {
      ...blueprint,
      days: [{ dayNumber: 1, exercises: [{ exerciseId: 'missing', sets: 2, reps: 5 }] }],
    });
    await expect(publishRoutine(store, auth(), request)).rejects.toMatchObject({ code: 'failed-precondition' });
    expect(store.documents.has('orgs/org-1/content/routine_blueprint-1')).toBe(false);
  });

  it('rejects duplicated exercise data in a blueprint instead of trusting it', async () => {
    const store = setup();
    store.documents.set('orgs/org-1/routineBlueprints/blueprint-1', {
      ...blueprint,
      days: [{ dayNumber: 1, exercises: [{ exerciseId: 'squat-1', exerciseName: 'Client supplied name', sets: 3, reps: 8 }] }],
    });
    await expect(publishRoutine(store, auth(), request)).rejects.toMatchObject({ code: 'failed-precondition' });
    expect(store.documents.has('orgs/org-1/content/routine_blueprint-1')).toBe(false);
  });

  it('returns the same publication on retry and rejects request ID reuse', async () => {
    const store = setup();
    const first = await publishRoutine(store, auth(), request, () => 1000);
    const second = await publishRoutine(store, auth(), request, () => 2000);
    expect(second).toEqual(first);
    const receiptCount = [...store.documents.keys()].filter(path => path.includes('/commandReceipts/')).length;
    expect(receiptCount).toBe(1);
    await expect(publishRoutine(store, auth(), { ...request, blueprintId: 'other' }, () => 3000))
      .rejects.toMatchObject({ code: 'already-exists' });
  });
});
