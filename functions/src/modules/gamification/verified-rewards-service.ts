import { createHash } from 'node:crypto';
import { requireVerifiedEmail, requireActiveMembership } from '../../platform/auth-context';
import { DomainError } from '../../platform/errors';
import { requiredIdentifier, InputValidationError } from '../../platform/validation';
import { readAll, type DocumentData, type DocumentStore, type TransactionPort } from '../../platform/firestore/store';
import type { CoachIdentityReader } from '../coaching/coach-profile-service';
import { resolveMembershipEntitlement } from '../commerce/membership-entitlement';
import {rewardItemDetails, rewardVoucherDetails} from './reward-details';
import {parsePointsRewardShop,pointsRewardItem,POINTS_SHOP_VERSION} from './points-reward-shop';
type Auth = { uid: string; token: Record<string, unknown> } | undefined;
const DAY = 86400000;
const integer = (v: unknown, min = 0): v is number => Number.isSafeInteger(v) && Number(v) >= min;
const time = (v: unknown): v is number => integer(v, 1) && v <= 8640000000000000;
const id = (v: unknown): v is string => typeof v === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(v);
const text = (v: unknown): v is string => typeof v === 'string' && v.trim().length > 0 && v.length <= 200;
const fail = () => new DomainError('failed-precondition', 'Verified rewards configuration or evidence is unavailable.');
const deny = () => new DomainError('permission-denied', 'Current verified organization authority is required.');
const digest = (...v: string[]) => createHash('sha256').update(JSON.stringify(v)).digest('hex');
type Source = { sourceId: string; producerVersion: string; basePoints: number; maxEventAgeMillis: number; dailyEvents: number; dailyAwardPoints: number };
type Policy = { version: string; timezone: string; effectiveFromMillis: number; effectiveUntilMillis: number; itemIds: string[]; sources: Source[];
  exchangeRate: { version: string; currency: 'MYR'; pointsPerUnit: number; unitValueMinor: number } };

function policy(d: DocumentData | undefined, org: string, now: number): Policy | null {
  if (!d || d.schemaVersion !== 1 || d.organizationId !== org || d.enabled !== true || !id(d.version)
      || !time(d.effectiveFromMillis) || !time(d.effectiveUntilMillis) || d.effectiveFromMillis >= d.effectiveUntilMillis
      || now < d.effectiveFromMillis || now >= d.effectiveUntilMillis || d.unknownHistoricalTier !== 'base_only'
      || typeof d.timezone !== 'string' || !Array.isArray(d.itemIds) || d.itemIds.length > 100
      || !d.itemIds.every(id) || new Set(d.itemIds).size !== d.itemIds.length
      || !Array.isArray(d.sources) || d.sources.length > 50) return null;
  try { new Intl.DateTimeFormat('en', { timeZone: d.timezone }).format(now); } catch { return null; }
  const rate = d.exchangeRate as DocumentData | undefined;
  if (!rate || !id(rate.version) || rate.currency !== 'MYR' || !integer(rate.pointsPerUnit, 1) || !integer(rate.unitValueMinor, 1)) return null;
  if (!d.sources.every(s => s && id(s.sourceId) && id(s.producerVersion) && integer(s.basePoints, 1)
      && s.basePoints <= Math.floor(Number.MAX_SAFE_INTEGER / 3) && integer(s.maxEventAgeMillis, 1)
      && integer(s.dailyEvents, 1) && integer(s.dailyAwardPoints, 1))
      || new Set(d.sources.map(s => s.sourceId)).size !== d.sources.length) return null;
  return d as unknown as Policy;
}
function balance(d: DocumentData | undefined, org: string, uid: string) {
  if (!d) return { points: null, recentRedemptionIds: [] as string[] };
  if (d.schemaVersion !== 1 || d.organizationId !== org || d.memberId !== uid || !integer(d.points)
      || !Array.isArray(d.recentRedemptionIds) || d.recentRedemptionIds.length > 50 || !d.recentRedemptionIds.every(id)) throw fail();
  return { points: d.points, recentRedemptionIds: d.recentRedemptionIds as string[] };
}
function item(d: DocumentData | undefined, itemId: string, org: string, p: Policy) {
  if (!d || d.schemaVersion !== 1 || d.organizationId !== org || d.itemId !== itemId || d.active !== true || !p.itemIds.includes(itemId)
      || !text(d.title) || !integer(d.pointCost, 1) || !integer(d.stock) || !integer(d.valueMinor, 1)
      || typeof d.premiumOnly !== 'boolean' || d.exchangeRateVersion !== p.exchangeRate.version
      || !Number.isSafeInteger(d.valueMinor * p.exchangeRate.pointsPerUnit)
      || !Number.isSafeInteger(d.pointCost * p.exchangeRate.unitValueMinor)
      || d.valueMinor * p.exchangeRate.pointsPerUnit !== d.pointCost * p.exchangeRate.unitValueMinor) throw fail();
  const details = rewardItemDetails(d);
  if (details && !integer(d.revision, 1)) throw fail();
  return { itemId, title: d.title, pointCost: d.pointCost, stock: d.stock, premiumOnly: d.premiumOnly, ...(details ? {...details, revision: d.revision} : {}) };
}
function redemption(d: DocumentData | undefined, org: string, redemptionId: string) {
  if (!d || d.schemaVersion !== 1 || d.organizationId !== org || d.redemptionId !== redemptionId || !id(d.memberId)
      || !id(d.itemId) || !text(d.title) || !integer(d.points, 1) || !time(d.issuedAtMillis)
      || !['issued', 'fulfilled'].includes(String(d.status)) || !id(d.policyVersion) || !id(d.exchangeRateVersion)
      || (d.status === 'fulfilled' && (!id(d.fulfilledBy) || !time(d.fulfilledAtMillis)))) throw fail();
  rewardVoucherDetails(d);
  return d;
}
function visibleRedemption(d: DocumentData, now: number) {
  return {...d, status: d.status === 'issued' && d.rewardDetailsVersion === 1 && now >= Number(d.expiresAtMillis) ? 'expired' : d.status};
}
async function admin(tx: TransactionPort, auth: NonNullable<Auth>, org: string) {
  const [u, m, o] = await readAll(tx, [`users/${auth.uid}`, `orgs/${org}/members/${auth.uid}`, `orgs/${org}`]);
  if (requireActiveMembership(m).role !== 'admin' || o?.status !== 'active' || u?.organizationId !== org || (u.role !== undefined && u.role !== 'admin') || m?.organizationId !== org
      || (m.userId !== undefined && m.userId !== auth.uid)) throw deny();
  const l = u.accountLifecycle as DocumentData | undefined;
  if (l !== undefined && (!l || l.schemaVersion !== 1 || l.state !== 'active' || l.revocationPending !== false
      || !integer(l.sessionNotBeforeSeconds) || (l.sessionNotBeforeSeconds > 0
        && (!integer(auth.token.auth_time) || auth.token.auth_time < l.sessionNotBeforeSeconds)))) throw deny();
}
export {policy as parseRewardPolicy, admin as authorizeRewardsAdmin};
export interface RewardsHistoryReader {page(uid: string, after: string | null, limit: number): Promise<{id: string; data: DocumentData}[]>}
/** A latest account cannot prove a past earning tier. Verify a specific durable cleared grant interval. */
function historicalPremium(p: DocumentData | undefined, org: string, uid: string, transactionId: unknown, at: number) {
  if (!p || !id(transactionId) || p.schemaVersion !== 1 || p.organizationId !== org || p.memberId !== uid
      || p.transactionId !== transactionId || p.planId !== 'premium' || !['MembershipPurchase', 'MembershipRenewal'].includes(String(p.kind))
      || p.environment !== 'sandbox' || p.provider !== 'billplz' || p.currency !== 'MYR' || p.paymentStatus !== 'cleared'
      || p.fulfilmentStatus !== 'confirmed' || !text(p.billId) || !text(p.collectionId) || !text(p.planName)
      || !integer(p.amountMinor, 1) || !integer(p.durationDays, 1) || p.durationDays > 3660 || !time(p.clearedAtMillis)
      || !time(p.expiresAtMillis) || p.clearedAtMillis > at || p.expiresAtMillis <= at) return false;
  const starts = p.expiresAtMillis - p.durationDays * DAY;
  return time(starts) && p.clearedAtMillis <= starts && starts <= at;
}
export async function rewardsCommand(store: DocumentStore, auth: Auth, raw: unknown, identity: CoachIdentityReader, clock = Date.now, historyReader?: RewardsHistoryReader): Promise<Record<string, any>> {
  requireVerifiedEmail(auth);
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) throw new InputValidationError('Command object required.');
  const d = raw as DocumentData, action = d.action;
  const actions: Record<string, string[]> = { overview: [], award: ['eventId'], redeem: ['itemId', 'requestId'], inspect: ['redemptionId'], fulfil: ['redemptionId'], voucher: ['redemptionId'], history: ['afterId'] };
  if (d.schemaVersion !== 1 || typeof action !== 'string' || !Object.hasOwn(actions, action)
      || Object.keys(d).some(k => !['schemaVersion', 'organizationId', 'action', ...actions[action], ...(action === 'redeem' ? ['expectedPointCost', 'expectedItemRevision'] : [])].includes(k))) throw new InputValidationError('Invalid rewards command.');
  for (const k of actions[action]) {if (k === 'afterId' && d[k] === null) continue; requiredIdentifier(d[k], k);}
  if (Object.hasOwn(d, 'expectedPointCost') && !integer(d.expectedPointCost, 1)) throw new InputValidationError('Invalid expected reward cost.');
  if (Object.hasOwn(d, 'expectedItemRevision') && !integer(d.expectedItemRevision, 1)) throw new InputValidationError('Invalid expected reward publication.');
  const org = requiredIdentifier(d.organizationId, 'organizationId'), uid = requiredIdentifier(auth!.uid, 'uid');
  // External identity reads must never be repeated inside transaction retries.
  const current = await identity(uid);
  if (!current.exists || current.disabled || !current.emailVerified) throw deny();
  const now = clock(); if (!time(now)) throw fail();
  const path = (collection: string, key: string) => `orgs/${org}/${collection}/${key}`;
  if (action === 'history') {
    if (!historyReader) throw fail();
    await store.transact(tx => resolveMembershipEntitlement(tx, auth, org, clock()));
    const after = d.afterId as string | null, rows = await historyReader.page(uid, after, 26);
    if (!Array.isArray(rows) || rows.length > 26) throw fail();
    let previous = after;
    for (const row of rows) {if (!row || !id(row.id) || (previous !== null && row.id <= previous)) throw fail();
      const r = redemption(row.data, org, row.id); if (r.memberId !== uid) throw fail(); previous = row.id;}
    await store.transact(tx => resolveMembershipEntitlement(tx, auth, org, clock()));
    const resolvedAtMillis = clock(); if (!time(resolvedAtMillis) || resolvedAtMillis < now) throw fail();
    return {schemaVersion: 1, organizationId: org, memberId: uid, redemptions: rows.slice(0, 25).map(row => visibleRedemption(row.data, resolvedAtMillis)),
      nextCursor: rows.length > 25 ? rows[24].id : null, resolvedAtMillis};
  }
  return store.transact(async tx => {
    // Expiry and issuance are checked against fresh time on transaction retries.
    const now = clock(); if (!time(now)) throw fail();
    if (action === 'fulfil' || action === 'inspect') {
      await admin(tx, auth!, org);
      const key = String(d.redemptionId), r = redemption(await tx.get(path('rewardRedemptions', key)), org, key);
      if (action === 'inspect') return { schemaVersion: 1, redemption: visibleRedemption(r, now) };
      if (r.status === 'fulfilled') return { schemaVersion: 1, redemption: r };
      if (r.rewardDetailsVersion === 1 && now >= Number(r.expiresAtMillis)) throw new DomainError('failed-precondition', 'This reward voucher has expired. Points remain spent.');
      const next = { ...r, status: 'fulfilled', fulfilledBy: uid, fulfilledAtMillis: now };
      tx.set(path('rewardRedemptions', key), next);
      return { schemaVersion: 1, redemption: next };
    }
    const entitlement = await resolveMembershipEntitlement(tx, auth, org, now);
    if (action === 'voucher') {
      const key = String(d.redemptionId), r = redemption(await tx.get(path('rewardRedemptions', key)), org, key);
      if (r.memberId !== uid) throw deny();
      return {schemaVersion: 1, redemption: visibleRedemption(r, now), resolvedAtMillis: now};
    }
    const [configured, balanceDoc,shopDoc] = await readAll(tx, [path('rewardPolicies', 'current'), path('rewardBalances', uid),path('rewardShops','current')]);
    const p = policy(configured, org, now), b = balance(balanceDoc, org, uid);
    let shop=action==='overview'?parsePointsRewardShop(shopDoc,org):null;
    if (action === 'overview') {
      const ids=shop?.itemIds??p?.itemIds??[];
      const items = await readAll(tx,ids.map(i => path('rewardItems',i)));
      const history = await readAll(tx, b.recentRedemptionIds.map(i => path('rewardRedemptions', i)));
      const redemptions = history.map((r, i) => {
        const parsed = redemption(r, org, b.recentRedemptionIds[i]); if (parsed.memberId !== uid) throw fail(); return visibleRedemption(parsed, now);
      });
      let catalog: ReturnType<typeof item>[] = [];
      let available = !!(shop??p);
      try { catalog = shop ? items.map((r,i)=>{const value=pointsRewardItem(r,ids[i],org);if(r?.active!==true)throw fail();return value;}) : p ? items.map((r, i) => item(r, p.itemIds[i], org, p)) : []; } catch { available = false; }
      return { schemaVersion: 1, organizationId: org, memberId: uid, available, policyVersion: available ? (shop?.version??p!.version) : null,
        balance: b.points, effectiveTier: entitlement.status === 'resolved' ? entitlement.effectiveTier : null,
        canRedeem: available && entitlement.status === 'resolved' && ['basic', 'premium'].includes(String(entitlement.effectiveTier)),
        items: available ? catalog : [], redemptions, resolvedAtMillis: now };
    }
    if (action === 'redeem') {
      const priorId = digest(uid, String(d.requestId)), prior = await tx.get(path('rewardRedemptions', priorId));
      if (prior) {const r = redemption(prior, org, priorId);
        if (r.memberId !== uid || r.itemId !== d.itemId || r.requestId !== d.requestId) throw new DomainError('already-exists', 'Request already used for another reward.');
        return {schemaVersion: 1, redemption: visibleRedemption(r, now)};}
      shop=parsePointsRewardShop(shopDoc,org);
    }
    if (!p&&!shop) throw fail();
    if (action === 'award') {
      if(!p)throw fail();
      const eventId = String(d.eventId), awardId = digest(uid, eventId);
      const [e, prior] = await readAll(tx, [path('rewardEvents', eventId), path('rewardAwards', awardId)]);
      if (prior) {
        if (prior.schemaVersion !== 1 || prior.organizationId !== org || prior.memberId !== uid || prior.eventId !== eventId || !integer(prior.points, 1)) throw fail();
        return { schemaVersion: 1, award: prior };
      }
      const s = p.sources.find(s => s.sourceId === e?.sourceId && s.producerVersion === e?.producerVersion);
      if (!e || !s || e.schemaVersion !== 1 || e.organizationId !== org || e.memberId !== uid || e.eventId !== eventId
          || e.verification !== 'trusted' || e.rewardPolicyVersion !== p.version || !time(e.occurredAtMillis) || !time(e.recordedAtMillis)
          || e.recordedAtMillis > now || e.occurredAtMillis > e.recordedAtMillis || now - e.occurredAtMillis > s.maxEventAgeMillis
          || e.occurredAtMillis < p.effectiveFromMillis || e.occurredAtMillis >= p.effectiveUntilMillis) throw fail();
      const payment = id(e.membershipTransactionId) ? await tx.get(path('transactions', e.membershipTransactionId)) : undefined;
      const bonus = historicalPremium(payment, org, uid, e.membershipTransactionId, e.occurredAtMillis);
      const points = bonus ? Math.floor(s.basePoints * 3 / 2) : s.basePoints;
      const date = new Intl.DateTimeFormat('en-CA', { timeZone: p.timezone, year: 'numeric', month: '2-digit', day: '2-digit' }).format(e.occurredAtMillis);
      // Deliberately exclude policy version: editing policy must not reset a member's daily cap.
      const capId = digest(uid, s.sourceId, p.timezone, date), cap = await tx.get(path('rewardCaps', capId));
      if (cap && (cap.schemaVersion !== 1 || cap.organizationId !== org || cap.memberId !== uid || cap.sourceId !== s.sourceId
          || cap.timezone !== p.timezone || cap.date !== date || !integer(cap.events) || !integer(cap.points))) throw fail();
      const count = Number(cap?.events ?? 0), cappedPoints = Number(cap?.points ?? 0);
      if (count >= s.dailyEvents || cappedPoints + points > s.dailyAwardPoints) throw new DomainError('resource-exhausted', 'Configured daily reward cap reached.');
      const nextBalance = Number(b.points ?? 0) + points; if (!integer(nextBalance)) throw fail();
      const receipt = { schemaVersion: 1, organizationId: org, memberId: uid, eventId, awardId, sourceId: s.sourceId,
        producerVersion: s.producerVersion, policyVersion: p.version, occurredAtMillis: e.occurredAtMillis, awardedAtMillis: now,
        basePoints: s.basePoints, points, premiumBonus: bonus, tierEvidence: bonus ? 'verified_historical_premium' : 'unverified_or_not_premium_base_only',
        membershipTransactionId: bonus ? e.membershipTransactionId : null };
      tx.create(path('rewardAwards', awardId), receipt);
      tx.set(path('rewardBalances', uid), { ...balanceDoc, schemaVersion: 1, organizationId: org, memberId: uid, points: nextBalance, recentRedemptionIds: b.recentRedemptionIds, updatedAtMillis: now });
      tx.set(path('rewardCaps', capId), { schemaVersion: 1, organizationId: org, memberId: uid, sourceId: s.sourceId, timezone: p.timezone, date, events: count + 1, points: cappedPoints + points });
      return { schemaVersion: 1, award: receipt };
    }
    const itemId = String(d.itemId), requestId = String(d.requestId), redemptionId = digest(uid, requestId);
    if (entitlement.status !== 'resolved' || !['basic', 'premium'].includes(String(entitlement.effectiveTier))) throw deny();
    const itemDoc = await tx.get(path('rewardItems', itemId));
    if(shop&&(!shop.itemIds.includes(itemId)||itemDoc?.active!==true))throw fail();
    const selected = shop?pointsRewardItem(itemDoc,itemId,org):item(itemDoc,itemId,org,p!);
    if ((selected.rewardDetailsVersion === 1 && d.expectedPointCost === undefined) ||
        (d.expectedPointCost !== undefined && d.expectedPointCost !== selected.pointCost)) {
      throw new DomainError('aborted', 'Reward cost changed. Refresh and confirm the displayed cost before redeeming.');
    }
    if (selected.rewardDetailsVersion === 1 && d.expectedItemRevision !== selected.revision) {
      throw new DomainError('aborted', 'Reward information changed. Refresh and review its conditions and validity before redeeming.');
    }
    if (selected.premiumOnly && entitlement.effectiveTier !== 'premium') throw deny();
    if (selected.stock < 1 || b.points === null || b.points < selected.pointCost) throw new DomainError('failed-precondition', 'Insufficient points or reward stock.');
    const details = rewardItemDetails(itemDoc!), expiresAtMillis = details ? now + details.validityDays * DAY : null;
    if (expiresAtMillis !== null && !time(expiresAtMillis)) throw fail();
    const issued = { schemaVersion: 1, organizationId: org, memberId: uid, redemptionId, requestId, itemId, title: selected.title,
      ...(details ? {...details, expiresAtMillis, expiredPointsPolicy: 'remain_spent', publishedItemRevision: itemDoc!.revision} : {}),
      points: selected.pointCost, status: 'issued', issuedAtMillis: now, policyVersion: shop?.version??p!.version, exchangeRateVersion: shop?POINTS_SHOP_VERSION:p!.exchangeRate.version };
    tx.create(path('rewardRedemptions', redemptionId), issued);
    tx.set(path('rewardItems', itemId), { ...itemDoc, stock: selected.stock - 1 });
    // Ledger is immutable; only the bounded display index drops older IDs.
    tx.set(path('rewardBalances', uid), { ...balanceDoc, schemaVersion: 1, organizationId: org, memberId: uid, points: b.points - selected.pointCost,
      recentRedemptionIds: [redemptionId, ...b.recentRedemptionIds].slice(0, 50), updatedAtMillis: now });
    return { schemaVersion: 1, redemption: issued };
  });
}
