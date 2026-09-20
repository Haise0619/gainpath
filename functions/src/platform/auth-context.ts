import { DomainError } from './errors';
import type { DocumentData } from './firestore/store';

export interface ActiveMembership {
  readonly role: string;
  readonly branchIds: readonly string[];
  readonly status: string;
}
export function requireActiveMembership(data: DocumentData | undefined): ActiveMembership {
  if (data?.status !== 'active' || !['member', 'coach', 'staff', 'admin'].includes(String(data.role))
    || !Array.isArray(data.branchIds) || !data.branchIds.every(id => typeof id === 'string')) {
    throw new DomainError('permission-denied', 'An active organization membership is required.');
  }
  return { role: String(data.role), status: 'active', branchIds: data.branchIds };
}
export function requireBranchAccess(membership: ActiveMembership, branchId: string): void {
  if (membership.role !== 'admin' && !membership.branchIds.includes(branchId)) {
    throw new DomainError('permission-denied', 'The account cannot access this branch.');
  }
}
