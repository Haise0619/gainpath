import { DomainError } from '../../platform/errors';
import type { DocumentData, DocumentStore } from '../../platform/firestore/store';
import { requiredIdentifier } from '../../platform/validation';

export const INITIAL_ORGANIZATION_ID = 'gainpath';
export const INITIAL_BRANCH_ID = 'main';

export interface ProvisionMemberInput {
  readonly userId: string;
  readonly email: string;
  readonly displayName: string;
}

export interface ProvisionedMemberScope {
  readonly schemaVersion: 1;
  readonly organizationId: typeof INITIAL_ORGANIZATION_ID;
  readonly branchIds: readonly [typeof INITIAL_BRANCH_ID];
  readonly role: 'member';
  readonly status: 'active';
}

function validatedInput(input: ProvisionMemberInput): ProvisionMemberInput {
  const userId = requiredIdentifier(input.userId, 'userId');
  const email = input.email.trim().toLowerCase();
  const displayName = input.displayName.trim();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254) {
    throw new DomainError('invalid-argument', 'A valid email address is required.');
  }
  if (!displayName || displayName.length > 120) {
    throw new DomainError('invalid-argument', 'displayName must use 1-120 characters.');
  }
  return { userId, email, displayName };
}

function validExistingUser(data: DocumentData | undefined): boolean {
  return data?.organizationId === INITIAL_ORGANIZATION_ID
    && data.primaryBranchId === INITIAL_BRANCH_ID;
}

function validExistingMember(data: DocumentData | undefined): boolean {
  return data?.role === 'member'
    && data.status === 'active'
    && Array.isArray(data.branchIds)
    && data.branchIds.length === 1
    && data.branchIds[0] === INITIAL_BRANCH_ID;
}

export async function provisionMember(
  store: DocumentStore,
  rawInput: ProvisionMemberInput,
  clock: () => number = Date.now,
): Promise<ProvisionedMemberScope> {
  const input = validatedInput(rawInput);
  const organizationPath = `orgs/${INITIAL_ORGANIZATION_ID}`;
  const branchPath = `${organizationPath}/branches/${INITIAL_BRANCH_ID}`;
  const userPath = `users/${input.userId}`;
  const memberPath = `${organizationPath}/members/${input.userId}`;

  return store.transact(async transaction => {
    const organization = await transaction.get(organizationPath);
    const branch = await transaction.get(branchPath);
    const user = await transaction.get(userPath);
    const member = await transaction.get(memberPath);

    if (organization && organization.status !== 'active') {
      throw new DomainError('failed-precondition', 'The GainPath organization is not active.');
    }
    if (branch && branch.status !== 'active') {
      throw new DomainError('failed-precondition', 'The main branch is not active.');
    }
    if (user && !validExistingUser(user)) {
      throw new DomainError('failed-precondition', 'This account already has a different organization assignment.');
    }
    if (member && !validExistingMember(member)) {
      throw new DomainError('failed-precondition', 'This account already has a different membership assignment.');
    }

    const now = clock();
    if (!organization) {
      transaction.create(organizationPath, {
        schemaVersion: 1,
        organizationId: INITIAL_ORGANIZATION_ID,
        displayName: 'GainPath',
        status: 'active',
        createdAtMillis: now,
        updatedAtMillis: now,
      });
    }
    if (!branch) {
      transaction.create(branchPath, {
        schemaVersion: 1,
        branchId: INITIAL_BRANCH_ID,
        displayName: 'Main Branch',
        status: 'active',
        createdAtMillis: now,
        updatedAtMillis: now,
      });
    }
    if (!user) {
      transaction.create(userPath, {
        schemaVersion: 1,
        organizationId: INITIAL_ORGANIZATION_ID,
        primaryBranchId: INITIAL_BRANCH_ID,
        email: input.email,
        displayName: input.displayName,
        createdAtMillis: now,
        updatedAtMillis: now,
      });
    }
    if (!member) {
      transaction.create(memberPath, {
        schemaVersion: 1,
        userId: input.userId,
        organizationId: INITIAL_ORGANIZATION_ID,
        email: input.email,
        displayName: input.displayName,
        role: 'member',
        status: 'active',
        branchIds: [INITIAL_BRANCH_ID],
        createdAtMillis: now,
        updatedAtMillis: now,
      });
    }

    return {
      schemaVersion: 1,
      organizationId: INITIAL_ORGANIZATION_ID,
      branchIds: [INITIAL_BRANCH_ID],
      role: 'member',
      status: 'active',
    };
  });
}
