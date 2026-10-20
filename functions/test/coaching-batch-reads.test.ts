import { expect, it } from 'vitest';
import type { Firestore } from 'firebase-admin/firestore';
import { FirestoreStore } from '../src/platform/firestore/firestore-store';
import type { DocumentData, DocumentStore } from '../src/platform/firestore/store';
import { MemoryStore } from './memory-store';
import { getCoachAvailabilityService, saveCoachAvailabilityDayService } from '../src/modules/coaching/coach-availability-service';
import { getMemberBookingOptionsService } from '../src/modules/coaching/member-booking-options-service';
import { auth, now, read, root, save, seeds } from './coach-availability.fixture';
import { dateGrid } from '../src/modules/coaching/coach-availability-contracts';
import { keyOf } from '../src/platform/idempotency';
import { eligibleCoach } from './booking-fixture';

function fixture() {
  const memory = new MemoryStore();
  Object.entries(seeds()).forEach(([path, data]) => memory.documents.set(path, data));
  const batches: string[][] = [];
  const store: DocumentStore = { transact: work => memory.transact(tx => work({
    ...tx,
    get: async path => {
      if (path.includes('/slotLocks/')) throw Error('Individual slot RPC would serialize the entire date');
      return tx.get(path);
    },
    getAll: async (paths: readonly string[]) => {
      batches.push([...paths]);
      return Promise.all(paths.map(path => tx.get(path)));
    },
  })) };
  return { memory, store, batches };
}

it('exposes one native transaction batch preserving missing-document positions and skips empty batches', async () => {
  const calls: string[][] = [];
  const db = {
    doc: (path: string) => ({ path }),
    runTransaction: async (work: (tx: unknown) => Promise<unknown>) => work({
      getAll: async (...refs: {path:string}[]) => {
        calls.push(refs.map(r => r.path));
        return refs.map(r => ({ data: () => r.path === 'items/missing' ? undefined : { path:r.path } }));
      },
    }),
  } as unknown as Firestore;
  const result = await new FirestoreStore(db).transact(async tx => {
    const batch = tx as typeof tx & {getAll(paths: readonly string[]): Promise<(DocumentData|undefined)[]>};
    expect(await batch.getAll([])).toEqual([]);
    return batch.getAll(['items/first','items/missing','items/last']);
  });
  expect(result).toEqual([{path:'items/first'},undefined,{path:'items/last'}]);
  expect(calls).toEqual([['items/first','items/missing','items/last']]);
});

it('batches all requested days and every lock while retaining revisions and receipts', async () => {
  const f = fixture();
  await saveCoachAvailabilityDayService(f.store, auth('coach'), save(), () => now);
  const slots = dateGrid('2026-10-16', 'Asia/Kuala_Lumpur').slots;
  expect(f.batches[0]).toEqual(slots.map(s => `${root}/slotLocks/${keyOf('coach',s)}`));
  const context = await getCoachAvailabilityService(f.store, auth('coach'), read(), () => now);
  expect(context.days.find(d => d.localDate === '2026-10-16')?.revision).toBe(1);
  expect(f.batches[1]).toEqual(context.days.map(d=>`${root}/coachAvailability/coach/days/${d.localDate}`));
  const replay = await saveCoachAvailabilityDayService(f.store, auth('coach'), save(), () => now);
  expect(replay.revision).toBe(1);
  expect(f.batches).toHaveLength(2);
});

it('checks the final off-window lock in the batch and never writes after malformed lock data', async () => {
  const f = fixture();
  const slot = dateGrid('2026-10-16', 'Asia/Kuala_Lumpur').slots.at(-1)!;
  f.memory.documents.set(`${root}/slotLocks/${keyOf('coach',slot)}`, {status:['confirmed']});
  const before = structuredClone([...f.memory.documents]);
  await expect(saveCoachAvailabilityDayService(f.store, auth('coach'), save(), () => now)).rejects.toMatchObject({code:'failed-precondition'});
  expect([...f.memory.documents]).toEqual(before);
});

it('uses the same full-date batched lock checks for Member options without writing', async () => {
  const f = fixture();
  await saveCoachAvailabilityDayService(f.store, auth('coach'), save(), () => now);
  const before = structuredClone([...f.memory.documents]);
  const result = await getMemberBookingOptionsService(f.store, auth('member'), {schemaVersion:1,organizationId:'b2-org',coachId:'coach',localDate:'2026-10-16',durationMinutes:30}, eligibleCoach, () => now);
  expect(result.options).toHaveLength(2);
  expect(f.batches.at(-1)).toEqual(dateGrid('2026-10-16','Asia/Kuala_Lumpur').slots.map(s=>`${root}/slotLocks/${keyOf('coach',s)}`));
  expect([...f.memory.documents]).toEqual(before);
});
