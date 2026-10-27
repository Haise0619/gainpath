import {beforeEach,expect,it} from 'vitest';
import {uploadRewardCover,type RewardCoverStore} from '../src/modules/gamification/reward-cover-upload';
import {seed,org,adminAuth,auth,now} from './reward-journey-fixture';
let store:ReturnType<typeof seed>,writes:number,after:(()=>void)|undefined;
const covers=new Map<string,{sha256:string;contentType:string;bytes:Buffer}>();
const media:RewardCoverStore={upload:async(path,bytes,contentType,sha256)=>{
 writes++;const old=covers.get(path);if(old&&old.sha256!==sha256)throw Error('immutable conflict');
 covers.set(path,{bytes,sha256,contentType});after?.();return 'https://media.example.test/cover';
}};
const data={schemaVersion:1,organizationId:org,action:'uploadCover',uploadId:'a'.repeat(32),contentType:'image/png',dataBase64:Buffer.from([137,80,78,71,13,10,26,10,0]).toString('base64')};
const run=(input=data,who=adminAuth)=>uploadRewardCover(store,who,input,media,()=>now);
beforeEach(()=>{store=seed();writes=0;after=undefined;covers.clear();});
it('canonical Admin uploads under its own immutable path without Storage Rules document lookups',async()=>{
 expect(await run()).toMatchObject({schemaVersion:1,organizationId:org,url:'https://media.example.test/cover'});
 expect([...covers.keys()]).toEqual([`orgs/${org}/rewardImages/admin/${data.uploadId}`]);expect(writes).toBe(1);
});
it('retries the same upload id without creating another object',async()=>{
 await run();await run();expect(covers.size).toBe(1);
 await expect(run({...data,dataBase64:Buffer.from([137,80,78,71,13,10,26,10,1]).toString('base64')})).rejects.toThrow();
});
it('rejects non-Admin, inactive organization and mismatched canonical assignment before uploading',async()=>{
 await expect(run(data,auth)).rejects.toThrow();
 store.documents.set('orgs/'+org,{status:'inactive'});await expect(run()).rejects.toThrow();
 store=seed();store.documents.set('users/admin',{organizationId:'other'});await expect(run()).rejects.toThrow();expect(writes).toBe(0);
});
it('rejects invalid bytes, MIME, size and client-controlled paths',async()=>{
 await expect(run({...data,contentType:'image/jpeg'})).rejects.toThrow();
 await expect(run({...data,dataBase64:'bad-base64'})).rejects.toThrow();
 await expect(run({...data,dataBase64:Buffer.alloc(5*1024*1024+1).toString('base64')})).rejects.toThrow();
 await expect(run({...data,uploadId:'../another'})).rejects.toThrow();expect(writes).toBe(0);
});
it('rechecks canonical authority after upload before returning a URL',async()=>{
 after=()=>store.documents.set('orgs/'+org,{status:'inactive'});await expect(run()).rejects.toThrow();expect(writes).toBe(1);
});
