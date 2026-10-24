const fs=require('node:fs'),path=require('node:path');
function regionalBuildDefines(env){
 const defines=[];
 if(env.SINGAPORE_CALLABLES?.trim()){
  const source=fs.readFileSync(path.resolve(__dirname,'../../packages/gainpath_data/lib/src/function_endpoint.dart'),'utf8');
  const block=source.match(/static const singaporeEligibleCommands = <String>\{([\s\S]*?)\};/);
  if(!block)throw Error('Shared callable inventory unavailable');
  const allowed=new Set([...block[1].matchAll(/'([^']+)'/g)].map(m=>m[1]));
  const names=[...new Set(env.SINGAPORE_CALLABLES.split(',').map(s=>s.trim()))];
  if(names.some(name=>!allowed.has(name)))throw Error('Invalid SINGAPORE_CALLABLES; use approved deployed logical names');
  defines.push('--dart-define=SINGAPORE_CALLABLES='+names.join(','));
 }
 for(const key of ['FUNCTIONS_REGION','BOOKING_READS_REGION','COACH_RATINGS_REGION'])if(env[key]){
  if(!['us-central1','asia-southeast1'].includes(env[key]))throw Error('Invalid '+key);
  defines.push('--dart-define='+key+'='+env[key]);
 }
 if(env.DIRECT_COACH_READS !== undefined){
  if(!['true','false'].includes(env.DIRECT_COACH_READS))throw Error('Invalid DIRECT_COACH_READS');
  defines.push('--dart-define=DIRECT_COACH_READS='+env.DIRECT_COACH_READS);
 }
 return defines;
}
module.exports={regionalBuildDefines};
