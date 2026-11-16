import type {Firestore} from 'firebase-admin/firestore';
import type {DocumentData,DocumentStore} from '../../platform/firestore/store';
import {DomainError} from '../../platform/errors';
import {logicalFypPath,requireFypScope,type FypScope} from './fyp-scope';

/** Narrow Firestore port for the existing handler. Every transaction retains
 * dataset assignment and generated-ownership checks in createFypScopedStore.
 * Only the shared approved organization notice is read outside the cohort. */
export function createFypAssistantFirestore(deps:{scope:FypScope;store:DocumentStore;db:Firestore;readNotice:()=>Promise<DocumentData|undefined>}){
 requireFypScope(deps.scope);
 const{scope,store,db}=deps;
 if(scope.role!=='member')throw new DomainError('permission-denied','Current Member access is required.');
 const state=`orgs/gainpath/members/${scope.uid}/chatbot/state`;
 const notice='orgs/gainpath/chatbotDisclaimer/config';
 const doc=(path:string)=>{logicalFypPath(scope,path);return path;};
 const snapshot=(value:DocumentData|undefined)=>({data:()=>value});
 return {
  doc,
  runTransaction:<T>(work:(tx:any)=>Promise<T>)=>store.transact(async tx=>{
   const read=async(path:string)=>snapshot(path===notice?await deps.readNotice():await tx.get(doc(path)));
   return work({
    get:read,getAll:(...paths:string[])=>Promise.all(paths.map(read)),
    set:(path:string,value:DocumentData)=>{
     if(path!==state)throw new DomainError('permission-denied','Assistant may only save its current Member state.');
     if(Buffer.byteLength(JSON.stringify(value))>200000)throw new DomainError('resource-exhausted','Saved advice is full. Remove an older tip before saving more.');
     tx.set(path,value);
    },
    create:()=>{throw new DomainError('permission-denied','Assistant cannot create business records.');},
   });
  }),
  collection:(path:string)=>{
   if(!['orgs/gainpath/workoutSessions','orgs/gainpath/coaches','orgs/gainpath/gymEquipment'].includes(path))throw new DomainError('permission-denied','Unsupported Assistant read.');
   // Collection paths need a validated document segment for the path mapper.
   const physical=logicalFypPath(scope,path+'/scope').slice(0,-6);
   return db.collection(physical);
  },
 };
}
