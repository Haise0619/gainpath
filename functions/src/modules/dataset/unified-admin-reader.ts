import {FieldPath,type Firestore} from 'firebase-admin/firestore';
import {DomainError} from '../../platform/errors';
import type {DocumentData} from '../../platform/firestore/store';
import {fypDigest} from './fyp-integrity';
export type UnifiedSource='existing'|'fyp';
export interface UnifiedAdminRow {id:string;source:UnifiedSource;sourcePath:string;record:DocumentData}
export type UnifiedDirectoryKind='members'|'coaches'|'coachProfiles'|'content'|'routineBlueprints'|'branches'|'exerciseVideos';
export interface UnifiedDirectoryQuery {kind:UnifiedDirectoryKind;afterId?:string;limit?:number;query?:string;status?:string;source?:'all'|UnifiedSource}
export const UNIFIED_ROOT='orgs/gainpath/cohorts/fyp-v1';
const denied=()=>new DomainError('failed-precondition','Unified Admin sources require review. No partial records were returned.');
const id=(x:unknown):x is string=>typeof x==='string'&&/^[A-Za-z0-9_-]{1,128}$/.test(x);
export function mergeUnifiedAdminPage(rows:readonly UnifiedAdminRow[],query:UnifiedDirectoryQuery){
 if(!Array.isArray(rows)||rows.length>2000||!['members','coaches','coachProfiles','content','routineBlueprints','branches','exerciseVideos'].includes(query.kind)||query.source!==undefined&&!['all','existing','fyp'].includes(query.source)||query.limit!==undefined&&(!Number.isSafeInteger(query.limit)||query.limit<1||query.limit>50)||query.afterId!==undefined&&!id(query.afterId)||query.query!==undefined&&(typeof query.query!=='string'||query.query.length>120)||query.status!==undefined&&!['All','Active','Suspended','Published','Inactive','Draft'].includes(query.status))throw denied();
 const ids=new Set<string>(),sourceCounts={existing:0,fyp:0},needle=(query.query??'').trim().toLowerCase();
 const eligible:UnifiedAdminRow[]=[];
 for(const r of rows as readonly UnifiedAdminRow[]){
  if(!r||!id(r.id)||!['existing','fyp'].includes(r.source)||r.sourcePath!==`${r.source==='existing'?'orgs/gainpath':UNIFIED_ROOT}/${query.kind}/${r.id}`||!r.record||r.record.organizationId!==undefined&&r.record.organizationId!=='gainpath')throw denied();
  if(query.kind==='members'&&r.record.role!=='member')continue;
  if(ids.has(r.id))throw denied();ids.add(r.id);sourceCounts[r.source]++;
  if(query.source&&query.source!=='all'&&r.source!==query.source||query.afterId&&r.id<=query.afterId||query.status&&query.status!=='All'&&r.record.status!==query.status.toLowerCase()||needle&&![r.record.displayName,r.record.email,r.record.title,r.record.name].some(x=>typeof x==='string'&&x.toLowerCase().includes(needle)))continue;
  const memberFields=['organizationId','userId','role','displayName','email','status','branchIds','createdAtMillis','updatedAtMillis'];
  eligible.push({...r,record:query.kind==='members'?Object.fromEntries(memberFields.filter(k=>r.record[k]!==undefined).map(k=>[k,r.record[k]])):r.record});
 }
 eligible.sort((a,b)=>a.id<b.id?-1:a.id>b.id?1:0);const limit=query.limit??24,items=eligible.slice(0,limit);
 return{schemaVersion:1 as const,organizationId:'gainpath',items,nextCursor:eligible.length>limit?items.at(-1)!.id:null,sourceCounts};
}
/** SDK reads are fixed to approved collection names; caller owns fresh Admin authorization. */
export function createUnifiedAdminReader(db:Firestore){
 let manifest:Promise<Set<string>>|undefined;
 function expectedPaths(){return manifest??=(async()=>{const run=(await db.doc(`${UNIFIED_ROOT}/seedRuns/gainpath-fyp-v1`).get()).data();
  if(!run||run.schemaVersion!==1||run.seedId!=='gainpath-fyp-v1'||run.status!=='complete'||!Array.isArray(run.sourcePaths)||run.sourcePaths.length>1000||run.sourcePaths.some(p=>typeof p!=='string'||p!==UNIFIED_ROOT&&!p.startsWith(UNIFIED_ROOT+'/'))||new Set(run.sourcePaths).size!==run.sourcePaths.length)throw denied();return new Set<string>(run.sourcePaths);
 })();}
 async function owned(path:string,data?:DocumentData):Promise<DocumentData|undefined>{
  if(!path.startsWith(UNIFIED_ROOT+'/')||path.split('/').some(x=>!id(x)))throw denied();
  const snapshots=await db.getAll(...[...(data?[]:[path]),`${UNIFIED_ROOT}/seedOwnership/${fypDigest(path)}`,`${UNIFIED_ROOT}/generatedOwnership/${fypDigest(path)}`].map(p=>db.doc(p)));
  const record=data??snapshots.shift()!.data();if(!record){if(snapshots.some(s=>s.exists)||(await expectedPaths()).has(path))throw denied();return undefined;}
  if(!snapshots.some(s=>{const x=s.data();return x?.schemaVersion===1&&x.seedId==='gainpath-fyp-v1'&&x.path===path&&x.digest===fypDigest(record);}))throw denied();return record;
 }
 async function rows(kind:UnifiedDirectoryKind,source:UnifiedSource):Promise<UnifiedAdminRow[]>{
  if(!['members','coaches','coachProfiles','content','routineBlueprints','branches','exerciseVideos'].includes(kind))throw denied();const root=source==='existing'?'orgs/gainpath':UNIFIED_ROOT;
  const result=await db.collection(`${root}/${kind}`).orderBy(FieldPath.documentId()).limit(2001).get();
  if(result.size>1000)throw new DomainError('resource-exhausted','Unified directory exceeds its bounded source scan.');
  if(source==='fyp'){const actual=new Set(result.docs.map(d=>d.ref.path));for(const path of await expectedPaths())if(path.startsWith(`${root}/${kind}/`)&&path.split('/').length===6&&!actual.has(path))throw denied();}
  const output:UnifiedAdminRow[]=[];
  for(let offset=0;offset<result.docs.length;offset+=20){const part=result.docs.slice(offset,offset+20);output.push(...await Promise.all(part.map(async d=>({id:d.id,source,sourcePath:d.ref.path,record:source==='fyp'?(await owned(d.ref.path,d.data()))!:d.data()}))));}
  return output;
 }
 async function sourceOf(kind:UnifiedDirectoryKind,key:string):Promise<UnifiedAdminRow>{
  if(!id(key)||!['members','coaches','coachProfiles','content','routineBlueprints','branches','exerciseVideos'].includes(kind))throw denied();const docs=await db.getAll(db.doc(`orgs/gainpath/${kind}/${key}`),db.doc(`${UNIFIED_ROOT}/${kind}/${key}`));
  if(docs.filter(d=>d.exists).length!==1)throw denied();const found=docs.find(d=>d.exists)!,source=found.ref.path.startsWith(UNIFIED_ROOT+'/')?'fyp':'existing';
  return{id:key,source,sourcePath:found.ref.path,record:source==='fyp'?(await owned(found.ref.path,found.data()))!:found.data()!};
 }
 async function coachSource(key:string){
  if(!id(key))throw denied();const roots=['orgs/gainpath',UNIFIED_ROOT],docs=await db.getAll(...roots.flatMap(r=>['coaches','coachProfiles'].map(k=>db.doc(`${r}/${k}/${key}`))));
  const existing=docs[0].exists||docs[1].exists,fyp=docs[2].exists||docs[3].exists;if(existing===fyp)throw denied();const offset=fyp?2:0,source:UnifiedSource=fyp?'fyp':'existing';
  const values=await Promise.all(docs.slice(offset,offset+2).map(async d=>fyp?owned(d.ref.path,d.data()):d.data()));
  return{source,sourcePath:`${roots[fyp?1:0]}/${values[0]?'coaches':'coachProfiles'}/${key}`,publication:values[0]??null,draft:values[1]??null};
 }
 return{owned,rows,sourceOf,coachSource,list:async(query:UnifiedDirectoryQuery)=>mergeUnifiedAdminPage((await Promise.all([rows(query.kind,'existing'),rows(query.kind,'fyp')])).flat(),query)};
}
