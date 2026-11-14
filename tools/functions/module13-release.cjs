// Prepare only. Never uploads source, edits Firebase config, or deploys.
const fs = require('node:fs'), path = require('node:path'), cp = require('node:child_process');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const folder = path.join(root, 'build/module13-final-release');
const pkg = path.join(folder, 'package');
fs.mkdirSync(pkg, {recursive: true});
cp.execFileSync(process.execPath, [path.join(root, 'functions/node_modules/typescript/bin/tsc'),
  '-p', path.join(root, 'functions/tsconfig.workout-recommendation-release.json')], {stdio: 'inherit', windowsHide: true});
const original = JSON.parse(fs.readFileSync(path.join(root, 'functions/package.json'), 'utf8'));
const manifest = {name: 'gainpath-module13-final-release', private: true,
  main: 'lib/workout-recommendation-release-index.js', engines: {node: '22'}, dependencies: original.dependencies};
fs.writeFileSync(path.join(pkg, 'package.json'), JSON.stringify(manifest, null, 2));
fs.writeFileSync(path.join(folder, 'firebase.review.json'), JSON.stringify({functions: {
  source: 'package', runtime: 'nodejs22', ignore: ['node_modules', '*.log'],
}}, null, 2));
process.env.NODE_PATH = path.join(root, 'functions/node_modules');
require('node:module').Module._initPaths();
const entry = require(path.join(pkg, manifest.main));
const names = Object.keys(entry).sort();
const expected = ['fypDatasetCommand','module13MemberCommand','module13AdminCommand','module9MemberCommandCallable',
  'module13WorkoutBackupCreated','module13WorkoutConsentChanged','module13FypWorkoutBackupCreated','module13FypWorkoutConsentChanged'].sort();
require('node:assert/strict').deepEqual(names, expected);
const files = [];
function seal(dir) {
  for (const name of fs.readdirSync(dir).sort()) {
    const absolute = path.join(dir, name), stat = fs.lstatSync(absolute);
    if (stat.isSymbolicLink()) throw Error('Unexpected release symlink');
    if (stat.isDirectory()) seal(absolute);
    else files.push({path: path.relative(pkg, absolute).replaceAll('\\', '/'),
      sha256: crypto.createHash('sha256').update(fs.readFileSync(absolute)).digest('hex')});
  }
}
seal(pkg);
fs.writeFileSync(path.join(folder, 'release-manifest.json'), JSON.stringify({
  baseCommit: cp.execFileSync('git', ['rev-parse', 'HEAD'], {cwd: root, encoding: 'utf8'}).trim(),
  projectId: 'gainpath-0619', databaseId: '(default)', region: 'asia-southeast1', deployed: false,
  exports: names, endpoints: Object.fromEntries(names.map(name => [name, entry[name].__endpoint])), files,
}, null, 2));
console.log(`Prepared ${names.length} entrypoints in ${folder}. Nothing deployed.`);
