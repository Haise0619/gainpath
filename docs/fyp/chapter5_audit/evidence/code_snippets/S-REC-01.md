# S-REC-01 — createWorkoutBackupRuntime

Chapter section 5.1.4.9. Source `functions/src/modules/recommendation/workout-backup-recommendation-runtime.ts:354–373`. Related regression `functions/test/workout-backup-recommendations.test.ts`.

Source and compatibility checks produce a bounded evidence set and a deterministic educational objective. Surrounding source omitted.

```ts
      const backups = `${root}/members/${member}/workoutBackups`;
      const source = await readWorkoutSource(tx, org, member, key, now, boundary, cohortRoot);
      if (!source) return [];
      const history = await db.collection(physical(backups)).orderBy('updatedAtMillis', 'desc').limit(32).get();
      const observed = cohortRoot ? (await db.collection(`${cohortRoot}/members/${member}/syntheticObservations`)
        .orderBy('observedAtMillis', 'desc').limit(32).get()).docs : [];
      const historyKeys = new Set([...history.docs.map(row => row.id), ...observed.map(row => 'session-' + row.id)]);
      const recent = [source];
      const allRecent=[source];
      for (const historyKey of historyKeys) {
        if (historyKey === key) continue;
        const other = await readWorkoutSource(tx, org, member, historyKey, now, boundary, cohortRoot);
        if(other && other.ended<=source.ended)allRecent.push(other);
        if (other?.exercise === source.exercise && other.ended <= source.ended) recent.push(other);
      }
      const scored = recent.filter(s => s.compatibility === source.compatibility && s.score !== null).sort((a, b) => b.ended - a.ended).slice(0, 5);
      const mean = scored.length >= 2 ? scored.reduce((sum, s) => sum + s.score!, 0) / scored.length : null;
      const objective = mean !== null && mean < 65 ? 'movement_control' :
        mean !== null && mean >= 85 ? 'progression' : 'technique_foundations';
      const catalog = await tx.get(`${root}/exerciseVideos/${source.exercise}`);
```
