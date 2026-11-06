// Explicit synthetic-only runner; no credentials, download, production or provider fallback.
const {existsSync,mkdirSync}=require('node:fs');
const {resolve,join,delimiter,dirname}=require('node:path');
const {spawnSync}=require('node:child_process');
const root=resolve(__dirname,'..');
const firebase=require.resolve('firebase-tools/lib/bin/firebase.js');
const vitest=require.resolve('vitest/vitest.mjs');
const jar=require('firebase-tools/lib/emulator/downloadableEmulators').getDownloadDetails('firestore').downloadPath;
if(!existsSync(jar))throw Error('Existing Firestore emulator JAR required; no installation or download authorized.');
if(process.env.FIRESTORE_EMULATOR_HOST&&process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:18115')throw Error('Refusing a foreign Firestore emulator endpoint.');
const cliConfig=resolve(root,'../build/module13-e/emulator-cli-config');mkdirSync(cliConfig,{recursive:true});
const childEnv={...process.env,CI:'true',FIREBASE_CLI_DISABLE_USAGE:'1',XDG_CONFIG_HOME:cliConfig,GCE_METADATA_HOST:'127.0.0.1:9',GCLOUD_PROJECT:'demo-gainpath-module13-e',GOOGLE_CLOUD_PROJECT:'demo-gainpath-module13-e',MODULE13_E_CLIENT_UI:process.argv.includes('--with-clients')?'1':'0'};
delete childEnv.GOOGLE_APPLICATION_CREDENTIALS;delete childEnv.FIREBASE_TOKEN;
const java=process.env.JAVA_HOME&&join(process.env.JAVA_HOME,'bin/java.exe');
const javaBinary=java&&existsSync(java)?java:'C:/Program Files/Android/Android Studio/jbr/bin/java.exe';
if(process.platform==='win32'){
  if(!existsSync(javaBinary))throw Error('Installed Java runtime required.');
  const pathKey=Object.keys(childEnv).find(key=>key.toUpperCase()==='PATH')||'PATH';childEnv[pathKey]=`${dirname(javaBinary)}${delimiter}${childEnv[pathKey]||''}`;
}
const result=spawnSync(process.execPath,[firebase,'emulators:exec','--project','demo-gainpath-module13-e','--config',resolve(root,'../firebase/module13-e.emulator.test.json'),'--only','firestore',`"${process.execPath}" "${vitest}" run --config vitest.module13-e.emulator.config.ts`],{cwd:root,stdio:'inherit',env:childEnv});
if(result.error)throw result.error;process.exitCode=result.status??1;
