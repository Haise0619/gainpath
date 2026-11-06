/* Synthetic POC only. One runner lock, conservative durable reservations, no retries. */
'use strict';
const fs=require('node:fs');
const path=require('node:path');
function openPocBudget(directory){
  fs.mkdirSync(directory,{recursive:true});
  const lock=path.join(directory,'poc.lock'),file=path.join(directory,'request-ledger.json');
  let fd;try{fd=fs.openSync(lock,'wx');fs.writeFileSync(fd,String(process.pid));}catch{throw Error('poc_already_running');}
  let closed=false;
  const close=()=>{if(!closed){closed=true;fs.closeSync(fd);fs.unlinkSync(lock);}};
  let ledger;
  const persist=()=>{const out=fs.openSync(file,'w');try{fs.writeFileSync(out,JSON.stringify(ledger,null,2)+'\n');fs.fsyncSync(out);}finally{fs.closeSync(out);}};
  try{
    ledger=fs.existsSync(file)?JSON.parse(fs.readFileSync(file,'utf8')):{schemaVersion:1,datasetId:'module13-batch-b-v1',maxRequests:20,maxConcurrent:1,attempts:[]};
    if(ledger.schemaVersion!==1||ledger.datasetId!=='module13-batch-b-v1'||ledger.maxRequests!==20||ledger.maxConcurrent!==1||!Array.isArray(ledger.attempts)||ledger.attempts.length>20||ledger.attempts.some((a,i)=>a.number!==i+1||typeof a.scenario!=='string'||!/^[a-f0-9]{64}$/.test(a.requestHash)||!Number.isSafeInteger(a.inputTokens)||a.inputTokens<1||a.inputTokens>6000)||new Set(ledger.attempts.map(a=>a.scenario)).size!==ledger.attempts.length)throw Error('invalid_ledger');
    if(!fs.existsSync(file))persist();
  }catch{close();throw Error('invalid_ledger');}
  return{
    snapshot:()=>structuredClone(ledger),
    reserve({scenario,requestHash,inputTokens}){
      if(closed)throw Error('budget_closed');
      if(ledger.attempts.length>=20)throw Error('request_limit');
      if(ledger.attempts.some(a=>a.scenario===scenario))throw Error('scenario_already_attempted');
      if(typeof scenario!=='string'||!/^[\w-]{1,80}$/.test(scenario)||!/^[a-f0-9]{64}$/.test(requestHash)||!Number.isSafeInteger(inputTokens)||inputTokens<1||inputTokens>6000)throw Error('invalid_reservation');
      const number=ledger.attempts.length+1;ledger.attempts.push({number,scenario,requestHash,inputTokens,reservedAt:new Date().toISOString(),status:'reserved'});persist();return number;
    },
    complete(number,status){if(closed||!Number.isInteger(number)||number<1||number>ledger.attempts.length||!['returned','failed'].includes(status))throw Error('invalid_completion');Object.assign(ledger.attempts[number-1],{status,completedAt:new Date().toISOString()});persist();},
    close,
  };
}
module.exports={openPocBudget};
