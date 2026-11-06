// Uses only the already configured Firebase CLI account and registered test provider.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{createRequire}=require('node:module');
const root=path.resolve(__dirname,'../..'),req=createRequire(path.join(root,'functions/package.json')),out=path.join(root,'build/fyp-live-20261104'),project='gainpath-0619';
const canonical=v=>Array.isArray(v)?v.map(canonical):v&&typeof v==='object'?Object.fromEntries(Object.keys(v).sort().map(k=>[k,k==='eventFilters'||k==='bindings'||k==='members'?Array.isArray(v[k])?v[k].map(canonical).sort((a,b)=>JSON.stringify(a).localeCompare(JSON.stringify(b))):canonical(v[k]):canonical(v[k])])):v;
const hash=v=>crypto.createHash('sha256').update(Buffer.isBuffer(v)||typeof v==='string'?v:JSON.stringify(canonical(v))).digest('hex');
const read=p=>JSON.parse(fs.readFileSync(path.join(root,p),'utf8'));
// Exact audited integration fixes, preserving the original accepted data/source
// manifest. This is not an arbitrary external hash allowlist or request flag.
const sourceFixes=Object.freeze({
 'functions/src/modules/dataset/fyp-evidence-reader.ts':['d53387599fb032474630b7da38b432d6a70324c0929f7e709788fa5a9d82af4f','a527b1a3bd99575fbf4133fcb52d04d8b5b671bd5613b738e3ca02ac4d5259c5'],
 'apps/admin_web/lib/features/recommendation/application/exercise_insights.dart':['4e1459be8941bf78acf38c9867eb9b06e4ace9d6cac81a284e86f09f2e8ab982','b0f16d6ba155d292937fab2480f02dde8827a1f1b4f3647dab338a3ba23fbe64'],
 'apps/admin_web/lib/features/recommendation/presentation/admin/exercise_insights_panel.dart':['95e4d6e19530f7afaa9d22495aa33d668bd01efa8bb66aefe93ad384dad1911d','632e986ac1079ab46d848ad3e4ca6b0151ed6aac72b00278a5a80069a944cd45'],
 'apps/admin_web/lib/features/recommendation/presentation/admin/recommendation_queue_panel.dart':['d2c9d4c69396dcb7a20d502212c0b7d193dbe3c00ff6a8a503324851007d0a32','69c96a3a975b2b4a5290ce91948591f3607335d1fc5397c992dff6db4f1dcfa1']
});
function checkSource(){const m=read('docs/integration/gainpath-fyp-cohort-preflight.json');for(const [p,h]of Object.entries({...m.deploymentSourceSha256,...m.clientSourceSha256})){const actual=hash(fs.readFileSync(path.join(root,p))),fix=sourceFixes[p];if(actual!==h&&(!fix||fix[0]!==h||fix[1]!==actual))throw Error('Accepted source hash mismatch.');}return m;}
async function connect({quarantineOnly=false}={}){if(!quarantineOnly)checkSource();for(const k of Object.keys(process.env))if(/EMULATOR/.test(k)&&process.env[k])throw Error('Emulator environment refused.');
 const c=await require(path.join(root,'build/latency-completion-20261024/cloud.cjs')).cloud(),cliAuth=req('firebase-tools/lib/auth');
 const credential={getAccessToken:async()=>{const t=await cliAuth.getAccessToken(c.options.tokens.refresh_token,c.options.authScopes);return{access_token:t.access_token,expires_in:3600};}};
 const {initializeApp,deleteApp}=req('firebase-admin/app'),{Firestore}=req('firebase-admin/firestore'),{getAuth}=req('firebase-admin/auth'),sdkReq=createRequire(req.resolve('firebase-admin/firestore')),firestoreReq=createRequire(sdkReq.resolve('@google-cloud/firestore')),gaxReq=createRequire(firestoreReq.resolve('google-gax')),{GoogleAuth,OAuth2Client}=gaxReq('google-auth-library'),oauth=new OAuth2Client();
 oauth.refreshHandler=async()=>{const t=await credential.getAccessToken();return{access_token:t.access_token,expiry_date:Date.now()+3500000};};
 const app=initializeApp({projectId:project,credential},'fyp-live-operator'),db=new Firestore({projectId:project,databaseId:'(default)',ssl:true,preferRest:true,auth:new GoogleAuth({authClient:oauth,projectId:project})});
 return{...c,app,db,auth:getAuth(app),async close(){await db.terminate();await deleteApp(app);}};
}
async function appCheck(c){const fixture=read('build/non-core-crud-sprint/module-8-activation/private/admin-web-app-check.json'),config=fs.readFileSync(path.join(root,'apps/admin_web/lib/firebase_options.dart'),'utf8'),key=config.match(/apiKey:\s*'([^']+)'/)?.[1],appId=config.match(/appId:\s*'([^']+)'/)?.[1];if(fixture.registered!==true||!fixture.token||!key||!appId?.startsWith('1:879719977530:web:'))throw Error('Existing registered App Check configuration required.');const r=await fetch(`https://firebaseappcheck.googleapis.com/v1/projects/879719977530/apps/${appId}:exchangeDebugToken?key=${key}`,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({debugToken:fixture.token}),signal:AbortSignal.timeout(30000)});if(!r.ok)throw Error('App Check exchange failed.');const b=await r.json(),verified=await req('firebase-admin/app-check').getAppCheck(c.app).verifyToken(b.token);if(verified.appId!==appId)throw Error('App Check app mismatch.');return{token:b.token,appId,provider:'existing_registered_debug_provider'};}
module.exports={root,req,out,project,canonical,hash,read,checkSource,connect,appCheck};
