import type {DocumentData} from '../../platform/firestore/store';
import {DomainError} from '../../platform/errors';
import {rewardItemDetails} from './reward-details';
const fail = () => new DomainError('failed-precondition','Reward catalog is unavailable.');
const id = (v: unknown): v is string => typeof v === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(v);
const integer = (v: unknown, min = 0): v is number => Number.isSafeInteger(v) && Number(v) >= min;
export const POINTS_SHOP_VERSION = 'points-only-v1';
export type PointsRewardShop = {schemaVersion:1;organizationId:string;version:string;itemIds:string[];catalogItemIds:string[]};
export function rewardCatalogIds(raw: unknown): string[] {
  if (!Array.isArray(raw) || raw.length > 100 || raw.some(v=>!id(v)) || new Set(raw).size !== raw.length) throw fail();
  return raw;
}
export function parsePointsRewardShop(raw: DocumentData | undefined, org: string): PointsRewardShop | null {
  if (raw === undefined) return null;
  if (!raw || raw.schemaVersion !== 1 || raw.organizationId !== org || raw.version !== POINTS_SHOP_VERSION) throw fail();
  const itemIds=rewardCatalogIds(raw.itemIds),catalogItemIds=rewardCatalogIds(raw.catalogItemIds);
  if (itemIds.some(i=>!catalogItemIds.includes(i))) throw fail();
  return {schemaVersion:1,organizationId:org,version:POINTS_SHOP_VERSION,itemIds,catalogItemIds};
}
export function pointsRewardItem(raw: DocumentData | undefined, itemId: string, org: string) {
  if (!raw || raw.schemaVersion !== 1 || raw.organizationId !== org || raw.itemId !== itemId ||
      typeof raw.title !== 'string' || !raw.title.trim() || raw.title.length > 120 || !integer(raw.pointCost,1) || !integer(raw.stock) ||
      typeof raw.active !== 'boolean' || typeof raw.premiumOnly !== 'boolean' ||
      (raw.pricingMode !== undefined && raw.pricingMode !== 'points_only')) throw fail();
  const details=rewardItemDetails(raw);
  if (details && !integer(raw.revision,1)) throw fail();
  return {itemId,title:raw.title,pointCost:raw.pointCost,stock:raw.stock,premiumOnly:raw.premiumOnly,
    ...(details ? {...details,revision:raw.revision} : {})};
}
