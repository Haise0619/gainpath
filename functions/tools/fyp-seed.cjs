#!/usr/bin/env node
// Compile first with `pnpm exec tsc`. No command accepts a live project or deletes records.
const {buildFypDataset, FYP_EMULATOR_PROJECT} = require('../lib/modules/dataset/fyp-dataset');
const {describeFypSeed, guardFypSeed, dryRunFypSeed, applyFypSeed, validateFypSeed, cleanupFypSeedDryRun} = require('../lib/modules/dataset/fyp-seed');
async function main() {
  const args = process.argv.slice(2), mode = args.shift(), allowed = ['plan', 'dry-run', 'apply', 'validate', 'cleanup-dry-run'];
  if (!allowed.includes(mode) || args.length !== 2 || args[0] !== '--anchor') throw Error('Usage: node tools/fyp-seed.cjs plan|dry-run|apply|validate|cleanup-dry-run --anchor 2026-11-03T04:00:00.000Z');
  const anchorMillis = Date.parse(args[1]);
  const dataset = await buildFypDataset({anchorMillis});
  if (mode === 'plan') {process.stdout.write(JSON.stringify(describeFypSeed(dataset), null, 2) + '\n'); return;}
  // Refuse before Firebase initialization. Existing endpoint/project environment is required,
  // never inferred from the owner's saved Firebase CLI account or .firebaserc.
  if (process.env.GCLOUD_PROJECT !== FYP_EMULATOR_PROJECT || process.env.GOOGLE_CLOUD_PROJECT !== FYP_EMULATOR_PROJECT
      || !/^(127\.0\.0\.1|localhost):[1-9][0-9]{0,4}$/.test(process.env.FIRESTORE_EMULATOR_HOST || '')
      || !/^(127\.0\.0\.1|localhost):[1-9][0-9]{0,4}$/.test(process.env.FIREBASE_AUTH_EMULATOR_HOST || '')) throw Error('Dedicated demo-gainpath-fyp Auth/Firestore loopback emulator environment required');
  const {initializeApp, deleteApp} = require('firebase-admin/app');
  const {getAuth} = require('firebase-admin/auth');
  const {getFirestore} = require('firebase-admin/firestore');
  const app = initializeApp({projectId: FYP_EMULATOR_PROJECT}, 'fyp-source-seeder');
  try {
    const options = {firestore: getFirestore(app), auth: getAuth(app), dataset};
    // Force SDK settings to resolve before verifying its effective endpoint.
    options.firestore.settings({ignoreUndefinedProperties: false});
    guardFypSeed(options);
    const run = {'dry-run': dryRunFypSeed, apply: applyFypSeed, validate: validateFypSeed, 'cleanup-dry-run': cleanupFypSeedDryRun}[mode];
    const result = await run(options);
    // Avoid dumping the full historical in-memory source graph or fictional credential assets.
    process.stdout.write(JSON.stringify(result, null, 2) + '\n');
  } finally {await deleteApp(app);}
}
main().catch(error => {process.stderr.write(`${error.message}\n`); process.exitCode = 1;});
