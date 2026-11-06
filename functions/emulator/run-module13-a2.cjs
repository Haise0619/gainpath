// Dedicated synthetic-only invocation: node emulator/run-module13-a2.cjs
// Uses installed dependencies and the existing cached JAR; never installs tools.
const {existsSync, mkdirSync} = require('node:fs');
const {resolve, join, delimiter, dirname} = require('node:path');
const {spawnSync} = require('node:child_process');
const root = resolve(__dirname, '..');
const firebase = require.resolve('firebase-tools/lib/bin/firebase.js');
const vitest = require.resolve('vitest/vitest.mjs');
const jar = require('firebase-tools/lib/emulator/downloadableEmulators').getDownloadDetails('firestore').downloadPath;
if (!existsSync(jar)) throw Error('Existing Firestore emulator JAR required; downloads are outside this local verification scope.');
if (process.env.FIRESTORE_EMULATOR_HOST && process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:18110') {
  throw Error('Refusing a foreign Firestore emulator endpoint.');
}
// Isolate CLI preferences/accounts too: do not inherit the owner's saved login.
const cliConfig = resolve(root, '../build/module13-a2/emulator-cli-config');
mkdirSync(cliConfig, {recursive: true});
const childEnv = {...process.env, CI: 'true', FIREBASE_CLI_DISABLE_USAGE: '1',
  XDG_CONFIG_HOME: cliConfig, GCE_METADATA_HOST: '127.0.0.1:9',
  GCLOUD_PROJECT: 'demo-gainpath-module13-a2', GOOGLE_CLOUD_PROJECT: 'demo-gainpath-module13-a2'};
delete childEnv.GOOGLE_APPLICATION_CREDENTIALS;
delete childEnv.FIREBASE_TOKEN;
// Windows' Oracle java.exe shim hangs on this workstation; use the installed
// Android Studio runtime directly, without launching an application or installing Java.
const java = process.env.JAVA_HOME && join(process.env.JAVA_HOME, 'bin/java.exe');
const javaBinary = java && existsSync(java) ? java : 'C:/Program Files/Android/Android Studio/jbr/bin/java.exe';
if (process.platform === 'win32') {
  if (!existsSync(javaBinary)) throw Error('An installed Java runtime is required. Set JAVA_HOME.');
  const pathKey = Object.keys(childEnv).find(key => key.toUpperCase() === 'PATH') || 'PATH';
  childEnv[pathKey] = `${dirname(javaBinary)}${delimiter}${childEnv[pathKey] || ''}`;
}
const result = spawnSync(process.execPath, [firebase, 'emulators:exec', '--project', 'demo-gainpath-module13-a2',
  '--config', resolve(root, '../firebase/module13-a2.emulator.test.json'), '--only', 'firestore',
  `"${process.execPath}" "${vitest}" run --config vitest.module13-a2.emulator.config.ts`], {
  cwd: root, stdio: 'inherit', env: childEnv,
});
if (result.error) throw result.error;
process.exitCode = result.status ?? 1;
