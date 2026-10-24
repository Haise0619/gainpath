import { readAll, type TransactionPort } from './store';

/** Batch known independent reads, retaining the original validators and their
 * order. This view lives only within the current transaction attempt. */
export async function prefetchReads(tx: TransactionPort, paths: readonly string[]): Promise<TransactionPort> {
  const unique = [...new Set(paths)];
  const values = await readAll(tx, unique);
  const snapshot = new Map(unique.map((path, i) => [path, values[i]]));
  return {
    get: async path => snapshot.has(path) ? snapshot.get(path) : tx.get(path),
    getAll: async paths => paths.every(path => snapshot.has(path))
      ? paths.map(path => snapshot.get(path)) : readAll(tx, paths),
    // Invalidate on writes so the adapter can still enforce read-before-write.
    create: (path, data) => { snapshot.clear(); tx.create(path, data); },
    set: (path, data) => { snapshot.clear(); tx.set(path, data); },
  };
}
