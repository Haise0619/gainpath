// Runs one authorized FYP source batch through the existing callable.
const assert = require('node:assert/strict');
const {client} = require('./module13-presentation-walkthrough.cjs');

async function main() {
  const batch = process.argv[2];
  assert(process.argv.length === 3 && /^[a-zA-Z0-9_-]{1,64}$/.test(batch ?? ''),
    'Provide a stable source batch ID. Reuse it when retrying the same batch.');
  const connection = await client();
  try {
    for (const kind of ['content', 'trainer']) {
      let continuation = null;
      for (let page = 0; page < 11; page++) {
        const result = await connection.call('demo-m13-admin', 'admin.queue.automatic', {
          schemaVersion: 1, organizationId: 'gainpath',
          kind, commandId: 'automatic-' + batch + '-' + kind, continuation,
        });
        continuation = result.summary.nextCursor;
        if (result.summary.status === 'complete') {
          console.log(JSON.stringify({kind, ...result.delivery}));
          break;
        }
        if (result.summary.status !== 'in_progress' || !continuation || page === 10) {
          throw Error('Automatic generation did not finish. Inspect the existing run before retrying.');
        }
      }
    }
  } finally {
    await connection.close();
  }
}

if (require.main === module) {
  main().catch(error => {
    console.error('FYP automatic batch stopped (' + (error.code ?? 'precondition') + ').');
    process.exitCode = 1;
  });
}
