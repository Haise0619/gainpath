export type DocumentData = Record<string, unknown>;
export interface TransactionPort {
  get(path: string): Promise<DocumentData | undefined>;
  create(path: string, data: object): void;
  set(path: string, data: object): void;
}
export interface DocumentStore {
  // Serializable atomic transactions may retry work. Read before writing;
  // never perform external effects in the callback.
  transact<T>(work: (transaction: TransactionPort) => Promise<T>): Promise<T>;
}
