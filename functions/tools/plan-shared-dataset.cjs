#!/usr/bin/env node
// Offline, non-executable planning only. No SDK initialization or apply flag.
const fs = require('node:fs'), path = require('node:path');
const args = process.argv.slice(2);
if (args.length !== 4 || args[0] !== '--anchor' || args[2] !== '--output')
  throw Error('Use --anchor <explicit epoch milliseconds> --output <local JSON path>. No apply/live/deploy mode exists.');
const anchorMillis = Number(args[1]), destination = path.resolve(args[3]);
if (!/^\d+$/.test(args[1]) || !Number.isSafeInteger(anchorMillis)) throw Error('Explicit integer anchor required.');
const {buildSharedDatasetDraft, compareSharedDatasetDraft} = require('../../build/gainpath-shared-data-20261103/compiled/modules/demo/shared-dataset-plan.js');
(async () => {
  const draft = await buildSharedDatasetDraft({anchorMillis});
  if (fs.existsSync(destination)) {
    compareSharedDatasetDraft(JSON.parse(fs.readFileSync(destination, 'utf8')), draft);
  } else {
    fs.mkdirSync(path.dirname(destination), {recursive: true});
    fs.writeFileSync(destination, JSON.stringify(draft, null, 2) + '\n', {flag: 'wx'});
  }
  process.stdout.write(JSON.stringify({status: draft.status, approvalEligible: false, liveApplyEnabled: false,
    target: draft.target, anchorMillis, candidateRecords: draft.records.length, identities: draft.identities.length,
    integrity: draft.integrity, output: destination}) + '\n');
})().catch(e => {process.stderr.write(e.message + '\n'); process.exitCode = 1;});
