import { FieldPath, type Firestore } from 'firebase-admin/firestore';
import type { DocumentData, TransactionPort } from '../../platform/firestore/store';

export interface ConversationQuery {
  collection: string;
  filters?: [string, '==' | '<' | '<=', unknown][];
  order?: [string, 'asc' | 'desc'][];
  after?: unknown[];
  limit: number;
}
export interface ConversationTransaction extends TransactionPort {
  query(spec: ConversationQuery): Promise<{ id: string; data: DocumentData }[]>;
}
export interface ConversationStore {
  transact<T>(work: (tx: ConversationTransaction) => Promise<T>): Promise<T>;
}
export class FirestoreConversationStore implements ConversationStore {
  constructor(private readonly db: Firestore) {}
  transact<T>(work: (tx: ConversationTransaction) => Promise<T>): Promise<T> {
    return this.db.runTransaction(tx => work({
      get: async path => (await tx.get(this.db.doc(path))).data(),
      create: (path, value) => { tx.create(this.db.doc(path), value); },
      set: (path, value) => { tx.set(this.db.doc(path), value); },
      query: async spec => {
        let query: FirebaseFirestore.Query = this.db.collection(spec.collection);
        for (const [field, op, value] of spec.filters ?? []) query = query.where(field, op, value);
        for (const [field, dir] of spec.order ?? []) query = query.orderBy(field === '__name__' ? FieldPath.documentId() : field, dir);
        if (spec.after) query = query.startAfter(...spec.after);
        const page = await tx.get(query.limit(spec.limit));
        return page.docs.map(doc => ({ id: doc.id, data: doc.data() }));
      },
    }));
  }
}
