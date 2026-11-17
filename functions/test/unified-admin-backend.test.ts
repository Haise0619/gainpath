import {expect,it} from 'vitest';
import {parseUnifiedAdminEnvelope,mergeRecommendationPages} from '../src/modules/dataset/unified-admin-backend';
it('merges creation-time pages newest first and retains the safe source frontier',()=>{
 const row=(id:string,createdAtMillis:number)=>({id,createdAtMillis});
 const first=mergeRecommendationPages([
  {records:[row('a',900),row('z',700)],nextAfterId:'z'},
  {records:[row('b',800),row('y',600)],nextAfterId:'y'},
 ]);
 expect(first).toEqual({records:[row('a',900),row('b',800),row('z',700)],nextAfterId:'z'});
 const rows=Array.from({length:50},(_,i)=>row(String(1000+i),2000-i));
 expect(mergeRecommendationPages([
  {records:rows.filter((_,i)=>i%2===0),nextAfterId:rows[48].id},
  {records:rows.filter((_,i)=>i%2===1),nextAfterId:rows[49].id},
 ])).toEqual({records:rows.slice(0,25),nextAfterId:rows[24].id});
});
it('uses chronological scanned frontier metadata when its raw row was filtered from the page',()=>{
 expect(mergeRecommendationPages([
  {records:[{id:'a',createdAtMillis:900}],nextAfterId:'z',nextCreatedAtMillis:700},
  {records:[{id:'b',createdAtMillis:800},{id:'y',createdAtMillis:600}],nextAfterId:null},
 ])).toEqual({
  records:[{id:'a',createdAtMillis:900},{id:'b',createdAtMillis:800}],nextAfterId:'z',
 });
 expect(mergeRecommendationPages([
  {records:[],nextAfterId:'z',nextCreatedAtMillis:700},
  {records:[],nextAfterId:'a',nextCreatedAtMillis:600},
 ])).toEqual({records:[],nextAfterId:'z'});
});
it('advances filtered source pages without dropping later rows or duplicating the other source',()=>{
 expect(mergeRecommendationPages([{records:[],nextAfterId:'2'},{records:[],nextAfterId:'3'}])).toEqual({records:[],nextAfterId:'2'});
 expect(mergeRecommendationPages([{records:[],nextAfterId:'2'},{records:[{id:'1'},{id:'4'}],nextAfterId:null}]))
  .toEqual({records:[{id:'1'}],nextAfterId:'2'});
 expect(mergeRecommendationPages([{records:[{id:'3'}],nextAfterId:null},{records:[{id:'4'}],nextAfterId:null}]))
  .toEqual({records:[{id:'3'},{id:'4'}],nextAfterId:null});
});
it('accepts a fixed unified read operation with no caller-selected authority',()=>{expect(parseUnifiedAdminEnvelope({schemaVersion:1,operation:'admin.unified.directory',data:{schemaVersion:1,organizationId:'gainpath',kind:'members'}}).operation).toBe('admin.unified.directory');});
it('rejects mutation verbs, arbitrary collections, paths, organizations and oversized inputs',()=>{
 for(const q of [{schemaVersion:1,operation:'admin.unified.send',data:{}},{schemaVersion:1,operation:'admin.unified.directory',data:{schemaVersion:1,organizationId:'other',kind:'members'}},{schemaVersion:1,operation:'admin.unified.directory',data:{schemaVersion:1,organizationId:'gainpath',kind:'users',rootPath:'other'}},{schemaVersion:1,operation:'admin.unified.directory',data:{schemaVersion:1,organizationId:'gainpath',kind:'members',padding:'x'.repeat(17000)}},{schemaVersion:1,operation:'admin.unified.directory',role:'admin',data:{}}])expect(()=>parseUnifiedAdminEnvelope(q)).toThrow();
});
