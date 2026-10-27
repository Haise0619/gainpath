import {getAuth} from 'firebase-admin/auth';
import {defineString} from 'firebase-functions/params';
import {DomainError} from '../../platform/errors';
import {requireVerifiedEmail} from '../../platform/auth-context';
export const rewardsOrganization = defineString('VERIFIED_REWARDS_ORGANIZATION_ID', {default: ''});
export type RewardAuth = {uid: string; token: Record<string, unknown>};
export async function freshRewardAuth(auth: RewardAuth) {
  if (typeof auth.token.email !== 'string' || !Number.isSafeInteger(auth.token.auth_time)) throw new DomainError('unauthenticated', 'Sign in again with a verified account.');
  const user = await getAuth().getUser(auth.uid), validAfter = user.tokensValidAfterTime ? Date.parse(user.tokensValidAfterTime) : 0;
  if (user.disabled || !user.emailVerified || user.email !== auth.token.email || !Number.isFinite(validAfter) || Number(auth.token.auth_time) * 1000 < validAfter) throw new DomainError('unauthenticated', 'Your account session changed.');
}
export async function rewardRequest(request: {app?: unknown; auth?: RewardAuth; data: unknown}) {
  if (!request.app) throw new DomainError('unauthenticated', 'App verification required.');
  requireVerifiedEmail(request.auth);
  const org = rewardsOrganization.value();
  if (!org || (request.data as Record<string, unknown> | null)?.organizationId !== org) throw new DomainError('permission-denied', 'Rewards organization unavailable.');
  await freshRewardAuth(request.auth!); return request.auth!;
}
