import type { DocumentStore, TransactionPort } from '../src/platform/firestore/store';
import { MemoryStore } from './memory-store';

/** Snapshot-preserving adapter with an optional synthetic per-RPC delay. */
export class ReadProbeStore implements DocumentStore {
  readonly memory = new MemoryStore();
  readonly singles: string[] = [];
  readonly batches: string[][] = [];
  activeTransactions = 0;
  constructor(private readonly rpcDelayMillis = 0) {}
  get documents() { return this.memory.documents; }
  get documentReads() { return this.singles.length + this.batches.reduce((n, b) => n + b.length, 0); }
  get readRpcs() { return this.singles.length + this.batches.length; }
  async transact<T>(work: (tx: TransactionPort) => Promise<T>): Promise<T> {
    this.activeTransactions++;
    try {
      return await this.memory.transact(tx => work({
        get: async path => {
          this.singles.push(path);
          await this.delay();
          return tx.get(path);
        },
        getAll: async paths => {
          this.batches.push([...paths]);
          await this.delay();
          return Promise.all(paths.map(path => tx.get(path)));
        },
        create: tx.create,
        set: tx.set,
      }));
    } finally { this.activeTransactions--; }
  }
  private async delay() {
    if (this.rpcDelayMillis) await new Promise(resolve => setTimeout(resolve, this.rpcDelayMillis));
  }
}
