/** Fail before initializing Admin or deleting fixtures unless the endpoint is
 * explicitly local. Demo project IDs in each test keep namespaces isolated. */
export function localFirestoreEmulator() {
  const authority = process.env.FIRESTORE_EMULATOR_HOST;
  const match = /^127\.0\.0\.1:(\d{1,5})$/.exec(authority ?? '');
  const port = Number(match?.[1]);
  if (!match || port < 1024 || port > 65535) throw Error('An explicit local loopback Firestore emulator is required.');
  return { authority: authority!, host: '127.0.0.1', port };
}

/** Start all fixture requests together, then replay only the exact stale
 * transaction response from the emulator (googleapis/google-cloud-node#9693).
 * A real concurrent winner is required before any retry is allowed.
 */
export async function settleConcurrentEmulatorRequests<T>(
  operations: readonly (() => Promise<T>)[],
): Promise<PromiseSettledResult<T>[]> {
  const results = await Promise.allSettled(operations.map(async run => run()));
  if (!results.some(result => result.status === 'fulfilled')) return results;

  for (const [index, result] of results.entries()) {
    if (result.status !== 'rejected') continue;
    const error: unknown = result.reason;
    if (error instanceof Error && 'code' in error && error.code === 3 &&
        'details' in error && error.details === 'Transaction is invalid or closed.') {
      const [replay] = await Promise.allSettled([Promise.resolve().then(operations[index])]);
      results[index] = replay;
    }
  }
  return results;
}
