import { requireVerifiedEmail } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import type { DocumentData, DocumentStore } from '../../platform/firestore/store';
import { requiredIdentifier } from '../../platform/validation';
import { currentBookingMembership, requireBookingOrganization } from '../coaching/booking-validation';

type Actor = { uid: string; token: Record<string, unknown> } | undefined;
type BranchRow = { id: string; data: DocumentData };
export type BranchList = (org: string, activeOnly: boolean, afterId?: string) => Promise<BranchRow[]>;
const textFields = ['description', 'address', 'city', 'state', 'postalCode', 'country', 'contactPhone', 'contactEmail', 'coverUrl'] as const;
const time = /^([01]\d|2[0-3]):[0-5]\d$/;

function object(value: unknown): DocumentData {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new DomainError('invalid-argument', 'Branch details are required.');
  }
  return value as DocumentData;
}

function fields(raw: unknown): DocumentData {
  const input = object(raw);
  const displayName = typeof input.displayName === 'string' ? input.displayName.trim() : '';
  if (!displayName || displayName.length > 120 || !['active', 'inactive'].includes(String(input.status))) {
    throw new DomainError('invalid-argument', 'Enter a branch name and status.');
  }
  const result: DocumentData = { displayName, status: input.status, timeZone: 'Asia/Kuala_Lumpur' };
  for (const field of textFields) {
    if (input[field] === undefined) continue;
    const value = input[field];
    if (typeof value !== 'string' || value.length > (field === 'coverUrl' ? 2048 : 1000)
      || (field === 'coverUrl' && value && !/^https:\/\/firebasestorage\.googleapis\.com\//.test(value))) {
      throw new DomainError('invalid-argument', 'Invalid branch field.');
    }
    result[field] = value.trim();
  }
  if ('latitude' in input || 'longitude' in input) {
    const { latitude, longitude } = input;
    if (latitude === null && longitude === null) Object.assign(result, { latitude, longitude });
    else if (typeof latitude !== 'number' || typeof longitude !== 'number'
      || !Number.isFinite(latitude) || !Number.isFinite(longitude) || Math.abs(latitude) > 90 || Math.abs(longitude) > 180) {
      throw new DomainError('invalid-argument', 'Enter valid latitude and longitude.');
    } else Object.assign(result, { latitude, longitude });
  }
  if (input.facilities !== undefined) {
    if (!Array.isArray(input.facilities) || input.facilities.length > 30
      || !input.facilities.every(value => typeof value === 'string' && value.trim().length > 0 && value.length <= 80)) {
      throw new DomainError('invalid-argument', 'Invalid facilities list.');
    }
    result.facilities = [...new Set(input.facilities.map(value => value.trim()))];
  }
  if (input.openingHours !== undefined) {
    if (!Array.isArray(input.openingHours) || input.openingHours.length !== 7) {
      throw new DomainError('invalid-argument', 'Set opening hours for all seven days.');
    }
    result.openingHours = input.openingHours.map(value => {
      const day = object(value);
      if (day.closed === true) return { closed: true };
      if (day.allDay === true) return { allDay: true };
      if (typeof day.open !== 'string' || typeof day.close !== 'string'
        || !time.test(day.open) || !time.test(day.close) || day.open === day.close) {
        throw new DomainError('invalid-argument', 'Use HH:mm times or select Closed / 24 hours.');
      }
      return { open: day.open, close: day.close };
    });
  }
  return result;
}

function view(id: string, data: DocumentData) {
  return { branchId: id, ...Object.fromEntries(
    ['displayName', 'status', 'latitude', 'longitude', 'facilities', 'openingHours', 'timeZone', ...textFields]
      .filter(key => data[key] !== undefined).map(key => [key, data[key]])),
  };
}

export async function branchManagement(store: DocumentStore, list: BranchList, auth: Actor, raw: unknown, clock = Date.now) {
  requireVerifiedEmail(auth);
  const input = object(raw);
  const org = requiredIdentifier(input.organizationId, 'organizationId');
  const uid = auth!.uid;
  const root = `orgs/${org}`;
  const action = input.action;
  if (action !== 'list' && action !== 'save' && action !== 'setHome' && action !== 'setSelected') {
    throw new DomainError('invalid-argument', 'Unsupported branch action.');
  }
  const scope = async () => store.transact(async tx => {
    await requireBookingOrganization(tx, org);
    return currentBookingMembership(tx, org, uid);
  });
  if (action === 'list') {
    const actor = await scope();
    const activeOnly = actor.role !== 'admin';
    const afterId = input.afterId == null ? undefined : requiredIdentifier(input.afterId, 'afterId');
    const rows = await list(org, activeOnly, afterId);
    const current = await scope();
    if (!activeOnly && current.role !== 'admin') throw new DomainError('permission-denied', 'Admin access is required.');
    const user = await store.transact(tx => tx.get(`users/${uid}`));
    const homeBranchId = user?.organizationId === org ? (user.homeBranchId ?? user.primaryBranchId ?? current.branchIds[0]) : undefined;
    const selected = user?.selectedBranchId;
    const selection = typeof selected === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(selected)
      ? await store.transact(tx => tx.get(`${root}/branches/${selected}`)) : undefined;
    return { records: rows.slice(0, 25).map(row => view(row.id, row.data)),
      ...(selection?.status === 'active' ? { selectedBranchId: selected } : {}),
      ...(typeof homeBranchId === 'string' ? { homeBranchId } : {}),
      ...(rows.length > 25 ? { nextAfterId: rows[24].id } : {}) };
  }
  const id = requiredIdentifier(input.branchId, 'branchId');
  const path = `${root}/branches/${id}`;
  return store.transact(async tx => {
    await requireBookingOrganization(tx, org);
    const actor = await currentBookingMembership(tx, org, uid);
    const old = await tx.get(path);
    if (action === 'setHome' || action === 'setSelected') {
      if (actor.role !== 'member' || old?.status !== 'active') {
        throw new DomainError('permission-denied', 'Select an active home branch.');
      }
      const user = await tx.get(`users/${uid}`);
      const field = action === 'setHome' ? 'homeBranchId' : 'selectedBranchId';
      tx.set(`users/${uid}`, { ...user, [field]: id, updatedAtMillis: clock() });
      return { [field]: id };
    }
    if (actor.role !== 'admin') throw new DomainError('permission-denied', 'Admin access is required.');
    if (input.create === true && old) throw new DomainError('already-exists', 'This branch ID already exists.');
    if (input.create !== true && !old) throw new DomainError('not-found', 'Branch not found.');
    const now = clock();
    const data = { ...old, schemaVersion: old?.schemaVersion ?? 1, branchId: id, ...fields(input.branch),
      createdAtMillis: old?.createdAtMillis ?? now, updatedAtMillis: now };
    tx.set(path, data);
    return { branch: view(id, data) };
  });
}
