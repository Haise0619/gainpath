import {DomainError} from '../../platform/errors';
import {readAll,type DocumentStore,type DocumentData} from '../../platform/firestore/store';
import {fypDigest} from './fyp-integrity';
import {aggregateUnifiedSampleBusiness,type SampleBusinessRow} from './unified-sample-business';
const root='orgs/gainpath/cohorts/fyp-v1',logical='orgs/gainpath',manifestPath=`${root}/unifiedSampleManifests/business-v1`;
const fail=()=>new DomainError('failed-precondition','Owned sample business projection is unavailable. No partial amounts were returned.');
function owns(owner:DocumentData|undefined,path:string,value:DocumentData){return owner?.schemaVersion===1&&owner.seedId==='unified-admin-business-v1'&&owner.path===path&&owner.digest===fypDigest(value);}
/** The supplied store is the canonical Admin's read-only cohort-bound store. */
export async function readUnifiedSampleBusiness(store:DocumentStore,window:{startAtMillis:number;endAtMillis:number},now:number){
 const rows=await store.transact(async tx=>{
  const [manifest,proof]=await readAll(tx,[`${logical}/unifiedSampleManifests/business-v1`,`${logical}/unifiedSampleOwnership/${fypDigest(manifestPath)}`]);
  if(!manifest||Object.keys(manifest).sort().join(',')!==['schemaVersion','version','sourceManifestDigest','anchorAtMillis','rowDigests'].sort().join(',')||manifest.schemaVersion!==1||manifest.version!=='unified-admin-business-v1'||manifest.sourceManifestDigest!=='cbca9c7b48b70d4dae6d5cb961eb11a07529f0a1a3a64c7b6581589dd545b405'||!Number.isSafeInteger(manifest.anchorAtMillis)||!owns(proof,manifestPath,manifest)||!manifest.rowDigests||typeof manifest.rowDigests!=='object'||Array.isArray(manifest.rowDigests))throw fail();
  const entries=Object.entries(manifest.rowDigests as Record<string,string>).sort(([a],[b])=>a.localeCompare(b));
  if(entries.length<1||entries.length>250||entries.some(([id,digest])=>!/^[A-Za-z0-9_-]{1,128}$/.test(id)||typeof digest!=='string'||!/^[a-f0-9]{64}$/.test(digest)))throw fail();
  const found=await readAll(tx,entries.flatMap(([id])=>[`${logical}/unifiedSampleBusiness/${id}`,`${logical}/unifiedSampleOwnership/${fypDigest(`${root}/unifiedSampleBusiness/${id}`)}`]));
  return entries.map(([id,digest],i)=>{const value=found[i*2],owner=found[i*2+1];if(!value||value.id!==id||fypDigest(value)!==digest||!owns(owner,`${root}/unifiedSampleBusiness/${id}`,value))throw fail();return value as unknown as SampleBusinessRow;});
 });
 return{summary:aggregateUnifiedSampleBusiness(rows,window,now),rows};
}
