// Fixed existing CLI identity; no credential discovery, new token, ADC or project fallback.
const fs=require('node:fs'),path=require('node:path'),{createRequire}=require('node:module'),legacy=require('./fyp-live-platform.cjs');
const {root,req,hash,canonical,project}=legacy,out=root+'/build/unified-admin-20261104';
async function connect(){
 for(const k of Object.keys(process.env))if((/EMULATOR/.test(k)&&process.env[k])||k==='GOOGLE_CLOUD_UNIVERSE_DOMAIN'&&process.env[k]!=='googleapis.com')throw Error('Fixed real Google project only.');
 const c=await require(root+'/build/latency-completion-20261024/cloud.cjs').cloud(),cliAuth=req('firebase-tools/lib/auth');
 const credential={getAccessToken:async()=>{const t=await cliAuth.getAccessToken(c.options.tokens.refresh_token,c.options.authScopes);return{access_token:t.access_token,expires_in:3600};}};
 const {initializeApp,deleteApp}=req('firebase-admin/app'),{Firestore}=req('firebase-admin/firestore'),{getAuth}=req('firebase-admin/auth'),sdkReq=createRequire(req.resolve('firebase-admin/firestore')),firestoreReq=createRequire(sdkReq.resolve('@google-cloud/firestore')),gaxReq=createRequire(firestoreReq.resolve('google-gax')),{GoogleAuth,OAuth2Client}=gaxReq('google-auth-library'),oauth=new OAuth2Client();
 oauth.refreshHandler=async()=>{const t=await credential.getAccessToken();return{access_token:t.access_token,expiry_date:Date.now()+3500000};};
 const app=initializeApp({projectId:project,credential},'unified-admin-operator'),db=new Firestore({projectId:project,databaseId:'(default)',ssl:true,preferRest:true,auth:new GoogleAuth({authClient:oauth,projectId:project})});
 if(db.projectId!==project||db.databaseId!=='(default)'||db._settings.ssl!==true)throw Error('Fixed SDK configuration required.');
 return{...c,app,db,auth:getAuth(app),async close(){await db.terminate();await deleteApp(app);}};
}
module.exports={root,out,req,hash,canonical,project,connect,appCheck:legacy.appCheck,read:f=>JSON.parse(fs.readFileSync(path.resolve(root,f),'utf8'))};
