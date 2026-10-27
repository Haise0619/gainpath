import {beforeEach, expect, it} from 'vitest';
import {rewardCatalogCommand} from '../src/modules/gamification/reward-catalog-service';
import {rewardsCommand} from '../src/modules/gamification/verified-rewards-service';
import {seed, org, now, adminAuth, auth, identity, path} from './reward-journey-fixture';
let store: ReturnType<typeof seed>;
const admin = (action: string, fields = {}) => rewardCatalogCommand(store, adminAuth, {schemaVersion:1, organizationId:org, action, ...fields}, () => now);
const member = (action: string, fields = {}) => rewardsCommand(store, auth, {schemaVersion:1, organizationId:org, action, ...fields}, identity, () => now);
const input = {requestId:'create',itemId:'bottle',baseItemRevision:0,title:'Training bottle',description:'Reusable bottle',category:'Merchandise',imageUrl:'',pointCost:137,stockToAdd:5,validityDays:10,conditions:'Collect in person',collectionInstructions:'Reception'};
beforeEach(() => {store=seed();});
it('creates and lists points-only rewards without a policy, conversion or draft', async () => {
  await admin('savePoints',input);
  const item=store.documents.get(path('rewardItems','bottle'))!;
  expect(item).toMatchObject({pricingMode:'points_only',pointCost:137,stock:5,revision:1});
  expect(item).not.toHaveProperty('valueMinor');expect(item).not.toHaveProperty('exchangeRateVersion');
  expect(store.documents.has(path('rewardPolicies','current'))).toBe(false);
  expect(store.documents.has(path('rewardCatalog','bottle'))).toBe(false);
  const overview=await admin('pointsOverview');expect(overview).not.toHaveProperty('policy');
  expect(overview.items).toEqual([expect.objectContaining({itemId:'bottle',pointCost:137})]);
});
it('Member redeems for its direct points cost once and gets a compatible voucher', async () => {
  await admin('savePoints',input);
  expect(await member('overview')).toMatchObject({available:true,canRedeem:true,items:[{itemId:'bottle',pointCost:137}]});
  const request={itemId:'bottle',requestId:'redeem',expectedPointCost:137,expectedItemRevision:1};
  const result=await member('redeem',request);expect(await member('redeem',request)).toEqual(result);
  expect(store.documents.get(path('rewardBalances','member'))?.points).toBe(863);
  expect(store.documents.get(path('rewardItems','bottle'))?.stock).toBe(4);
  expect(result.redemption).toMatchObject({points:137,exchangeRateVersion:'points-only-v1',expiredPointsPolicy:'remain_spent'});
});
it('legacy conversion and earning configuration stay unchanged; old items remain visible after first points save', async () => {
  await admin('configure',{requestId:'legacy',pointsPerUnit:500,unitValueMinor:50,enabled:true});
  await admin('publish',{requestId:'publish',itemId:'item',draftRevision:1,baseItemRevision:0,pointCost:500,valueMinor:50,stockToAdd:10,validityDays:10,conditions:'Terms',collectionInstructions:'Desk'});
  const policy=structuredClone(store.documents.get(path('rewardPolicies','current')));
  await admin('savePoints',input);
  expect(store.documents.get(path('rewardPolicies','current'))).toEqual(policy);
  const overview=await member('overview');expect(overview.available).toBe(true);expect(overview.items).toHaveLength(2);
  const reward=await member('redeem',{itemId:'item',requestId:'old-item',expectedPointCost:500,expectedItemRevision:1});
  expect(reward.redemption.points).toBe(500);
});
it('idempotent editing preserves current stock, rejects stale terms and direct monetary fields', async () => {
  await Promise.all([admin('savePoints',input),admin('savePoints',input)]);
  store.documents.set(path('rewardItems','bottle'),{...store.documents.get(path('rewardItems','bottle')),stock:3});
  const edit={...input,requestId:'edit',baseItemRevision:1,pointCost:211,stockToAdd:2};
  await admin('savePoints',edit);await admin('savePoints',edit);
  expect(store.documents.get(path('rewardItems','bottle'))).toMatchObject({stock:5,revision:2,pointCost:211});
  await expect(admin('savePoints',{...edit,requestId:'stale'})).rejects.toMatchObject({code:'aborted'});
  await expect(member('redeem',{itemId:'bottle',requestId:'stale-price',expectedPointCost:137,expectedItemRevision:1})).rejects.toMatchObject({code:'aborted'});
  await expect(admin('savePoints',{...input,requestId:'money',valueMinor:20})).rejects.toThrow();
});
it('removal blocks new redemption but keeps confirmed voucher retry/inspection and spent points', async () => {
  await admin('savePoints',input);
  const request={itemId:'bottle',requestId:'issued',expectedPointCost:137,expectedItemRevision:1};
  const issued=await member('redeem',request);
  await admin('retirePoints',{requestId:'remove',itemId:'bottle',baseItemRevision:1});
  expect(await member('redeem',request)).toEqual(issued);
  await expect(member('redeem',{...request,requestId:'another'})).rejects.toThrow();
  expect((await member('voucher',{redemptionId:issued.redemption.redemptionId})).redemption).toMatchObject({status:'issued',points:137});
});
it('invalid input and unauthorized Admin cannot create partial shop or item writes', async () => {
  const before=JSON.stringify([...store.documents]);
  await expect(admin('savePoints',{...input,pointCost:0})).rejects.toThrow();
  await expect(admin('savePoints',{...input,conditions:''})).rejects.toThrow();
  await expect(rewardCatalogCommand(store,auth,{schemaVersion:1,organizationId:org,action:'savePoints',...input},()=>now)).rejects.toMatchObject({code:'permission-denied'});
  expect(JSON.stringify([...store.documents])).toBe(before);
});
it('creating a points shop does not enable held earning sources', async () => {
  await admin('savePoints',input);
  await expect(member('award',{eventId:'invented'})).rejects.toThrow();
  expect(store.documents.get(path('rewardBalances','member'))?.points).toBe(1000);
});
it('a confirmed redemption recovers even if the later catalog index is invalid', async () => {
  await admin('savePoints',input);
  const request={itemId:'bottle',requestId:'recover',expectedPointCost:137,expectedItemRevision:1};
  const issued=await member('redeem',request);
  store.documents.set(path('rewardShops','current'),{schemaVersion:999});
  expect(await member('redeem',request)).toEqual(issued);
  expect(store.documents.get(path('rewardBalances','member'))?.points).toBe(863);
});
it('old Admin tabs cannot change legacy indexes after points-only activation, but confirmed legacy retries recover', async () => {
  const setup={requestId:'legacy-setup',pointsPerUnit:500,unitValueMinor:50,enabled:true};
  const confirmed=await admin('configure',setup);
  await admin('savePoints',input);
  expect(await admin('configure',setup)).toEqual(confirmed);
  await expect(admin('configure',{...setup,requestId:'stale-tab'})).rejects.toMatchObject({code:'failed-precondition'});
});
