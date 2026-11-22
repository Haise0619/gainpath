/** Bounded independent reads. Each worker retains the caller's authorization
 * and validation. No response is returned until its entire batch completes. */
export async function forEachReportBatch<T>(
  values: readonly T[],
  read: (value: T) => Promise<void>,
): Promise<void> {
  for (let offset = 0; offset < values.length; offset += 4) {
    await Promise.all(values.slice(offset, offset + 4).map(read));
  }
}
