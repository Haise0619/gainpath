const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const hash=x=>crypto.createHash('sha256').update(x).digest('hex');
function inventory(dir){const result={};function walk(d){for(const x of fs.readdirSync(d,{withFileTypes:true})){const f=path.join(d,x.name);assert(!x.isSymbolicLink());if(x.isDirectory())walk(f);else result[path.relative(dir,f).split(path.sep).join('/')]=hash(fs.readFileSync(f));}}walk(dir);return result;}
function assertRecoverable(current,previous,staged){
 for(const key of new Set([...Object.keys(current),...Object.keys(previous),...Object.keys(staged)])){
  assert(!key.startsWith('/')&&!key.split('/').includes('..'));
  if(current[key]===undefined){assert(previous[key]===undefined,'A preserved previous file is missing');continue;}
  assert(current[key]===previous[key]||current[key]===staged[key],'Unrelated current bundle bytes require review');
 }
}
function restore(current,previous,staged){const old=inventory(previous);assertRecoverable(inventory(current),old,staged);
 const root=path.resolve(current);assert(!fs.lstatSync(root).isSymbolicLink());
 for(const file of [...Object.keys(old).filter(f=>!['index.html','flutter_bootstrap.js'].includes(f)),'flutter_bootstrap.js','index.html']){
  const target=path.resolve(current,file);assert(target.startsWith(root+path.sep));fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(path.join(previous,file),target);
 }
 for(const[file,h]of Object.entries(old))assert.equal(hash(fs.readFileSync(path.join(current,file))),h);
}
module.exports={inventory,assertRecoverable,restore};
