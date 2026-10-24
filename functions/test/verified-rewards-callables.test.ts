import { expect, it } from 'vitest';
import { verifiedRewardsCommand } from '../src/modules/gamification/verified-rewards-callables';

it('rejects missing App Check, missing Auth and unverified Auth before database access', async () => {
  await expect(verifiedRewardsCommand.run({ data: {} } as any)).rejects.toMatchObject({ code: 'unauthenticated' });
  await expect(verifiedRewardsCommand.run({ app: { appId: 'synthetic' }, data: {} } as any)).rejects.toMatchObject({ code: 'unauthenticated' });
  await expect(verifiedRewardsCommand.run({ app: { appId: 'synthetic' }, auth: { uid: 'member', token: { email_verified: false } }, data: {} } as any))
    .rejects.toMatchObject({ code: 'permission-denied' });
});
