# QA-01 — Immutable backup conflict assertion

Source functions/test/workout-backup.test.ts:34–34. Contiguous excerpt. Surrounding fixture setup omitted.

~~~ts
it('conflicting immutable session preserves existing backup', async () => { const a = await backupWorkout(store, actor, command); await expect(backupWorkout(store, actor, { ...command, baseDigest: a.digest, payload: { ...payload, repetitions: 3 } })).rejects.toMatchObject({ code: 'already-exists' }); expect((await listWorkoutBackups(store, actor, { schemaVersion: 1, organizationId: 'gainpath', memberId: 'member', consented: true, after: null })).records[0].digest).toBe(a.digest); });
~~~

The test submits one record, attempts an incompatible update to the same immutable session, expects a conflict, then checks that the previously stored digest survives.
