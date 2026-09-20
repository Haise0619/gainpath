import { createHash } from 'node:crypto';
// Tuple encoding avoids ambiguous underscore-delimited composite keys.
export function keyOf(...parts: readonly unknown[]): string {
  return createHash('sha256').update(JSON.stringify(parts)).digest('hex');
}
