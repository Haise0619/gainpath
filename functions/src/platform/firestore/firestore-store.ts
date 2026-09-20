import type { Firestore } from 'firebase-admin/firestore';
import type { DocumentStore, TransactionPort } from './store';
export class FirestoreStore implements DocumentStore {
  constructor(private readonly db: Firestore) {}
  transact<T>(work: (transaction: TransactionPort) => Promise<T>): Promise<T> {
    return this.db.runTransaction(tx => work({
      get: async path => (await tx.get(this.db.doc(path))).data(),
      create: (path, data) => { tx.create(this.db.doc(path), data); },
      set: (path, data) => { tx.set(this.db.doc(path), data); },
    }));
  }
}
