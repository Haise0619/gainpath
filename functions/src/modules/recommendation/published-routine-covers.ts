import type {TransactionPort} from '../../platform/firestore/store';
import {DomainError} from '../../platform/errors';
import {keys} from '../workouts/workout-backup-validation';

function cover(value: unknown): string | undefined {
  if (typeof value !== 'string' || value.length > 2048) return;
  try {
    const url = new URL(value);
    if (url.protocol === 'https:' && !url.username && !url.password && !url.hash) return value;
  } catch { return; }
}

export async function readPublishedRoutineCovers(tx: TransactionPort, org: string, data: Record<string, unknown>) {
  keys(data, ['schemaVersion','organizationId','routineIds']);
  const ids = data.routineIds;
  if (data.schemaVersion !== 1 || !Array.isArray(ids) || ids.length > 25 ||
      ids.some(id => typeof id !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(id))) {
    throw new DomainError('invalid-argument', 'Invalid routine cover query.');
  }
  const root = 'orgs/' + org;
  const entries = await Promise.all([...new Set(ids as string[])].map(async id => {
    const routine = await tx.get(root + '/content/' + id);
    if (!routine || routine.status !== 'published' || routine.archived === true || routine.isActive === false ||
        !['routine','routine_v2'].includes(String(routine.kind))) return null;
    const published = cover(routine.coverImageUrl) ?? cover(routine.imageUrl);
    if (published) return [id, published];
    const source = routine.sourceBlueprintId;
    if (typeof source !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(source)) return null;
    const collection = routine.kind === 'routine_v2' ? 'routineBlueprintsV2' : 'routineBlueprints';
    const blueprint = await tx.get(root + '/' + collection + '/' + source);
    const image = cover(blueprint?.imageUrl);
    return image ? [id, image] : null;
  }));
  return Object.fromEntries(entries.filter(entry => entry !== null));
}
