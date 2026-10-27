const {readdirSync, mkdtempSync, writeFileSync, copyFileSync, rmSync} = require('node:fs');
const {join, resolve, delimiter} = require('node:path');
const {tmpdir} = require('node:os');
const {spawnSync} = require('node:child_process');

// Newer integration suites intentionally use separate ports and demo projects.
// Keep those guards intact rather than running them against the core emulator.
const suites = {
  core: {project: 'demo-gainpath', port: 18080, storage: 19199, tests: []},
  backup: {project: 'demo-gainpath-backup', port: 18086, tests: ['workout-backup']},
  checkin: {project: 'demo-gainpath-checkin', port: 18087, tests: ['app-check-in']},
  reporting: {project: 'demo-gainpath-reporting', port: 18088, storage: 19200,
    tests: ['admin-reporting', 'admin-workout-reporting', 'admin-check-in-reporting',
      'reward-journey', 'reward-cover-upload', 'mini-game-rewards', 'workout-rewards']},
  rounds: {project: 'demo-gainpath-mini-game-rounds', port: 18092, tests: ['mini-game-rounds']},
  participation: {project: 'demo-gainpath-participation', port: 18096, tests: ['mini-game-participation']},
};
for (const suite of Object.values(suites)) {
  suite.tests = suite.tests.map(name => `emulator/${name}.test.ts`);
}
const dedicated = new Set(Object.values(suites).flatMap(suite => suite.tests));
suites.core.tests = readdirSync(__dirname).filter(name => name.endsWith('.test.ts'))
  .map(name => `emulator/${name}`).filter(name => !dedicated.has(name)).sort();

function configFor(name) {
  if (!Object.hasOwn(suites, name)) throw new Error(`Unknown emulator suite: ${name}`);
  const suite = suites[name];
  return {
    firestore: {rules: 'firestore.rules', indexes: 'firestore.indexes.json'},
    ...(suite.storage ? {storage: {rules: 'storage.rules'}} : {}),
    emulators: {
      firestore: {host: '127.0.0.1', port: suite.port},
      ...(suite.storage ? {storage: {host: '127.0.0.1', port: suite.storage}} : {}),
      hub: {host: '127.0.0.1', port: 14400},
      logging: {host: '127.0.0.1', port: 14500},
      ui: {enabled: false}, singleProjectMode: true,
    },
  };
}

function main() {
  const names = process.argv.slice(2);
  for (const name of names.length ? names : Object.keys(suites)) {
    configFor(name); // Reject unknown suite names before creating temporary files.
    const suite = suites[name];
    const directory = mkdtempSync(join(tmpdir(), 'gainpath-emulator-'));
    try {
      const file = join(directory, 'firebase.json');
      // Firebase requires Rules inside the config's project directory. Copy
      // exact checked-in bytes; never rewrite Rules or point at a live project.
      for (const name of ['firestore.rules', 'firestore.indexes.json', 'storage.rules']) {
        copyFileSync(resolve(__dirname, '../../firebase', name), join(directory, name));
      }
      writeFileSync(file, JSON.stringify(configFor(name)));
      console.log(`Running ${name}: ${suite.tests.length} files on ${suite.project}`);
      const pathKey = Object.keys(process.env).find(key => key.toUpperCase() === 'PATH') ?? 'PATH';
      const result = spawnSync(process.execPath, [require.resolve('firebase-tools/lib/bin/firebase.js'),
        'emulators:exec', '--project', suite.project, '--config', file,
        '--only', suite.storage ? 'firestore,storage' : 'firestore',
        'vitest run --config vitest.emulator.config.ts'], {
        cwd: resolve(__dirname, '..'), stdio: 'inherit',
        env: {...process.env, GAINPATH_EMULATOR_SUITE: name,
          [pathKey]: `${resolve(__dirname, '../node_modules/.bin')}${delimiter}${process.env[pathKey] ?? ''}`},
      });
      if (result.error) throw result.error;
      if (result.status !== 0) return result.status ?? 1;
    } finally {
      rmSync(directory, {recursive: true, force: true});
    }
  }
  return 0;
}
module.exports = {suites, configFor};
if (require.main === module) process.exitCode = main();
