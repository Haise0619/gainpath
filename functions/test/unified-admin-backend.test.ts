import {expect,it} from 'vitest';
import {parseUnifiedAdminEnvelope} from '../src/modules/dataset/unified-admin-backend';
it('accepts a fixed unified read operation with no caller-selected authority',()=>{expect(parseUnifiedAdminEnvelope({schemaVersion:1,operation:'admin.unified.directory',data:{schemaVersion:1,organizationId:'gainpath',kind:'members'}}).operation).toBe('admin.unified.directory');});
it('rejects mutation verbs, arbitrary collections, paths, organizations and oversized inputs',()=>{
 for(const q of [{schemaVersion:1,operation:'admin.unified.send',data:{}},{schemaVersion:1,operation:'admin.unified.directory',data:{schemaVersion:1,organizationId:'other',kind:'members'}},{schemaVersion:1,operation:'admin.unified.directory',data:{schemaVersion:1,organizationId:'gainpath',kind:'users',rootPath:'other'}},{schemaVersion:1,operation:'admin.unified.directory',data:{schemaVersion:1,organizationId:'gainpath',kind:'members',padding:'x'.repeat(17000)}},{schemaVersion:1,operation:'admin.unified.directory',role:'admin',data:{}}])expect(()=>parseUnifiedAdminEnvelope(q)).toThrow();
});
