import type { Firestore,Timestamp } from 'firebase-admin/firestore';
import {DomainError} from '../errors';
import type { DocumentStore, TransactionPort } from './store';
export class FirestoreStore implements DocumentStore {
  constructor(private readonly db: Firestore,private readonly revision?:{path:string;updateTime:Timestamp}) {}
  transact<T>(work: (transaction: TransactionPort) => Promise<T>): Promise<T> {
    return this.db.runTransaction(tx => work({
      get: async path => {const snapshot=await tx.get(this.db.doc(path));if(this.revision?.path===path&&!snapshot.updateTime?.isEqual(this.revision.updateTime))throw new DomainError('aborted','Booking revision changed.');return snapshot.data();},
      getAll: async paths => paths.length
        ? (await tx.getAll(...paths.map(path => this.db.doc(path)))).map((snapshot,index) => {if(this.revision?.path===paths[index]&&!snapshot.updateTime?.isEqual(this.revision.updateTime))throw new DomainError('aborted','Booking revision changed.');return snapshot.data();})
        : [],
      create: (path, data) => { tx.create(this.db.doc(path), data); },
      set: (path, data) => { tx.set(this.db.doc(path), data); },
    }));
  }
}
