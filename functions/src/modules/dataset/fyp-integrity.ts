import {createHash} from 'node:crypto';
/** Timestamp normalization makes source Date and Firestore Timestamp readbacks identical. */
function canonical(value: unknown): unknown {
  if (value instanceof Date) return {$timestampMillis: value.getTime()};
  if (value && typeof value === 'object' && 'toMillis' in value && typeof value.toMillis === 'function') return {$timestampMillis: value.toMillis()};
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === 'object') return Object.fromEntries(Object.entries(value).sort(([a], [b]) => a.localeCompare(b)).map(([k, v]) => [k, canonical(v)]));
  return value;
}
export function fypDigest(value: unknown): string {return createHash('sha256').update(JSON.stringify(canonical(value))).digest('hex');}
