import {expect,it} from 'vitest';
import {membershipCapabilities} from '../src/modules/commerce/membership-capabilities';
it.each(['free','basic','premium',null])('keeps digital fitness available for %s', tier => {
  const c=membershipCapabilities({status:tier?'resolved':'unknown',effectiveTier:tier});
  expect(c.canUseDigitalFitness).toBe(true);
  expect(c.canBookCoach).toBe(tier==='basic'||tier==='premium');
  expect(c.canAccessMiniGames).toBe(c.canBookCoach);
  expect(c.canRedeemPremiumRewards).toBe(tier==='premium');
});
it('unknown and historical tier hints never authorize paid actions',()=>{
 expect(membershipCapabilities({status:'unknown',effectiveTier:'premium'}).canAccessGym).toBe(false);
 expect(membershipCapabilities({status:'resolved',effectiveTier:'premium',historicalOnly:true}).canAccessGym).toBe(false);
});
