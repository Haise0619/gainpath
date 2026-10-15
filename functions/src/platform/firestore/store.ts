export type DocumentData = Record<string, unknown>;
export interface TransactionPort {
  get(path: string): Promise<DocumentData | undefined>;
  // Same transaction snapshot, one result per input path (including absent docs).
  getAll?(paths: readonly string[]): Promise<(DocumentData | undefined)[]>;
  create(path: string, data: object): void;
  set(path: string, data: object): void;
}
export async function readAll(transaction: TransactionPort, paths: readonly string[]): Promise<(DocumentData | undefined)[]> {
  if (!paths.length) return [];
  return transaction.getAll
    ? transaction.getAll(paths)
    : Promise.all(paths.map(path => transaction.get(path)));
}
export interface DocumentStore {
  // Serializable atomic transactions may retry work. Read before writing;
  // never perform external effects in the callback.
  transact<T>(work: (transaction: TransactionPort) => Promise<T>): Promise<T>;
}
