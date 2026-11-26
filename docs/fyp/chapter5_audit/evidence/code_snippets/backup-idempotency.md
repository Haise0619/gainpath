# Workout backup write transaction

Source functions/src/modules/workouts/workout-backup.ts:48–77. Contiguous excerpt. Surrounding code omitted.

```ts
  if (v.baseDigest !== null && (typeof v.baseDigest !== 'string' || !/^[a-f0-9]{64}$/.test(v.baseDigest))) {
    throw new InputValidationError('Invalid base revision.');
  }
  const key = kind+'-'+id, path = `orgs/${org}/members/${uid}/workoutBackups/${key}`;
  return store.transact(async tx => {
    await member(tx,auth!,org,uid);
    const previous = await tx.get(path);
    if (previous?.digest === digest) return {schemaVersion:1,status:'backed_up',kind,id,digest};
    if ((previous && (kind === 'session' || previous.digest !== v.baseDigest)) ||
        (!previous && v.baseDigest !== null)) {
      throw new DomainError('already-exists','Backup conflict. Both copies are retained.');
    }
    const revision = await tx.get(path+'/revisions/'+digest);
    const record = {schemaVersion:1,kind,id,key,digest,payloadJson:JSON.stringify(payload),
      classification:'provisional_member_backup',updatedAtMillis:Date.now()};
    if (!revision) tx.create(path+'/revisions/'+digest,record);
    tx.set(path,record);
    return {schemaVersion:1,status:'backed_up',kind,id,digest};
  });
}
export async function listWorkoutBackups(store: BackupStore, auth: WorkoutAuth | undefined, raw: unknown) {
  const {v,org,uid} = input(auth,raw,false);
  const routineMaximum=v.schemaVersion===2?v.maxRoutineCheckpointSchemaVersion:1;
  if(![1,2].includes(Number(routineMaximum))) throw new InputValidationError('Invalid supported routine checkpoint version.');
  // Existing clients understand metric schemas 1/2 and send no negotiation.
  const maximum = 'maxPoseMetricsSchemaVersion' in v ? v.maxPoseMetricsSchemaVersion : 2;
  if (!Number.isSafeInteger(maximum) || Number(maximum) < 2 || Number(maximum) > 7) {
    throw new InputValidationError('Invalid supported pose metric version.');
  }
  const after = v.after === null ? null : String(v.after);
```

Scoped deterministic key and canonical digest support safe retries and reject conflicting prior data.
