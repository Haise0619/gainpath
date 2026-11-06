import {expect,it} from 'vitest';
import {mkdtempSync,readFileSync,rmSync,writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
const {openPocBudget}=require('../tools/module13-batch-b-budget.cjs');
it('reserves at most 20 actual attempts durably across sessions and refuses concurrent runners',()=>{
  const dir=mkdtempSync(join(tmpdir(),'gainpath-b-poc-'));
  try{const b=openPocBudget(dir);expect(()=>openPocBudget(dir)).toThrow('poc_already_running');
    for(let i=0;i<20;i++)b.reserve({scenario:`s${i}`,requestHash:'a'.repeat(64),inputTokens:100});
    expect(()=>b.reserve({scenario:'excess',requestHash:'a'.repeat(64),inputTokens:100})).toThrow('request_limit');b.close();
    const resumed=openPocBudget(dir);expect(()=>resumed.reserve({scenario:'again',requestHash:'a'.repeat(64),inputTokens:100})).toThrow('request_limit');resumed.close();
    expect(JSON.parse(readFileSync(join(dir,'request-ledger.json'),'utf8')).attempts).toHaveLength(20);
  }finally{rmSync(dir,{recursive:true,force:true});}
});
it('fails closed on corrupt ledger, excess input tokens and duplicate scenario attempts',()=>{
  const dir=mkdtempSync(join(tmpdir(),'gainpath-b-poc-'));
  try{const b=openPocBudget(dir);expect(()=>b.reserve({scenario:'too-large',requestHash:'a'.repeat(64),inputTokens:6001})).toThrow();b.reserve({scenario:'one',requestHash:'a'.repeat(64),inputTokens:100});expect(()=>b.reserve({scenario:'one',requestHash:'a'.repeat(64),inputTokens:100})).toThrow('scenario_already_attempted');b.close();
    writeFileSync(join(dir,'request-ledger.json'),'{}');expect(()=>openPocBudget(dir)).toThrow('invalid_ledger');
  }finally{rmSync(dir,{recursive:true,force:true});}
});
