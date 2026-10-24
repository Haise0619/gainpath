import { expect, it } from 'vitest';
import { memberBookingChangeCommand } from '../src/modules/coaching/member-booking-change-callable';

it('actual callable rejects missing App Check, authentication and unverified email before database access', async () => {
  await expect(memberBookingChangeCommand.run({ data: {} } as any)).rejects.toMatchObject({ code: 'unauthenticated' });
  await expect(memberBookingChangeCommand.run({ app: { appId: 'fixture' }, data: {} } as any)).rejects.toMatchObject({ code: 'unauthenticated' });
  await expect(memberBookingChangeCommand.run({ app: { appId: 'fixture' }, auth: { uid: 'member', token: { email_verified: false } }, data: {} } as any)).rejects.toMatchObject({ code: 'permission-denied' });
});
