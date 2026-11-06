import type {DocumentData, DocumentStore, TransactionPort} from '../../platform/firestore/store';
import {readAll} from '../../platform/firestore/store';
import {DomainError} from '../../platform/errors';
import {digestOf} from '../workouts/workout-backup-validation';
import {fypDigest} from './fyp-integrity';
import {authorizeUnifiedAdmin,checkUnifiedAdminIdentity} from './unified-admin-scope';

export const FYP_SCOPE_ROOT='orgs/gainpath/cohorts/fyp-v1';
export interface FypIdentity {uid:string;email:string;emailVerified:boolean;disabled:boolean;creationTimeMillis:number;tokensValidAfterMillis:number}
export interface FypRequest {app?:{appId:string};auth?:{uid:string;token:Record<string,unknown>};data:unknown}
export interface FypScope {readonly uid:string;readonly organizationId:'gainpath';readonly datasetId:'fyp-v1';readonly seedId:'gainpath-fyp-v1';readonly rootPath:typeof FYP_SCOPE_ROOT;readonly role:'member'|'coach'|'admin';readonly revision:number;readonly assignmentFingerprint:string;readonly membershipFingerprint:string;readonly authCreatedAtMillis:number;readonly authTimeSeconds:number;readonly branchIds:readonly string[]}
const scopes=new WeakSet<object>();
const adminReads=new WeakMap<object,FypRequest>();
const denied=()=>new DomainError('permission-denied','Your current dataset assignment is unavailable.');
function assignment(data:DocumentData|undefined):DocumentData {
  if(!data||data.schemaVersion!==1||data.datasetId!=='fyp-v1'||data.organizationId!=='gainpath'||data.seedId!=='gainpath-fyp-v1'||data.enabled!==true||!['member','coach','admin'].includes(String(data.role))||!Number.isSafeInteger(data.revision)||Number(data.revision)<1||!Number.isSafeInteger(data.authCreatedAtMillis)||Number(data.authCreatedAtMillis)<=0)throw denied();return data;
}
async function current(tx:TransactionPort,uid:string,expected?:FypScope,authTimeSeconds?:number){
  if(expected&&adminReads.has(expected)){
    const authority=await authorizeUnifiedAdmin(tx,adminReads.get(expected)!);
    if(authority.fingerprint!==expected.membershipFingerprint)throw new DomainError('aborted','Your Admin authorization changed.');
    return {a:{},user:{},member:{}};
  }
  const [raw,root,user,member,canonicalUser,canonicalMember]=await readAll(tx,[`datasetAssignments/${uid}`,FYP_SCOPE_ROOT,`${FYP_SCOPE_ROOT}/users/${uid}`,`${FYP_SCOPE_ROOT}/members/${uid}`,`users/${uid}`,`orgs/gainpath/members/${uid}`]);
  if(canonicalUser||canonicalMember)throw denied();
  const a=assignment(raw);
  if(user?.accountLifecycle!==undefined){const l=user.accountLifecycle as DocumentData,at=expected?.authTimeSeconds??authTimeSeconds;
    if(!l||l.schemaVersion!==1||l.state!=='active'||l.revocationPending!==false||!Number.isSafeInteger(l.sessionNotBeforeSeconds)||Number(l.sessionNotBeforeSeconds)<0||at===undefined||at<Number(l.sessionNotBeforeSeconds))throw denied();}
  if(root?.schemaVersion!==1||root.enabled!==true||root.status!=='active'||root.datasetId!=='fyp-v1'||root.organizationId!=='gainpath'||root.seedId!==a.seedId||user?.organizationId!=='gainpath'||user.status!=='active'||user.role!==a.role||member?.organizationId!=='gainpath'||member.userId!==uid||member.status!=='active'||member.role!==a.role||!Array.isArray(member.branchIds)||!member.branchIds.every(id=>typeof id==='string'&&/^[A-Za-z0-9_-]{1,128}$/.test(id)))throw denied();
  if(expected&&(digestOf(a)!==expected.assignmentFingerprint||digestOf({role:member.role,branchIds:member.branchIds,status:member.status,lifecycle:user.accountLifecycle??null})!==expected.membershipFingerprint))throw new DomainError('aborted','Your dataset assignment changed. Reload your session.');
  return{a,user,member};
}
export async function resolveFypScope(request:FypRequest,deps:{store:DocumentStore;identity:(uid:string)=>Promise<FypIdentity>;clock?:()=>number}):Promise<FypScope>{
  if(!request.app?.appId||!request.auth||request.auth.token.email_verified!==true||typeof request.auth.token.email!=='string'||!Number.isSafeInteger(request.auth.token.auth_time))throw new DomainError('unauthenticated','Verified Auth and App Check are required.');
  const q=request.data as Record<string,unknown>;if(!q||Array.isArray(q)||Object.keys(q).length!==1||q.schemaVersion!==1)throw new DomainError('invalid-argument','Dataset session cannot select a scope.');
  const uid=request.auth.uid;if(!/^[A-Za-z0-9_-]{1,128}$/.test(uid))throw denied();
  const fresh=await deps.identity(uid);
  if(fresh.uid!==uid||fresh.disabled||!fresh.emailVerified||fresh.email!==request.auth.token.email||!Number.isFinite(fresh.tokensValidAfterMillis)||Number(request.auth.token.auth_time)*1000<fresh.tokensValidAfterMillis)throw denied();
  const {a,member,user}=await deps.store.transact(tx=>current(tx,uid,undefined,Number(request.auth!.token.auth_time)));
  if(a.authCreatedAtMillis!==fresh.creationTimeMillis||request.auth.token.fypAuthCreatedAtMillis!==fresh.creationTimeMillis)throw denied();
  const scope:FypScope=Object.freeze({uid,organizationId:'gainpath',datasetId:'fyp-v1',seedId:'gainpath-fyp-v1',rootPath:FYP_SCOPE_ROOT,role:a.role as FypScope['role'],revision:Number(a.revision),assignmentFingerprint:digestOf(a),membershipFingerprint:digestOf({role:member.role,branchIds:member.branchIds,status:member.status,lifecycle:user.accountLifecycle??null}),authCreatedAtMillis:Number(a.authCreatedAtMillis),authTimeSeconds:Number(request.auth.token.auth_time),branchIds:Object.freeze([...(member.branchIds as string[])])});
  scopes.add(scope);return scope;
}
export function requireFypScope(scope:FypScope):void {if(!scopes.has(scope))throw denied();}
/** Explicit server-only bridge: canonical Admin identity, read-only cohort data. */
export async function resolveFypAdminReadScope(request:FypRequest,deps:{store:DocumentStore;identity:(uid:string)=>Promise<FypIdentity>}):Promise<FypScope>{
  const q=request.data as Record<string,unknown>;
  if(!request.auth||!q||Array.isArray(q)||Object.keys(q).length!==1||q.schemaVersion!==1)throw denied();
  const identity=await deps.identity(request.auth.uid);checkUnifiedAdminIdentity(request,identity);
  const authority=await deps.store.transact(tx=>authorizeUnifiedAdmin(tx,request));
  const frozenRequest=Object.freeze({app:Object.freeze({...request.app!}),auth:Object.freeze({uid:request.auth.uid,token:Object.freeze({...request.auth.token})}),data:Object.freeze({schemaVersion:1})});
  const scope:FypScope=Object.freeze({uid:request.auth.uid,organizationId:'gainpath',datasetId:'fyp-v1',seedId:'gainpath-fyp-v1',rootPath:FYP_SCOPE_ROOT,role:'admin',revision:1,assignmentFingerprint:fypDigest({kind:'canonical_admin_read',identity,authority:authority.fingerprint}),membershipFingerprint:authority.fingerprint,authCreatedAtMillis:identity.creationTimeMillis,authTimeSeconds:Number(request.auth.token.auth_time),branchIds:Object.freeze([...authority.branchIds])});
  scopes.add(scope);adminReads.set(scope,frozenRequest);return scope;
}
export function isFypAdminReadScope(scope:FypScope):boolean {requireFypScope(scope);return adminReads.has(scope);}
export function logicalFypPath(scope:FypScope,path:string):string{
  requireFypScope(scope);const parts=path.split('/');if(parts.some(p=>!/^[A-Za-z0-9_-]{1,128}$/.test(p)))throw denied();
  if(adminReads.has(scope)&&(path===`users/${scope.uid}`||path===`orgs/gainpath/members/${scope.uid}`))return path;
  if(parts[0]==='users'&&parts.length===2)return`${scope.rootPath}/${path}`;
  if(path==='orgs/gainpath')return scope.rootPath;
  if(parts[0]==='orgs'&&parts[1]==='gainpath'&&parts.length>=4&&parts[2]!=='cohorts')return`${scope.rootPath}/${parts.slice(2).join('/')}`;
  if(/^module13Demo(?:Source|Expertise|Suitability|Policies)?$/.test(parts[0])&&parts.length===2)return`${scope.rootPath}/${path}`;
  throw denied();
}
export function createFypScopedStore(base:DocumentStore,scope:FypScope):DocumentStore{
  requireFypScope(scope);
  return{transact:work=>base.transact(async tx=>{
    await current(tx,scope.uid,scope);
    const writes=new Map<string,{data:object;create:boolean}>();
    const read=(path:string)=>{if(writes.size)throw new DomainError('failed-precondition','Dataset transactions must read before writing.');return logicalFypPath(scope,path);};
    const stage=(path:string,data:object,create:boolean)=>{
      if(adminReads.has(scope))throw denied();
      const physical=logicalFypPath(scope,path),relative=physical.slice(scope.rootPath.length+1).split('/')[0];
      if(['seedOwnership','seedAuthOwnership','seedRuns','generatedOwnership','module13DemoSource'].includes(relative)||physical===scope.rootPath||writes.size>=80)throw denied();
      if(writes.has(physical))throw new DomainError('failed-precondition','Duplicate dataset write.');writes.set(physical,{data,create});
    };
    const bound:TransactionPort={get:path=>tx.get(read(path)),getAll:paths=>readAll(tx,paths.map(read)),create:(path,data)=>stage(path,data,true),set:(path,data)=>stage(path,data,false)};
    const result=await work(bound);
    const paths=[...writes.keys()],existing=await readAll(tx,paths.flatMap(path=>[path,`${scope.rootPath}/seedOwnership/${fypDigest(path)}`,`${scope.rootPath}/generatedOwnership/${fypDigest(path)}`]));
    for(const[i,path]of paths.entries()){
      const record=existing[i*3],source=existing[i*3+1],generated=existing[i*3+2],entry=writes.get(path)!;
      const identity=(p:DocumentData)=>p.schemaVersion===1&&p.seedId===scope.seedId&&p.path===path&&typeof p.digest==='string'&&/^[a-f0-9]{64}$/.test(p.digest);
      if(source&&!identity(source)||generated&&(!identity(generated)||generated.datasetId!==scope.datasetId))throw new DomainError('aborted','Dataset ownership registry collision.');
      const proof=(p:DocumentData|undefined)=>p&&identity(p)&&p.digest===fypDigest(record);
      if(record&&(entry.create||!proof(source)&&!proof(generated))||!record&&(source||generated))throw new DomainError('aborted','An unowned or changed dataset record occupies this path.');
    }
    for(const[path,entry]of writes){if(entry.create)tx.create(path,entry.data);else tx.set(path,entry.data);
      tx.set(`${scope.rootPath}/generatedOwnership/${fypDigest(path)}`,{schemaVersion:1,seedId:scope.seedId,datasetId:scope.datasetId,path,digest:fypDigest(entry.data),actorId:scope.uid,assignmentRevision:scope.revision,lastWrittenAtMillis:Date.now()});}
    return result;
  })};
}
/** Non-serializable server capability. No request field can construct one. */
export interface FypRuntimeCapability {readonly __fypRuntime?:never}
const capabilities=new WeakMap<object,FypScope>();
export function mintFypRuntimeCapability(scope:FypScope):FypRuntimeCapability{requireFypScope(scope);const token=Object.freeze({});capabilities.set(token,scope);return token;}
export function requireFypRuntimeCapability(capability:FypRuntimeCapability|undefined,organizationId:string):boolean{
  if(!capability)return false;const scope=capabilities.get(capability);if(!scope||organizationId!==scope.organizationId)throw denied();requireFypScope(scope);return true;
}
export function requireFypObservationScope(capability:FypRuntimeCapability|undefined,organizationId:string,memberId:string):void{
  if(!requireFypRuntimeCapability(capability,organizationId))throw denied();const scope=capabilities.get(capability!)!;
  if(scope.role!=='admin'&&(scope.role!=='member'||scope.uid!==memberId))throw denied();
}
export function requireFypQueryRoot(capability:FypRuntimeCapability|undefined,rootPath:string):void{
  if(!requireFypRuntimeCapability(capability,'gainpath')||capabilities.get(capability!)?.rootPath!==rootPath)throw denied();
}
