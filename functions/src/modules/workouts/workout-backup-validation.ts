import { createHash } from 'node:crypto';
import { InputValidationError, requiredIdentifier } from '../../platform/validation';
export function object(raw: unknown): Record<string, unknown> { if (!raw || typeof raw !== 'object' || Array.isArray(raw))
    throw new InputValidationError('Expected object.'); return raw as Record<string, unknown>; }
export function keys(raw: Record<string, unknown>, allowed: string[], required = allowed): void { if (Object.keys(raw).some(k => !allowed.includes(k)) || required.some(k => !(k in raw)))
    throw new InputValidationError('Unexpected backup fields.'); }
function number(value: unknown, max = Number.MAX_SAFE_INTEGER): number { if (!Number.isSafeInteger(value) || Number(value) < 0 || Number(value) > max)
    throw new InputValidationError('Invalid backup number.'); return Number(value); }
function text(value: unknown, max = 8000): string { if (typeof value !== 'string' || value.length > max || value.includes('\u0000'))
    throw new InputValidationError('Invalid backup text.'); return value; }
function array(value: unknown, max: number): unknown[] { if (!Array.isArray(value) || value.length > max)
    throw new InputValidationError('Invalid backup list.'); return value; }
function idsMap(raw: unknown, lists = false): void { for (const [k, v] of Object.entries(object(raw))) {
    if (!/^\d{1,2}$/.test(k) || Number(k) > 49)
        throw new InputValidationError('Invalid entry index.');
    if (lists)
        array(v, 1000).forEach(x => requiredIdentifier(x, 'sessionId'));
    else if (typeof v === 'number')
        number(v, 50);
    else
        requiredIdentifier(v, 'sessionId');
} }
function nullableNumber(v: unknown, max = 100): void { if (v !== null && (typeof v !== 'number' || !Number.isFinite(v) || v < 0 || v > max))
    throw new InputValidationError('Invalid backup score.'); }
function metrics(raw: unknown): void { const m = object(raw); const fields = ['schemaVersion', 'partialRepetitions', 'trackedDurationMicros', 'rejectedDurationMicros', 'formScorePercent', 'scoringVersion', 'detectorId', 'detectorVersion', 'cameraView', 'consentVersion', 'consentedAt', 'publishedRoutineId', 'deviations']; if (m.schemaVersion === 2)
    fields.push('curlArms'); keys(m, fields); if (![1, 2].includes(Number(m.schemaVersion)))
    throw new InputValidationError('Invalid metric version.'); for (const k of ['partialRepetitions', 'trackedDurationMicros', 'rejectedDurationMicros'])
    number(m[k]); nullableNumber(m.formScorePercent); for (const k of ['scoringVersion', 'detectorId', 'detectorVersion', 'cameraView', 'consentVersion', 'consentedAt'])
    text(m[k], 256); if (m.publishedRoutineId !== null)
    requiredIdentifier(m.publishedRoutineId, 'routine'); const deviations = object(m.deviations); keys(deviations, ['trunkLean', 'incompleteDepth'], []); for (const d of Object.values(deviations)) {
    const a = object(d);
    keys(a, ['count', 'maximumDegrees']);
    number(a.count, 10000);
    nullableNumber(a.maximumDegrees, 180);
} if (m.schemaVersion === 2) {
    const a = object(m.curlArms);
    keys(a, ['mode', 'targetSets', 'repetitionsPerArm', 'completedSets', 'left', 'right']);
    if (!['both', 'leftOnly', 'rightOnly'].includes(String(a.mode)))
        throw new InputValidationError('Invalid arm mode');
    for (const k of ['targetSets', 'repetitionsPerArm', 'completedSets'])
        number(a[k], 1000);
    for (const k of ['left', 'right']) {
        const r = object(a[k]);
        keys(r, ['repetitions', 'partialRepetitions', 'formScorePercent']);
        number(r.repetitions, 10000);
        number(r.partialRepetitions, 10000);
        nullableNumber(r.formScorePercent);
    }
} }
function plan(raw: unknown): void { const p = object(raw); const required=['schemaVersion', 'kind', 'status', 'sourceBlueprintId', 'title', 'estimatedMinutes', 'exercises']; keys(p, [...required,'difficulty'],required); if (p.difficulty!==undefined&&!['Beginner','Intermediate','Advanced'].includes(String(p.difficulty)))throw new InputValidationError('Invalid routine difficulty'); if (p.schemaVersion !== 1 || p.kind !== 'routine' || p.status !== 'published')
    throw new InputValidationError('Invalid plan snapshot'); text(p.sourceBlueprintId, 128); text(p.title, 500); number(p.estimatedMinutes, 10000); for (const rawE of array(p.exercises, 50)) {
    const e = object(rawE);
    keys(e, ['exerciseId', 'dayNumber', 'name', 'category', 'sets', 'reps', 'cue', 'imageUrl', 'muscleGroup', 'videoUrl', 'description', 'coverImageUrl', 'difficulty', 'equipment', 'tutorialSteps']);
    requiredIdentifier(e.exerciseId, 'exerciseId');
    for (const k of ['dayNumber', 'sets', 'reps'])
        number(e[k], 10000);
    for (const [k, v] of Object.entries(e))
        if (!['dayNumber', 'sets', 'reps', 'tutorialSteps'].includes(k))
            text(v, 8000);
    for (const k of ['imageUrl', 'videoUrl', 'coverImageUrl']) {
        const v = String(e[k]);
        if (v !== '' && !v.startsWith('https://'))
            throw new InputValidationError('Only HTTPS media references are allowed.');
    }
    for (const rawS of array(e.tutorialSteps, 12)) {
        const s = object(rawS);
        keys(s, ['title', 'description', 'imageUrl']);
        text(s.title, 80);
        text(s.description, 1200);
        const image = text(s.imageUrl, 2048);
        if (image && !image.startsWith('https://'))
            throw new InputValidationError('Invalid image reference.');
    }
} }
export function validateBackupPayload(kind: string, id: string, org: string, uid: string, raw: unknown): Record<string, unknown> { const p = object(raw); if (p.userId !== uid || p.organizationId !== org)
    throw new InputValidationError('Backup owner mismatch.'); if (kind === 'session') {
    keys(p, ['sessionId', 'userId', 'organizationId', 'exerciseId', 'repetitions', 'accuracy', 'startedAt', 'endedAt', 'summarySchemaVersion', 'provenance', 'poseMetrics']);
    if (p.sessionId !== id || p.summarySchemaVersion !== 3 || p.provenance !== 'realCamera')
        throw new InputValidationError('Only measured local summaries can be backed up.');
    requiredIdentifier(p.exerciseId, 'exercise');
    number(p.repetitions, 10000);
    number(p.accuracy, 100);
    const start = Date.parse(text(p.startedAt, 64)), end = Date.parse(text(p.endedAt, 64));
    if (!Number.isFinite(start) || !Number.isFinite(end) || end < start || end - start > 86400000)
        throw new InputValidationError('Invalid summary times');
    metrics(p.poseMetrics);
    const m=object(p.poseMetrics),attempts=Number(p.repetitions)+Number(m.partialRepetitions);
    if(attempts>10000||Number(m.trackedDurationMicros)+Number(m.rejectedDurationMicros)>(end-start)*1000||Date.parse(String(m.consentedAt))>start||!Number.isFinite(Date.parse(String(m.consentedAt)))||(attempts===0&&m.formScorePercent!==null)||(m.trackedDurationMicros===0&&p.repetitions!==0))throw new InputValidationError('Inconsistent backup summary.');
}
else if (kind === 'routine') {
    keys(p, ['schemaVersion', 'id', 'organizationId', 'userId', 'routineId', 'planSignature', 'day', 'selectedIndex', 'updatedAtMicros', 'finished', 'startedAtMicros', 'attempt', 'sessions', 'pending', 'manualSets', 'reviewed', 'skipped']);
    if (p.schemaVersion !== 1 || p.id !== id || typeof p.finished !== 'boolean')
        throw new InputValidationError('Invalid checkpoint');
    requiredIdentifier(p.routineId, 'routine');
    text(p.planSignature, 32768);
    for (const k of ['day', 'selectedIndex', 'updatedAtMicros'])
        number(p[k]);
    if (p.startedAtMicros !== null)
        number(p.startedAtMicros);
    idsMap(p.sessions, true);
    idsMap(p.pending);
    idsMap(p.manualSets);
    for(const value of Object.values(object(p.manualSets)))number(value,50);
    for(const value of Object.values(object(p.pending)))requiredIdentifier(value,'session');
    array(p.reviewed, 50).forEach(x => number(x, 49));
    array(p.skipped, 50).forEach(x => number(x, 49));
    const a = object(p.attempt);
    keys(a, ['schemaVersion', 'id', 'organizationId', 'userId', 'routineId', 'routine', 'day', 'finished', 'startedAtMicros', 'finishedAtMicros', 'updatedAtMicros', 'entries']);
    if (a.schemaVersion !== 1 || a.id !== id || a.organizationId !== org || a.userId !== uid || a.routineId !== p.routineId || a.day !== p.day || a.finished !== p.finished || a.startedAtMicros !== p.startedAtMicros)
        throw new InputValidationError('Attempt identity mismatch');
    for (const k of ['startedAtMicros', 'finishedAtMicros'])
        if (a[k] !== null)
            number(a[k]);
    number(a.updatedAtMicros);
    if(Number(a.updatedAtMicros)>Number(p.updatedAtMicros)||p.day===0||Number(p.selectedIndex)>49|| (a.finishedAtMicros!==null&&(a.finished!==true||a.startedAtMicros===null||Number(a.finishedAtMicros)<Number(a.startedAtMicros))))throw new InputValidationError('Invalid attempt chronology.');
    plan(a.routine);
    const exercises=array(object(a.routine).exercises,50).map(object);
    const expected=exercises.map((e,i)=>e.dayNumber===p.day?i:-1).filter(i=>i>=0);
    const entries=array(a.entries,50).map(object);
    if(expected.length===0||JSON.stringify(entries.map(e=>e.index))!==JSON.stringify(expected)||!expected.includes(Number(p.selectedIndex)))throw new InputValidationError('Attempt entries do not match routine day.');
    const captures=entries.flatMap(e=>array(e.sessionIds,1000));
    if(new Set(captures).size!==captures.length||entries.some(e=>Number(e.manualSets)>Number(exercises[Number(e.index)].sets)))throw new InputValidationError('Invalid entry evidence.');

    for (const rawE of array(a.entries, 50)) {
        const e = object(rawE);
        keys(e, ['index', 'status', 'sessionIds', 'fullRepetitions', 'partialRepetitions', 'trackedDurationMicros', 'manualSets']);
        if (!['notStarted', 'partial', 'completed', 'selfReportedPartial', 'selfReportedCompleted', 'instructionsReviewed', 'skipped'].includes(String(e.status)))
            throw new InputValidationError('Invalid result status');
        for (const k of ['index', 'fullRepetitions', 'partialRepetitions', 'trackedDurationMicros', 'manualSets'])
            number(e[k]);
        if(Number(e.index)>49||Number(e.manualSets)>50)throw new InputValidationError('Invalid entry limits.');
        array(e.sessionIds, 1000).forEach(x => requiredIdentifier(x, 'session'));
    }
}
else
    throw new InputValidationError('Invalid backup kind'); const json = canonical(p); if (Buffer.byteLength(json, 'utf8') > 850000)
    throw new InputValidationError('Backup record is too large.'); return p; }
// Used for hashing only, not JSON storage; preserves every finite numeric bit.
export function canonical(value: unknown): string {
 if(Array.isArray(value))return '['+value.map(canonical).join(',')+']';
 if(value&&typeof value==='object')return '{'+Object.entries(value).sort(([a],[b])=>a<b?-1:a>b?1:0).map(([k,v])=>JSON.stringify(k)+':'+canonical(v)).join(',')+'}';
 if(typeof value==='number'){if(!Number.isFinite(value))throw new InputValidationError('Invalid backup number');const bytes=Buffer.alloc(8);bytes.writeDoubleBE(value===0?0:value);return 'n'+bytes.toString('hex');}
 return JSON.stringify(value);
}
export const digestOf = (value: unknown): string => createHash('sha256').update(canonical(value)).digest('hex');
