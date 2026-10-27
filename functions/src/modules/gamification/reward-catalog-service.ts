import {createHash} from 'node:crypto';
import {requireVerifiedEmail} from '../../platform/auth-context';
import {DomainError} from '../../platform/errors';
import {InputValidationError, requiredIdentifier} from '../../platform/validation';
import {readAll, type DocumentData, type DocumentStore} from '../../platform/firestore/store';
import {authorizeRewardsAdmin, parseRewardPolicy} from './verified-rewards-service';
import {rewardItemDetails} from './reward-details';
import {pointsRewardCatalogCommand} from './points-reward-catalog';
type Auth = {uid: string; token: Record<string, unknown>} | undefined;
const integer = (v: unknown, min = 0): v is number => Number.isSafeInteger(v) && Number(v) >= min;
const id = (v: unknown): v is string => typeof v === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(v);
const hash = (v: unknown) => createHash('sha256').update(JSON.stringify(v)).digest('hex');
const fail = (message = 'Reward shop configuration needs authorized review.') => new DomainError('failed-precondition', message);
function configured(raw: DocumentData | undefined, org: string) {
  if (!raw) return null;
  if (typeof raw.enabled !== 'boolean') throw fail();
  const p = parseRewardPolicy({...raw, enabled: true}, org, Number(raw.effectiveFromMillis));
  if (!p) throw fail(); return p;
}
function catalogIds(raw: DocumentData | undefined, p: ReturnType<typeof configured>) {
  const ids = raw?.catalogItemIds ?? p?.itemIds ?? [];
  if (!Array.isArray(ids) || ids.length > 100 || ids.some(v => !id(v)) || new Set(ids).size !== ids.length || p?.itemIds.some(i => !ids.includes(i))) throw fail();
  return ids as string[];
}
function published(d: DocumentData | undefined, org: string, itemId: string) {
  if (!d || d.schemaVersion !== 1 || d.organizationId !== org || d.itemId !== itemId || typeof d.title !== 'string' || !d.title.trim() || d.title.length > 120 ||
      !integer(d.stock) || !integer(d.pointCost, 1) || !integer(d.valueMinor, 1) || !integer(d.revision, 1) || typeof d.active !== 'boolean') throw fail();
  const details = rewardItemDetails(d); if (!details) throw fail('Legacy reward stock needs reviewed publication before editing.');
  return {itemId, title: d.title, category: typeof d.category === 'string' ? d.category : 'Merchandise', pointCost: d.pointCost, valueMinor: d.valueMinor, stock: d.stock, revision: d.revision, active: d.active, ...details};
}
export async function rewardCatalogCommand(store: DocumentStore, auth: Auth, raw: unknown, clock: () => number = Date.now): Promise<{schemaVersion:number;organizationId:string;confirmed?:boolean;items?:DocumentData[];policy?:DocumentData|null}> {
  if (raw && typeof raw === 'object' && ['pointsOverview','savePoints','retirePoints'].includes(String((raw as DocumentData).action))) {
    return pointsRewardCatalogCommand(store,auth,raw,clock);
  }
  requireVerifiedEmail(auth);
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) throw new InputValidationError('Reward command required.');
  const d = raw as DocumentData, actions: Record<string, string[]> = {overview: [], configure: ['requestId', 'pointsPerUnit', 'unitValueMinor', 'enabled'],
    publish: ['requestId', 'itemId', 'draftRevision', 'baseItemRevision', 'pointCost', 'valueMinor', 'stockToAdd', 'validityDays', 'conditions', 'collectionInstructions'],
    save: ['requestId', 'itemId', 'baseItemRevision', 'title', 'description', 'category', 'imageUrl', 'pointCost', 'valueMinor', 'stockToAdd', 'validityDays', 'conditions', 'collectionInstructions'],
    retire: ['requestId', 'itemId', 'baseItemRevision']};
  if (d.schemaVersion !== 1 || typeof d.action !== 'string' || !Object.hasOwn(actions, d.action)) throw new InputValidationError('Invalid reward action.');
  const action = d.action, fields = ['schemaVersion', 'organizationId', 'action', ...actions[action]];
  if (Object.keys(d).length !== fields.length || Object.keys(d).some(k => !fields.includes(k))) throw new InputValidationError('Invalid reward command fields.');
  const org = requiredIdentifier(d.organizationId, 'organizationId'), uid = requiredIdentifier(auth!.uid, 'uid');
  if (action !== 'overview') requiredIdentifier(d.requestId, 'requestId');
  if (['publish', 'save', 'retire'].includes(action)) {requiredIdentifier(d.itemId, 'itemId'); if (!integer(d.baseItemRevision)) throw new InputValidationError('Invalid reward revision.');}
  if (action === 'configure' && (!integer(d.pointsPerUnit, 1) || !integer(d.unitValueMinor, 1) || typeof d.enabled !== 'boolean')) throw new InputValidationError('Enter an explicit positive point conversion.');
  if (['publish', 'save'].includes(action) && ((action === 'publish' && !integer(d.draftRevision, 1)) || !integer(d.pointCost, 1) || !integer(d.valueMinor, 1) || !integer(d.stockToAdd) || !integer(d.validityDays, 1) || Number(d.validityDays) > 365 ||
      typeof d.conditions !== 'string' || typeof d.collectionInstructions !== 'string')) throw new InputValidationError('Enter reward cost, stock, validity and conditions.');
  if (action === 'save' && (typeof d.title !== 'string' || !d.title.trim() || d.title.trim().length > 120 ||
      typeof d.description !== 'string' || typeof d.imageUrl !== 'string' || !['Merchandise', 'Food & Drink', 'Apparel', 'Access Pass'].includes(String(d.category)))) throw new InputValidationError('Enter valid reward information.');
  const operationId = hash([uid, d.requestId]), fingerprint = hash(Object.keys(d).sort().map(k => [k, d[k]]));
  return store.transact(async tx => {
    const now = clock(); if (!integer(now, 1) || now > 8640000000000000) throw fail();
    await authorizeRewardsAdmin(tx, auth!, org);
    const opPath = `orgs/${org}/rewardCatalogOperations/${operationId}`;
    if (action !== 'overview') {
      const prior = await tx.get(opPath);
      if (prior) {
        if (prior.schemaVersion !== 1 || prior.organizationId !== org || prior.adminId !== uid || prior.requestId !== d.requestId || prior.action !== action || prior.fingerprint !== fingerprint) throw new DomainError('already-exists', 'This request was used for another reward operation.');
        return {schemaVersion: 1, organizationId: org, confirmed: true};
      }
    }
    if(action!=='overview'&&(await tx.get(`orgs/${org}/rewardShops/current`))!==undefined) {
      throw fail('Points-only reward management is active. Refresh the Admin page before editing rewards.');
    }
    const policyPath = `orgs/${org}/rewardPolicies/current`, rawPolicy = await tx.get(policyPath), p = configured(rawPolicy, org), ids = catalogIds(rawPolicy, p);
    if (action === 'overview') {
      const items = await readAll(tx, ids.map(i => `orgs/${org}/rewardItems/${i}`));
      return {schemaVersion: 1, organizationId: org, policy: p ? {version: p.version, pointsPerUnit: p.exchangeRate.pointsPerUnit, unitValueMinor: p.exchangeRate.unitValueMinor, enabled: rawPolicy!.enabled} : null,
        items: items.map((item, i) => published(item, org, ids[i]))};
    }
    if (action === 'configure') {
      if (p?.sources.length) throw fail('Existing earning rules require separate review; this setup only controls redemption.');
      const changed = !p || p.exchangeRate.pointsPerUnit !== d.pointsPerUnit || p.exchangeRate.unitValueMinor !== d.unitValueMinor;
      if (changed && p?.itemIds.length) throw fail('Retire active rewards before changing point conversion.');
      const version = 'reward-shop-' + operationId;
      tx.set(policyPath, {schemaVersion: 1, organizationId: org, version, enabled: d.enabled, effectiveFromMillis: now, effectiveUntilMillis: 8640000000000000,
        timezone: 'Asia/Kuala_Lumpur', unknownHistoricalTier: 'base_only', sources: [], itemIds: p?.itemIds ?? [], catalogItemIds: ids,
        exchangeRate: {version: changed ? version : p!.exchangeRate.version, currency: 'MYR', pointsPerUnit: d.pointsPerUnit, unitValueMinor: d.unitValueMinor}, updatedBy: uid, updatedAtMillis: now});
    } else {
      if (!p) throw fail('Configure the reward shop before publishing.');
      const itemId = String(d.itemId), itemPath = `orgs/${org}/rewardItems/${itemId}`, existing = await tx.get(itemPath);
      if ((existing?.revision ?? 0) !== d.baseItemRevision || (existing && (existing.organizationId !== org || existing.itemId !== itemId))) throw new DomainError('aborted', 'Reward changed. Reload before publishing.');
      if (action === 'retire') {
        if (!existing) throw fail('Reward is unavailable.');
        published(existing, org, itemId);
        tx.set(itemPath, {...existing, active: false, revision: Number(existing.revision) + 1, updatedBy: uid, updatedAtMillis: now});
        tx.set(policyPath, {...rawPolicy, itemIds: p.itemIds.filter(i => i !== itemId), updatedBy: uid, updatedAtMillis: now});
      } else {
        const draft = action === 'save' ? {schemaVersion: 1, status: 'draft', revision: 0, title: d.title, description: d.description, imageUrl: d.imageUrl, category: d.category} : await tx.get(`orgs/${org}/rewardCatalog/${itemId}`);
        if (!draft || draft.schemaVersion !== 1 || draft.status !== 'draft' || (action === 'publish' && draft.revision !== d.draftRevision) || typeof draft.title !== 'string' || !draft.title.trim() || draft.title.trim().length > 120 ||
            typeof draft.description !== 'string' || typeof draft.imageUrl !== 'string') throw new DomainError('aborted', 'Saved reward draft changed. Save and reload before publishing.');
        if (!Number.isSafeInteger(Number(d.valueMinor) * p.exchangeRate.pointsPerUnit) || !Number.isSafeInteger(Number(d.pointCost) * p.exchangeRate.unitValueMinor) ||
            Number(d.valueMinor) * p.exchangeRate.pointsPerUnit !== Number(d.pointCost) * p.exchangeRate.unitValueMinor) throw fail('Reward value and point cost must follow the configured conversion.');
        const details = rewardItemDetails({rewardDetailsVersion: 1, description: draft.description, imageUrl: draft.imageUrl, validityDays: d.validityDays, conditions: d.conditions, collectionInstructions: d.collectionInstructions})!;
        if (existing) published(existing, org, itemId);
        const stock = Number(existing?.stock ?? 0) + Number(d.stockToAdd);
        if (!integer(stock)) throw fail('Reward stock is outside supported limits.');
        if (!ids.includes(itemId) && ids.length >= 100) throw fail('Reward catalog limit reached. Retain existing stock for review.');
        tx.set(itemPath, {schemaVersion: 1, organizationId: org, itemId, title: draft.title.trim(), category: draft.category ?? 'Merchandise', active: true, pointCost: d.pointCost, valueMinor: d.valueMinor, stock,
          premiumOnly: false, exchangeRateVersion: p.exchangeRate.version, revision: Number(d.baseItemRevision) + 1,
          ...(action === 'publish' ? {draftRevision: d.draftRevision} : {}),
          ...details, updatedBy: uid, updatedAtMillis: now});
        tx.set(policyPath, {...rawPolicy, itemIds: [...new Set([...p.itemIds, itemId])], catalogItemIds: [...new Set([...ids, itemId])], updatedBy: uid, updatedAtMillis: now});
      }
    }
    tx.create(opPath, {schemaVersion: 1, organizationId: org, adminId: uid, requestId: d.requestId, action, fingerprint, confirmedAtMillis: now});
    return {schemaVersion: 1, organizationId: org, confirmed: true};
  });
}
