import { randomBytes } from 'node:crypto';
import { requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import { readAll, type DocumentData, type DocumentStore, type TransactionPort } from '../../platform/firestore/store';
import { keyOf } from '../../platform/idempotency';
import { requiredIdentifier } from '../../platform/validation';
import { requireMembershipCapability } from '../commerce/membership-capabilities';
import { currentBookingMembership, requireBookingOrganization } from '../coaching/booking-validation';

type Actor = { uid: string; token: Record<string, unknown> } | undefined;
type Row = { id: string; data: DocumentData };
export type OperationsReader = (path: string, order: 'id' | 'recent', afterId?: string) => Promise<Row[]>;
export const branchOperationsActions = new Set([
  'inventory', 'catalog', 'saveInventory', 'removeInventory',
  'issueVisitCode', 'checkIn', 'myVisits', 'branchVisits',
  'equipmentAvailability',
]);
const denied = () => new DomainError('permission-denied', 'This branch operation is not available for your account.');
const count = (value: unknown): value is number =>
  typeof value === 'number' && Number.isInteger(value) && value >= 0 && value <= 10000;
const visitWindow = 5 * 60 * 1000;
const visitCooldown = 15 * 60 * 1000;

export async function branchOperations(store: DocumentStore, rows: OperationsReader, auth: Actor, input: DocumentData, clock = Date.now) {
  requireVerifiedEmail(auth);
  const uid = requiredIdentifier(auth!.uid, 'actorId');
  const org = requiredIdentifier(input.organizationId, 'organizationId');
  const root = `orgs/${org}`;
  const action = String(input.action);
  const id = ['catalog', 'myVisits', 'equipmentAvailability'].includes(action) ? undefined : requiredIdentifier(input.branchId, 'branchId');
  const branch = `${root}/branches/${id}`;
  const adminOnly = ['catalog', 'saveInventory', 'removeInventory', 'issueVisitCode', 'branchVisits'].includes(action);
  const authorize = async (tx: TransactionPort) => {
    await requireBookingOrganization(tx, org);
    const actor = await currentBookingMembership(tx, org, uid);
    if ((adminOnly && actor.role !== 'admin') || (['myVisits', 'checkIn'].includes(action) && actor.role !== 'member')) throw denied();
    if (id) {
      const data = await tx.get(branch);
      if (!data || ((actor.role !== 'admin' || action === 'issueVisitCode') && data.status !== 'active')) throw denied();
      return data;
    }
    return undefined;
  };

  if (action === 'equipmentAvailability') {
    const equipmentId = requiredIdentifier(input.equipmentId, 'equipmentId');
    const selected = await store.transact<DocumentData>(async tx => {
      await authorize(tx);
      const user = await tx.get(`users/${uid}`);
      for (const candidate of new Set([user?.selectedBranchId, user?.homeBranchId, user?.primaryBranchId])) {
        if (typeof candidate !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(candidate)) continue;
        const path = `${root}/branches/${candidate}`;
        const location = await tx.get(path);
        if (location?.status !== 'active') continue;
        const item = await tx.get(`${path}/equipmentInventory/${equipmentId}`);
        const recorded = !!item && item.removed !== true && count(item.quantity) && count(item.maintenance);
        return { branchId: candidate, branchName: location.displayName ?? candidate, recorded,
          ...(recorded ? { usable: Number(item!.quantity) - Number(item!.maintenance),
            maintenance: item!.maintenance } : {}) };
      }
      return { recorded: false };
    });
    if (Number(selected.usable) > 0) return { ...selected, otherBranches: [] };
    const locations = await rows(`${root}/branches`, 'id');
    return store.transact(async tx => {
      await authorize(tx);
      const candidates = locations.slice(0, 30).filter(row => row.id !== selected.branchId);
      const branches = await readAll(tx, candidates.map(row => `${root}/branches/${row.id}`));
      const stock = await readAll(tx, candidates.map(row => `${root}/branches/${row.id}/equipmentInventory/${equipmentId}`));
      const otherBranches = candidates.flatMap((row, index) => {
        const location = branches[index], item = stock[index];
        if (location?.status !== 'active' || typeof location.displayName !== 'string'
          || !item || item.removed === true || !count(item.quantity) || !count(item.maintenance)
          || item.quantity <= item.maintenance) return [];
        return [{ branchId: row.id, branchName: location.displayName, usable: item.quantity - item.maintenance,
          ...(typeof location.address === 'string' ? { address: location.address } : {}),
          ...(typeof location.latitude === 'number' && typeof location.longitude === 'number'
            ? { latitude: location.latitude, longitude: location.longitude } : {}) }];
      });
      return { ...selected, otherBranches, otherBranchesPartial: locations.length > 30 };
    });
  }

  if (['inventory', 'catalog', 'branchVisits', 'myVisits'].includes(action)) {
    await store.transact(authorize);
    const path = action === 'catalog' ? `${root}/gymEquipment`
      : action === 'inventory' ? `${branch}/equipmentInventory`
      : action === 'branchVisits' ? `${branch}/gymVisits` : `${root}/members/${uid}/gymVisits`;
    const after = input.afterId == null ? undefined : requiredIdentifier(input.afterId, 'afterId');
    const result = await rows(path, action.endsWith('Visits') ? 'recent' : 'id', after);
    await store.transact(authorize);
    const records = result.slice(0, 30).flatMap<DocumentData>(({ id: rowId, data }) => {
      if (action === 'catalog') return data.isActive === true ? [{ equipmentId: rowId, name: data.name }] : [];
      if (action === 'inventory') return data.removed === true ? [] : [{
        equipmentId: rowId, name: data.name, quantity: data.quantity, maintenance: data.maintenance,
        usable: Number(data.quantity) - Number(data.maintenance),
      }];
      return [{ visitId: rowId, branchId: data.branchId, branchName: data.branchName,
        checkedInAtMillis: data.checkedInAtMillis, ...(action === 'branchVisits' ? { memberId: data.memberId } : {}) }];
    });
    return { records, ...(result.length > 30 ? { nextAfterId: result[29].id } : {}) };
  }

  if (action === 'saveInventory' || action === 'removeInventory') {
    const equipmentId = requiredIdentifier(input.equipmentId, 'equipmentId');
    const path = `${branch}/equipmentInventory/${equipmentId}`;
    return store.transact(async tx => {
      await authorize(tx);
      if (action === 'removeInventory') {
        if (await tx.get(path)) tx.set(path, { removed: true, updatedAtMillis: clock() });
        return { saved: true };
      }
      const equipment = await tx.get(`${root}/gymEquipment/${equipmentId}`);
      if (equipment?.isActive !== true || typeof equipment.name !== 'string') throw new DomainError('not-found', 'Equipment is unavailable.');
      const { quantity, maintenance } = input;
      if (!count(quantity) || !count(maintenance) || maintenance > quantity) {
        throw new DomainError('invalid-argument', 'Maintenance cannot exceed the total quantity.');
      }
      tx.set(path, { equipmentId, name: equipment.name, quantity, maintenance, updatedAtMillis: clock() });
      return { saved: true };
    });
  }

  if (action === 'issueVisitCode') {
    const token = randomBytes(24).toString('base64url');
    return store.transact(async tx => {
      await authorize(tx);
      const expiresAtMillis = clock() + visitWindow;
      tx.set(`${branch}/gymCheckIn/current`, { digest: keyOf(org, id, token), expiresAtMillis });
      return { qr: `gainpath-visit:${id}:${token}`, expiresAtMillis };
    });
  }

  const token = input.token;
  if (action !== 'checkIn' || typeof token !== 'string' || !/^[A-Za-z0-9_-]{32}$/.test(token)) {
    throw new DomainError('invalid-argument', 'Scan a valid GainPath visit code.');
  }
  return store.transact(async tx => {
    const data = await authorize(tx);
    const now = clock();
    await requireMembershipCapability(tx, auth, org, 'canAccessGym', now);
    const digest = keyOf(org, id, token);
    const visitId = keyOf(uid, digest);
    const memberVisits = `${root}/members/${uid}/gymVisits`;
    const prior = await tx.get(`${memberVisits}/${visitId}`);
    if (prior) return { visit: prior, duplicate: true };
    const code = await tx.get(`${branch}/gymCheckIn/current`);
    if (!code || code.digest !== digest || Number(code.expiresAtMillis) <= now) {
      throw new DomainError('failed-precondition', 'This visit code expired. Ask the branch for a new one.');
    }
    const latestPath = `${branch}/gymVisitLatest/${uid}`;
    const latest = await tx.get(latestPath);
    if (latest && Number(latest.checkedInAtMillis) + visitCooldown > now) {
      return { visit: latest, duplicate: true };
    }
    const visit = { visitId, memberId: uid, branchId: id, branchName: data!.displayName ?? id,
      checkedInAtMillis: now, source: 'branch_qr' };
    tx.create(`${memberVisits}/${visitId}`, visit);
    tx.create(`${branch}/gymVisits/${visitId}`, visit);
    tx.set(latestPath, visit);
    return { visit, duplicate: false };
  });
}
