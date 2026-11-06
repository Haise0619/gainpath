import {Firestore} from 'firebase-admin/firestore';
import {DomainError} from '../../platform/errors';
export interface DemoRuntimeCapability {readonly __demoRuntime?:never}
const bindings=new WeakMap<object,Firestore>();
function binding(db:Firestore):void{
 const projectId=(db as unknown as {projectId:string}).projectId;
 if(!(db instanceof Firestore)||db.databaseId!=='module13-demo'||!['gainpath-0619','demo-gainpath-module13-demo'].includes(projectId))throw new DomainError('failed-precondition','Dedicated named demo database required.');
 const local=projectId==='demo-gainpath-module13-demo',s=(db as unknown as {_settings:Record<string,unknown>})._settings;
 if(local&&(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:18119'||s.servicePath!=='127.0.0.1'||s.port!==18119||s.ssl!==false)||!local&&(process.env.FIRESTORE_EMULATOR_HOST||s.ssl===false))throw new DomainError('failed-precondition','Demo database transport does not match the reviewed environment.');
}
/** Private WeakMap identity is never serializable or minted from a request flag.
 * A real-project instance alone grants no caller access: the separately composed
 * callable revalidates the enabled manifest, approved identity and owned I/O. */
export function mintDemoRuntimeCapability(db:Firestore):DemoRuntimeCapability{binding(db);const token=Object.freeze({});bindings.set(token,db);return token;}
export function requireDemoRuntimeCapability(capability:DemoRuntimeCapability|undefined,organizationId:string):boolean{
 if(!capability)return false;const db=bindings.get(capability);if(!db||organizationId!=='gainpath')throw new DomainError('failed-precondition','Invalid controlled demo capability.');binding(db);return true;
}
