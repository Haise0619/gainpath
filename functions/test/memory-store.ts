import type { DocumentStore, TransactionPort, DocumentData } from '../src/platform/firestore/store';

// Atomic deterministic test adapter. Emulator tests cover real contention/retries.
export class MemoryStore implements DocumentStore {
  readonly documents = new Map<string, DocumentData>();
  private serial: Promise<unknown> = Promise.resolve();
  async transact<T>(work: (tx: TransactionPort) => Promise<T>): Promise<T> {
    const result = this.serial.then(async () => {
      const next = new Map(structuredClone([...this.documents]));
      let writing = false;
      const tx: TransactionPort = {
        get: async (path) => {
          if (writing) throw new Error('Read after write');
          return next.get(path);
        },
        create: (path, value) => {
          writing = true;
          if (next.has(path)) throw new Error('Already exists');
          next.set(path, { ...value });
        },
        set: (path, value) => { writing = true; next.set(path, { ...value }); },
      };
      const value = await work(tx);
      this.documents.clear();
      next.forEach((data, path) => this.documents.set(path, data));
      return value;
    });
    this.serial = result.catch(() => undefined);
    return result;
  }
}
