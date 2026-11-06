import {expect,it} from 'vitest';
import {execFileSync,spawnSync} from 'node:child_process';
import {mkdtempSync,readFileSync,writeFileSync,rmSync,readdirSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {resolve,join,dirname,basename} from 'node:path';
import {createHash} from 'node:crypto';
const root=resolve(__dirname,'../..'),tool=resolve(root,'functions/tools/module13-import-assessments.cjs'),frozen=resolve(root,'build/module13-e/evaluation');
const hashDirectory=(directory:string)=>Object.fromEntries(readdirSync(directory).map(name=>[name,createHash('sha256').update(readFileSync(join(directory,name))).digest('hex')]));
it('imports fixture-only completed forms offline, preserves original evidence, refuses overwrite and blank forms',()=>{
 const before=hashDirectory(resolve(root,'build/module13-batch-b')),packetBefore=readFileSync(join(frozen,'assessor-packet.json'),'utf8'),directory=mkdtempSync(join(tmpdir(),'module13-assessment-import-'));
 try{
  const args=['--assessment-a',join(directory,'a.json'),'--assessment-b',join(directory,'b.json'),'--output',join(directory,'result.json')];
  for(const [index,file] of ['a.json','b.json'].entries()){
   const form=JSON.parse(readFileSync(join(frozen,`assessor-${index?'B':'A'}.blank.json`),'utf8'));
   form.assessorId=`software-test-not-human-${index}`;form.independent=true;form.blinded=true;
   form.items=form.items.map((item:any)=>({...item,grade:0,rationale:'Automated software test only; not a human judgment.'}));writeFileSync(join(directory,file),JSON.stringify(form));
  }
  const run=(flags:string[])=>execFileSync(process.execPath,[tool,...flags],{cwd:root,encoding:'utf8',env:{...process.env,GEMINI_API_KEY:'MUST_NOT_BE_USED'},timeout:30000,windowsHide:true});
  run(args);const result=JSON.parse(readFileSync(join(directory,'result.json'),'utf8'));
  expect(result).toMatchObject({status:'complete',networkCalls:0,providerCalls:0});expect(result.rows).toHaveLength(22);expect(result.summary.semantic).toBeNull();
  const duplicate=spawnSync(process.execPath,[tool,...args],{cwd:root,encoding:'utf8',windowsHide:true});expect(duplicate.status).toBe(1);expect(duplicate.stderr).toContain('output_exists');
  const blank=spawnSync(process.execPath,[tool,'--assessment-a',join(frozen,'assessor-A.blank.json'),'--assessment-b',join(frozen,'assessor-B.blank.json'),'--output',join(directory,'blank.json')],{cwd:root,encoding:'utf8',windowsHide:true});expect(blank.status).toBe(1);expect(blank.stderr).toContain('incomplete_assessment');
  expect(hashDirectory(resolve(root,'build/module13-batch-b'))).toEqual(before);expect(readFileSync(join(frozen,'assessor-packet.json'),'utf8')).toBe(packetBefore);
 }finally{if(dirname(resolve(directory))!==resolve(tmpdir())||!basename(directory).startsWith('module13-assessment-import-'))throw Error('invalid_test_cleanup_target');rmSync(directory,{recursive:true,force:true});}
},30000);
it('rejects unbounded, activation-like and frozen-output CLI inputs before emitting judgments',()=>{
 const directory=mkdtempSync(join(tmpdir(),'module13-assessment-import-'));
 try{
  const a=join(directory,'oversized.json'),b=join(frozen,'assessor-B.blank.json');writeFileSync(a,' '.repeat(1048577));
  const run=(args:string[])=>spawnSync(process.execPath,[tool,...args],{cwd:root,encoding:'utf8',windowsHide:true,timeout:30000});
  const oversized=run(['--assessment-a',a,'--assessment-b',b,'--output',join(directory,'result.json')]);expect(oversized.status).toBe(1);expect(oversized.stderr).toContain('oversized_assessment_input');
  const frozenOutput=run(['--assessment-a',a,'--assessment-b',b,'--output',join(frozen,'new-import.json')]);expect(frozenOutput.status).toBe(1);expect(frozenOutput.stderr).toContain('frozen_evidence_output_forbidden');
  const flag=run(['--enabled','true']);expect(flag.status).toBe(1);expect(flag.stderr).toContain('invalid_import_arguments');
 }finally{if(dirname(resolve(directory))!==resolve(tmpdir())||!basename(directory).startsWith('module13-assessment-import-'))throw Error('invalid_test_cleanup_target');rmSync(directory,{recursive:true,force:true});}
},30000);
