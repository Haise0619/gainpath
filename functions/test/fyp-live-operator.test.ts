import {createRequire} from 'node:module';
import {relative,isAbsolute,resolve} from 'node:path';
import {expect,it} from 'vitest';
import {vi} from 'vitest';
const req=createRequire(resolve('package.json')),vault=req('./tools/fyp-live-vault.cjs');
it('uses Windows CurrentUser DPAPI and rejects damaged ciphertext without logging secret material',()=>{
 const value='Synthetic DPAPI known-answer fixture; not a login credential.';
 const encrypted=vault.dpapi('protect',value);
 expect(encrypted).not.toContain(value);expect(vault.dpapi('unprotect',encrypted)).toBe(value);
 expect(()=>vault.dpapi('unprotect','invalid')).toThrow('DPAPI');
});
it('places the encrypted operator vault outside the checkout and rejects unknown inventory before writes',()=>{
 const file=vault.location();expect(isAbsolute(file)).toBe(true);expect(relative(process.cwd(),file).startsWith('..')).toBe(true);
 expect(()=>vault.openVault([],{create:true})).toThrow('27');
});
it('refuses an overridden LOCALAPPDATA that would put credentials inside the repository',()=>{
 const before=process.env.LOCALAPPDATA;process.env.LOCALAPPDATA=resolve('..');try{expect(()=>vault.location()).toThrow('outside');}finally{if(before===undefined)delete process.env.LOCALAPPDATA;else process.env.LOCALAPPDATA=before;}
});
it('rejects an incomplete infrastructure proof before it can skip deployed Function checks',async()=>{
 const fs=req('node:fs'),platform=req('./tools/fyp-live-platform.cjs'),operator=req('./tools/fyp-live.cjs');
 const read=fs.readFileSync,spy=vi.spyOn(fs,'readFileSync').mockImplementation((file:any,...args:any[])=>String(file).endsWith('infrastructure-verified.json')?JSON.stringify({projectId:'gainpath-0619',databaseId:'(default)',passed:true,functionNames:['fypDatasetSessionCommand','fypDatasetCommand','provisionMemberRegistration'],currentFunctionDigests:{},currentIamDigests:{},rulesetName:'current'}):read(file,...args));
 const check=vi.spyOn(platform,'appCheck').mockResolvedValue({appId:'synthetic-test-app'}),request=vi.fn(async()=>({rulesetName:'current'}));
 try{await expect(operator.infrastructure({request})).rejects.toThrow();expect(request).not.toHaveBeenCalled();}finally{spy.mockRestore();check.mockRestore();}
});
