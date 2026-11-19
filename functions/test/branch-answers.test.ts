import type { Firestore } from 'firebase-admin/firestore';
import { describe, expect, it, vi } from 'vitest';
import { branchAnswer, branchQuestion } from '../src/modules/chatbot/branch-answers';

function store() {
  const catalog = { id: 'eq-17', get: () => 'Dumbbell' };
  const north = { id: 'north', get: () => 'North Gym' };
  const east = { id: 'east', get: () => 'East Gym' };
  const collection = vi.fn((path: string) => {
    const docs = path.endsWith('/gymEquipment') ? [catalog] : [north, east];
    return { where: () => ({ limit: () => ({ get: async () => ({ docs, size: docs.length }) }) }) };
  });
  const doc = (path: string) => ({
    path,
    get: async () => ({
      data: () => path === 'users/member' ? { selectedBranchId: 'north' }
        : { status: 'active', displayName: 'North Gym', facilities: ['Showers', 'Lockers'] },
    }),
  });
  const getAll = vi.fn(async (...refs: { path: string }[]) => refs.map(ref => ({
    data: () => ref.path.includes('/north/') ? { quantity: 5, maintenance: 2 } : undefined,
  })));
  return { db: { collection, doc, getAll } as unknown as Firestore, getAll };
}

describe('branch assistant questions', () => {
  it('recognizes facilities and named equipment without intercepting workout advice', () => {
    expect(branchQuestion('What facilities are available?')).toBe('facilities');
    expect(branchQuestion('Does this branch have a lat pulldown machine?'))
      .toEqual({ equipment: 'lat pulldown machine', allBranches: false });
    expect(branchQuestion('Which branches have dumbbells?'))
      .toEqual({ equipment: 'dumbbells', allBranches: true });
    expect(branchQuestion('How should I train with dumbbells?')).toBeUndefined();
  });

  it('lists recorded facilities and reads other branches by canonical equipment ID', async () => {
    const { db, getAll } = store();
    const onBranch = vi.fn();
    expect(await branchAnswer(db, 'org', 'member', 'facilities', 0, onBranch))
      .toBe('North Gym lists these facilities: Showers, Lockers.');
    expect(onBranch).toHaveBeenCalledWith({
      branchId: 'north', displayName: 'North Gym', status: 'active',
      facilities: ['Showers', 'Lockers'],
    });
    expect(await branchAnswer(db, 'org', 'member', { equipment: 'dumbbells', allBranches: true }, 0))
      .toBe('Recorded usable Dumbbell: North Gym (3).');
    expect(getAll).toHaveBeenCalledOnce();
    expect(getAll.mock.calls[0].map(ref => ref.path)).toEqual([
      'orgs/org/branches/north/equipmentInventory/eq-17',
      'orgs/org/branches/east/equipmentInventory/eq-17',
    ]);
  });

  it('represents missing inventory as unavailable rather than counting zero units', async () => {
    const { db, getAll } = store();
    getAll.mockResolvedValueOnce([{ data: () => undefined }]);
    expect(await branchAnswer(db, 'org', 'member', { equipment: 'dumbbells', allBranches: false }, 0))
      .toBe('Inventory for Dumbbell at North Gym is unavailable. Check with gym staff.');
  });
});
