// Focused local regression checks; no builds, provider requests or live data.
const fs=require('node:fs'),path=require('node:path'),{spawnSync}=require('node:child_process');
const repo=path.resolve(__dirname,'../..'),out=path.join(repo,'build/fyp-cohort-integration');
const groups={
 'shared-data':{cwd:'packages/gainpath_data',files:['fyp_dataset_transport_test.dart','module13_demo_transport_test.dart','firebase_auth_repository_test.dart','firebase_fitness_profile_repository_test.dart']},
 admin:{cwd:'apps/admin_web',files:['fyp_workout_reporting_test.dart','fyp_offline_fonts_test.dart','firebase_demo_recommendation_test.dart','recommendation_queue_test.dart','admin_recommendation_queue_test.dart','exercise_insights_test.dart','admin_exercise_insights_test.dart','admin_workout_reporting_test.dart','admin_workout_reporting_ui_test.dart','admin_reporting_regression_test.dart','admin_original_reporting_layout_test.dart','admin_member_directory_test.dart','module13_ui_preservation_test.dart']},
 mobile:{cwd:'apps/mobile',files:['fyp_progress_repository_test.dart','firebase_published_routine_catalog_test.dart','firebase_demo_recommendation_test.dart','local_member_progress_repository_test.dart','member_recommendation_repository_test.dart','member_recommendation_ui_test.dart','member_recommendation_navigation_test.dart','recommendation_consent_repository_test.dart','personalized_recommendation_settings_test.dart','coach_directory_state_test.dart','fitness_profile_flow_test.dart','progress_report_refinement_test.dart','features/workout_history_bloc_test.dart','features/workout_account_scope_test.dart']}
};
fs.mkdirSync(out,{recursive:true});let failed=false;
for(const[name,group]of Object.entries(groups)){
 const files=group.files.map(f=>'test/'+f),log=path.join(out,`${name}-results.jsonl`);
 const result=spawnSync('C:/flutter/bin/cache/dart-sdk/bin/dart.exe',['C:/flutter/bin/cache/flutter_tools.snapshot','test','--no-pub','--reporter','json',...files],{cwd:path.join(repo,group.cwd),encoding:'utf8',windowsHide:true,maxBuffer:20*1024*1024});
 fs.writeFileSync(log,result.stdout||'');fs.writeFileSync(path.join(out,`${name}-stderr.txt`),result.stderr||'');
 const events=(result.stdout||'').split(/\r?\n/).flatMap(line=>{try{return[JSON.parse(line)];}catch{return[];}}),done=events.filter(e=>e.type==='testDone'&&!e.hidden),errors=events.filter(e=>e.type==='error');
 const summary={exitCode:result.status,passed:done.filter(e=>e.result==='success'&&!e.skipped).length,failed:done.filter(e=>e.result==='error'||e.result==='failure').length,skipped:done.filter(e=>e.skipped).length,files,cwd:group.cwd,errors};
 fs.writeFileSync(path.join(out,`${name}-summary.json`),JSON.stringify(summary,null,2)+'\n');console.log(name,JSON.stringify({...summary,errors:errors.length}));
 if(result.status!==0){failed=true;for(const e of errors)console.error(e.error);}
}
process.exitCode=failed?1:0;
