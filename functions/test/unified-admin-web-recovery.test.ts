import {expect,it} from 'vitest';
import {mkdtempSync,mkdirSync,writeFileSync,readFileSync,copyFileSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {createRequire} from 'node:module';
const {inventory,restore}=createRequire(resolve('package.json'))('./tools/unified-admin-web-files.cjs');
it('restores a partially copied bundle while refusing unrelated concurrent bytes',()=>{
 const root=resolve('../build/unified-admin-20261104/recovery-fixtures');mkdirSync(root,{recursive:true});const fixture=mkdtempSync(join(root,'partial-'));
 const old=join(fixture,'old'),current=join(fixture,'current'),next=join(fixture,'next');for(const dir of [old,current,next])mkdirSync(dir);
 for(const name of ['main.dart.js','index.html','flutter_bootstrap.js']){writeFileSync(join(old,name),'old '+name);writeFileSync(join(current,name),'old '+name);writeFileSync(join(next,name),'new '+name);}
 writeFileSync(join(next,'new-only.js'),'new asset');copyFileSync(join(next,'main.dart.js'),join(current,'main.dart.js'));
 restore(current,old,inventory(next));expect(inventory(current)).toEqual(inventory(old));
 writeFileSync(join(current,'main.dart.js'),'unrelated concurrent bytes');expect(()=>restore(current,old,inventory(next))).toThrow();expect(readFileSync(join(current,'main.dart.js'),'utf8')).toBe('unrelated concurrent bytes');
});
