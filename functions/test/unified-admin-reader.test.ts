import {expect,it} from 'vitest';
import {mergeUnifiedAdminPage,createUnifiedAdminReader,UNIFIED_ROOT} from '../src/modules/dataset/unified-admin-reader';
import type {Firestore} from 'firebase-admin/firestore';
import {fypDigest} from '../src/modules/dataset/fyp-integrity';
const row=(id:string,source:'existing'|'fyp',name=id)=>({id,source,sourcePath:source==='existing'?`orgs/gainpath/members/${id}`:`orgs/gainpath/cohorts/fyp-v1/members/${id}`,record:{organizationId:'gainpath',role:'member',displayName:name,status:'active',email:id+'@example.invalid',privateNotes:'never browser'}});
it('rejects a missing manifest source instead of publishing a smaller partial directory',async()=>{
 const path=UNIFIED_ROOT+'/members/missing',docs=new Map<string,object>([[UNIFIED_ROOT+'/seedRuns/gainpath-fyp-v1',{schemaVersion:1,seedId:'gainpath-fyp-v1',status:'complete',sourcePaths:[UNIFIED_ROOT,path]}]]);
 const db={doc:(p:string)=>({get:async()=>({data:()=>docs.get(p)})}),collection:()=>({orderBy:()=>({limit:()=>({get:async()=>({size:0,docs:[]})})})})} as unknown as Firestore;
 await expect(createUnifiedAdminReader(db).rows('members','fyp')).rejects.toThrow();
});
it('merges default-all authorized identities with deterministic bounded pagination and explicit provenance',()=>{
 const rows=[row('z','existing'),row('a','fyp'),row('m','existing')];const page=mergeUnifiedAdminPage(rows,{kind:'members',limit:2});expect(page.items.map(x=>x.id)).toEqual(['a','m']);expect(page.nextCursor).toBe('m');expect(page.items[0].source).toBe('fyp');expect(page.items[0].record).not.toHaveProperty('privateNotes');expect(page.sourceCounts).toEqual({existing:2,fyp:1});
 expect(mergeUnifiedAdminPage(rows,{kind:'members',afterId:page.nextCursor!,limit:2}).items.map(x=>x.id)).toEqual(['z']);
});
it('filters across both sources without hiding FYP by default',()=>{
 const rows=[row('a','existing','Alice'),row('b','fyp','Bela')];expect(mergeUnifiedAdminPage(rows,{kind:'members',query:'BELA'}).items.map(x=>x.id)).toEqual(['b']);expect(mergeUnifiedAdminPage(rows,{kind:'members',source:'existing'}).items).toHaveLength(1);expect(mergeUnifiedAdminPage(rows,{kind:'members'}).items).toHaveLength(2);
});
it('fails closed for duplicate identities, foreign sources, oversized scans or invalid query controls',()=>{
 const a=row('a','existing');for(const rows of [[a,row('a','fyp')],[{...a,sourcePath:'orgs/foreign/members/a'}],[{...a,record:{...a.record,organizationId:'foreign'}}],Array.from({length:2001},(_,i)=>row('id'+i,'existing'))])expect(()=>mergeUnifiedAdminPage(rows as never,{kind:'members'})).toThrow();
 for(const query of [{limit:0},{limit:51},{source:'other'},{afterId:'../escape'},{query:'x'.repeat(121)}])expect(()=>mergeUnifiedAdminPage([a],{kind:'members',...query} as never)).toThrow();
});
