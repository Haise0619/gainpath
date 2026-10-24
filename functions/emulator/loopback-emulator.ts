/** Fail before initializing Admin or deleting fixtures unless the endpoint is
 * explicitly local. Demo project IDs in each test keep namespaces isolated. */
export function localFirestoreEmulator() {
  const authority = process.env.FIRESTORE_EMULATOR_HOST;
  const match = /^127\.0\.0\.1:(\d{1,5})$/.exec(authority ?? '');
  const port = Number(match?.[1]);
  if (!match || port < 1024 || port > 65535) throw Error('An explicit local loopback Firestore emulator is required.');
  return { authority: authority!, host: '127.0.0.1', port };
}
