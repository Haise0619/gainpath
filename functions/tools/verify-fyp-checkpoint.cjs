// Offline evidence/preservation audit. Never initializes Firebase or a provider.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{execFileSync}=require('node:child_process');
const repo=path.resolve(__dirname,'../..'),out='build/fyp-cohort-integration';
const read=p=>JSON.parse(fs.readFileSync(path.join(repo,p),'utf8'));
const sha=p=>crypto.createHash('sha256').update(fs.readFileSync(path.isAbsolute(p)?p:path.join(repo,p))).digest('hex');
function requireTrue(v,m){if(!v)throw Error(m);}
const base=read(`${out}/baseline.json`).hashes,current=execFileSync('git',['ls-files','--cached','--others','--exclude-standard','-z'],{cwd:repo,encoding:'utf8'}).split('\0').filter(Boolean);
const missing=Object.keys(base).filter(p=>!fs.existsSync(path.join(repo,p))),changed=Object.keys(base).filter(p=>!missing.includes(p)&&sha(p)!==base[p]).sort(),added=current.filter(p=>!(p in base)&&fs.existsSync(path.join(repo,p))).sort();
requireTrue(!missing.length,'Preexisting source files were removed.');
const protectedPaths=Object.keys(base).filter(p=>p==='functions/src/index.ts'||p==='firebase/firestore.indexes.json'||p==='firebase/storage.rules'||p.includes('/pose/')||p.startsWith('packages/gainpath_pose/')||p.includes('/assets/')||/typography_theme|app_theme/.test(p)||p.startsWith('functions/src/modules/chatbot/'));
requireTrue(protectedPaths.every(p=>sha(p)===base[p]),'Protected measurement/theme/production configuration changed.');
const historical=[];
for(const checkpoint of ['module13-firebase-demo','module13-final'])for(const[p,hash]of Object.entries(read(`build/${checkpoint}/verification.json`).rawSha256||{})){const target=`build/${checkpoint}/${p}`;requireTrue(sha(target)===hash,'Historical raw evidence changed: '+target);historical.push(target);}
const bArtifacts=read('build/module13-final/verification.json').evaluation.bArtifacts;
for(const[p,hash]of Object.entries(bArtifacts))requireTrue(sha(p)===hash,'Historical Gemini evidence changed: '+p);
const attempts=read('build/module13-batch-b/request-ledger.json').attempts.length;requireTrue(attempts===18,'Historical Gemini request count changed.');
const academics={'C:/Users/Ngzhe/Documents/A-FYP/Final Md file/c3.md':'ed55a2b8dbfb697ffec023ccd91d6332410fb6bd1751b9318c3bf349e3bead2b','C:/Users/Ngzhe/Documents/A-FYP/Final Md file/c4.md':'67aafcd6117601ad5fe6aa34e90f755be85753bd3188363cae39e2ef263e05e7'};
for(const[p,hash]of Object.entries(academics))requireTrue(sha(p)===hash,'Original academic requirements changed.');
const backend=read(`${out}/backend-results.json`),emulator=read(`${out}/emulator-results.json`),proof=read(`${out}/integration-proof.json`),types=read(`${out}/typescript-checks.json`),summaries=Object.fromEntries(['shared-data','admin','mobile'].map(n=>[n,read(`${out}/${n}-summary.json`)]));
requireTrue(backend.success&&backend.numFailedTests===0&&emulator.success&&emulator.numFailedTests===0,'Backend/emulator checks not all passing.');
requireTrue(proof.ordinaryFlutterCompositions&&proof.baselineUnchanged&&proof.revocations,'Ordinary-app/baseline/revocation acceptance missing.');
requireTrue(Number.isFinite(emulator.startTime)&&Math.abs(emulator.startTime-proof.plan.anchorMillis)<=60000,'Emulator result and source proof are from different runs.');
const memberClientLog=`${out}/mobile-client-output-${proof.plan.anchorMillis}.log`;
requireTrue(fs.readFileSync(path.join(repo,memberClientLog),'utf8').includes('actual Admin-widget recipient demo-m13-member-02; delivered inbox entries=2'),'Ordinary Admin-to-same-Member inbox proof missing.');
requireTrue(Object.values(summaries).every(s=>s.exitCode===0&&s.failed===0),'Flutter regression checks failed.');
requireTrue(types.sourceExitCode===0&&types.testsExitCode===0&&fs.readFileSync(path.join(repo,out,'dart-analysis.txt'),'utf8').includes('No issues found!'),'TypeScript/Dart analysis not clean.');
const preflight=read('docs/integration/gainpath-fyp-cohort-preflight.json');requireTrue(preflight.executionEnabled===false&&preflight.sourceManifestDigest===proof.plan.planDigest,'Preflight not bound to final accepted source.');
const screenshots=fs.readdirSync(path.join(repo,'build/fyp-shared-data')).filter(p=>/^ordinary-(admin|member)-.*\.png$/.test(p)).map(p=>'build/fyp-shared-data/'+p);
requireTrue(screenshots.length>=13,'Ordinary UI screenshot evidence incomplete.');
const sourceHashes=Object.fromEntries([...changed,...added].map(p=>[p,sha(p)]));
fs.writeFileSync(path.join(repo,out,'source-changes.json'),JSON.stringify({baselineFiles:Object.keys(base).length,changed,added,missing,sourceSha256:sourceHashes},null,2)+'\n');
const result={schemaVersion:1,dateMalaysia:'2026-11-04',checkpoint:'secure_fyp_default_database_cohort_local_acceptance',status:'PASS',liveFirebase:false,
 tests:{backend:{passed:backend.numPassedTests,files:backend.testResults.length},emulator:{passed:emulator.numPassedTests,files:emulator.testResults.length,includesTwoOrdinaryFlutterClients:true},flutter:summaries,typescript:types,dartAnalysis:'PASS'},
 dataset:{sourceDocuments:proof.seed.sourceDocuments,authIdentities:27,members:18,coaches:8,publishedCoaches:7,tutorials:12,programs:3,goals:18,observations:52,initialFirestoreDocuments:1014,anchorMillis:proof.plan.anchorMillis,digest:proof.plan.planDigest},
 integration:{ordinaryAuth:proof.normalAuthSession,publishedIsolation:proof.publishedIsolation,historyAndReporting:proof.sharedHistoryAndReports,trainer:proof.trainerGeneration,content:proof.contentGeneration,adminSendAndMemberDelivery:proof.adminSendMemberDelivery,ordinaryFlutter:proof.ordinaryFlutterCompositions,ordinaryUiRecipient:'demo-m13-member-02',ordinaryClientsShareSendAndInbox:true,memberClientLog,revocations:proof.revocations,canonicalBaselineUnchanged:proof.baselineUnchanged},
 preservation:{baselineFiles:Object.keys(base).length,unchanged:Object.keys(base).length-changed.length,missing,protectedPaths:protectedPaths.length,historicalRawArtifacts:historical.length,bArtifacts:Object.keys(bArtifacts).length,historicalGeminiAttempts:attempts,academicOriginals:academics},
 sourceChanges:`${out}/source-changes.json`,screenshots:Object.fromEntries(screenshots.map(p=>[p,sha(p)])),
 rawSha256:Object.fromEntries(['backend-results.json','emulator-results.json','integration-proof.json','dart-analysis.txt','typescript-checks.json','shared-data-results.jsonl','admin-results.jsonl','mobile-results.jsonl','source-changes.json'].map(p=>[p,sha(`${out}/${p}`)])),
 preflight:{path:'docs/integration/gainpath-fyp-cohort-preflight.json',sha256:sha('docs/integration/gainpath-fyp-cohort-preflight.json'),executionEnabled:false,liveExecutor:false},
 actions:{liveReads:0,liveWrites:0,deployments:0,newGeminiRequests:0,productionConsentActivation:false,iamOrBillingChanges:false,apkBuildOrInstall:false,gitResetStashClean:false},
 limitations:['Ordinary widget compositions use actual emulator REST at the Auth/Firestore/callable ports; native SDK browser/device UAT remains pending.','Test-only offline font aliases substitute bundled Barlow bytes; production theme unchanged.','Installed emulator host Node24 differs from proposed Node22 runtime.','Decoded emulator App Check token is not cryptographic production attestation.','Credential metadata only, no Storage attachments.','Real Member processing/policy/retention and independent recommendation quality remain outside this checkpoint.']};
fs.writeFileSync(path.join(repo,out,'verification.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify({status:result.status,backend:result.tests.backend,emulator:result.tests.emulator,flutter:Object.fromEntries(Object.entries(summaries).map(([k,v])=>[k,v.passed])),changed:changed.length,added:added.length,screenshots:screenshots.length,preservation:result.preservation}));
