import {DomainError} from '../../platform/errors';
import type {DocumentData, TransactionPort} from '../../platform/firestore/store';
import type {InsightsAuth} from './exercise-insights-contracts';
import {createCanonicalRecommendationLifecycle, type CanonicalLifecycleDependencies} from './canonical-recommendation-lifecycle';

/** One read-only transaction snapshot per page. Never reuse privacy or target
 * checks across requests, and never use this store for delivery/mutations. */
export async function canonicalRecommendationPage(deps: CanonicalLifecycleDependencies,
  auth: InsightsAuth, org: string, after: string|null, admin: boolean, history = false) {
  return deps.store.transact(async underlying => {
    const reads = new Map<string, Promise<DocumentData|undefined>>();
    const noWrite = () => {throw new Error('Recommendation pages are read-only.');};
    const tx: TransactionPort = {
      get(path) {
        let pending = reads.get(path);
        if (!pending) {pending = underlying.get(path); reads.set(path, pending);}
        return pending;
      },
      create: noWrite, set: noWrite,
    };
    const lifecycle = createCanonicalRecommendationLifecycle({...deps,
      store: {transact: work => work(tx)}});
    // ids() authorizes before any recommendation documents are read.
    const ids = await lifecycle.ids(auth, org, after, admin);
    if (underlying.getAll && ids.length) {
      const paths = ids.map(id => `orgs/${org}/canonicalRecommendations/${id}`);
      const values = await underlying.getAll(paths);
      paths.forEach((path, index) => reads.set(path, Promise.resolve(values[index])));
    }
    const records: unknown[] = [];
    // Bound concurrent target checks while keeping stable cursor order.
    for (let offset = 0; offset < ids.length; offset += 4) {
      const batch = await Promise.all(ids.slice(offset, offset + 4).map(async id => {
        try {
          if (admin) return await lifecycle.adminDetail(auth, org, id);
          const detail = await lifecycle.member(auth, org, id, 'get', null, null);
          return detail.deliveredAtMillis !== null && (history || detail.state === 'available') ? detail : null;
        } catch (error) {
          if (error instanceof DomainError && (error.code === 'failed-precondition' ||
            !admin && error.code === 'permission-denied')) return null;
          throw error;
        }
      }));
      records.push(...batch.filter(row => row !== null));
    }
    return {records, nextAfterId: ids.length === 25 ? ids[ids.length - 1] : null};
  });
}
