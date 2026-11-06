/* Offline only. Imports real assessor-supplied forms; never invents judgments or invokes inference. */
'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const functionRoot=path.resolve(__dirname,'..'),root=path.resolve(functionRoot,'..');
const frozen=path.join(root,'build/module13-e/evaluation'),bDirectory=path.join(root,'build/module13-batch-b');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
function readJson(file){const bytes=fs.readFileSync(file);if(bytes.length>1048576)throw Error('oversized_assessment_input');return JSON.parse(bytes.toString('utf8'));}
function hashes(directory){return Object.fromEntries(fs.readdirSync(directory).sort().map(name=>[name,sha(fs.readFileSync(path.join(directory,name)))]));}
function inside(file,directory){const relative=path.relative(directory,file);return relative===''||(!relative.startsWith('..'+path.sep)&&relative!=='..'&&!path.isAbsolute(relative));}
function enableTypescript(){const ts=require('typescript');require.extensions['.ts']=(module,filename)=>{
 if(!filename.startsWith(functionRoot+path.sep)||filename.includes(path.sep+'node_modules'+path.sep))throw Error('unexpected_typescript_source');
 module._compile(ts.transpileModule(fs.readFileSync(filename,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,esModuleInterop:true}}).outputText,filename);
};}
async function importHumanAssessments(options){
 const output=path.resolve(options.output);
 if(inside(output,frozen)||inside(output,bDirectory))throw Error('frozen_evidence_output_forbidden');
 if(fs.existsSync(output))throw Error('output_exists');
 const before=hashes(bDirectory),packetBytes=fs.readFileSync(path.join(frozen,'assessor-packet.json')),keyBytes=fs.readFileSync(path.join(frozen,'heldout-custodian-key.json'));
 const previousFetch=global.fetch;global.fetch=async()=>{throw Error('assessment_import_network_forbidden');};
 try{
  enableTypescript();
  const {HELD_OUT_SCENARIOS,prepareHeldOutScenario}=require('../test/recommendation-independent-evaluation.fixture.ts');
  const {buildBlindPackage}=require('../src/modules/recommendation/recommendation-independent-evaluation-labels.ts');
  const {evaluateHumanAssessmentImport}=require('../src/modules/recommendation/recommendation-assessment-import.ts');
  const cases=[];for(const scenario of HELD_OUT_SCENARIOS){const prepared=await prepareHeldOutScenario(scenario);cases.push({id:scenario.id,kind:scenario.kind,need:scenario.need,candidates:prepared.candidates.map(c=>({id:c.id,evidence:c.evidence})),baselineIds:prepared.ranking.baseline.map(c=>c.id)});}
  const seed='module13-e-heldout-blind-v1',rebuilt=buildBlindPackage(cases,seed);
  if(JSON.stringify(JSON.parse(packetBytes.toString('utf8')))!==JSON.stringify(rebuilt.assessorPacket)||JSON.stringify(JSON.parse(keyBytes.toString('utf8')))!==JSON.stringify(rebuilt.privateKey))throw Error('frozen_assessment_package_mismatch');
  const first=readJson(options.assessmentA),second=readJson(options.assessmentB),adjudication=options.adjudication?readJson(options.adjudication):undefined;
  const result=evaluateHumanAssessmentImport(cases,seed,first,second,adjudication);
  const report={...result,assessmentInputHashes:{first:sha(fs.readFileSync(options.assessmentA)),second:sha(fs.readFileSync(options.assessmentB)),adjudication:options.adjudication?sha(fs.readFileSync(options.adjudication)):null},frozenPacketHash:sha(packetBytes),frozenKeyHash:sha(keyBytes),inferenceStatus:'No held-out real-model inference measured; semantic/hybrid metrics remain null.'};
  if(JSON.stringify(before)!==JSON.stringify(hashes(bDirectory))||!packetBytes.equals(fs.readFileSync(path.join(frozen,'assessor-packet.json')))||!keyBytes.equals(fs.readFileSync(path.join(frozen,'heldout-custodian-key.json'))))throw Error('frozen_evidence_changed');
  fs.writeFileSync(output,JSON.stringify(report,null,2)+'\n',{flag:'wx'});
  return{status:report.status,scenarioCount:report.rows.length,networkCalls:0,providerCalls:0};
 }finally{global.fetch=previousFetch;}
}
function argumentsFrom(values){const allowed=new Set(['--assessment-a','--assessment-b','--adjudication','--output']),args={};
 if(values.length%2)throw Error('invalid_import_arguments');
 for(let i=0;i<values.length;i+=2){if(!allowed.has(values[i])||Object.hasOwn(args,values[i])||!values[i+1]||values[i+1].startsWith('--'))throw Error('invalid_import_arguments');args[values[i]]=values[i+1];}
 if(!args['--assessment-a']||!args['--assessment-b']||!args['--output'])throw Error('required_assessment_arguments');
 return{assessmentA:args['--assessment-a'],assessmentB:args['--assessment-b'],adjudication:args['--adjudication'],output:args['--output']};
}
if(require.main===module){Promise.resolve().then(()=>importHumanAssessments(argumentsFrom(process.argv.slice(2)))).then(result=>console.log(JSON.stringify(result))).catch(error=>{console.error(error.message);process.exitCode=1;});}
module.exports={importHumanAssessments};
