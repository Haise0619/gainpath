import { DomainError } from '../../platform/errors';
import type { DocumentData, DocumentStore } from '../../platform/firestore/store';
import { keyOf } from '../../platform/idempotency';
import { requireActiveMembership, requireVerifiedEmail } from '../../platform/auth-context';
import { InputValidationError, requiredIdentifier } from '../../platform/validation';
import { tutorialMediaUrl } from './tutorial-media';

export interface PublishRoutineInputV1 {
  readonly schemaVersion: 1;
  readonly requestId: string;
  readonly organizationId: string;
  readonly blueprintId: string;
}

export interface PublishRoutineResultV1 {
  readonly schemaVersion: 1;
  readonly requestId: string;
  readonly contentId: string;
  readonly sourceBlueprintId: string;
  readonly status: 'published';
  readonly publishedAtMillis: number;
}

export function parsePublishRoutine(input: unknown): PublishRoutineInputV1 {
  if (!input || typeof input !== 'object' || Array.isArray(input)) {
    throw new InputValidationError('request data must be an object');
  }
  const value = input as Record<string, unknown>;
  const allowed = ['schemaVersion', 'requestId', 'organizationId', 'blueprintId'];
  if (Object.keys(value).some(key => !allowed.includes(key))) {
    throw new InputValidationError('Unknown publish command field');
  }
  if (value.schemaVersion !== 1) throw new InputValidationError('schemaVersion must be 1');
  return {
    schemaVersion: 1,
    requestId: requiredIdentifier(value.requestId, 'requestId'),
    organizationId: requiredIdentifier(value.organizationId, 'organizationId'),
    blueprintId: requiredIdentifier(value.blueprintId, 'blueprintId'),
  };
}

interface SourceRoutineExercise { exerciseId: string; sets: number; reps: number; }
interface SourceRoutineDay { dayNumber: number; exercises: SourceRoutineExercise[]; }

function parseBlueprint(data: DocumentData | undefined): {
  name: string; estimatedMinutes: number; days: SourceRoutineDay[];
} {
  if (!data) throw new DomainError('not-found', 'Routine blueprint not found.');
  if (data.schemaVersion !== 1 || typeof data.name !== 'string' || !data.name.trim()
    || !Number.isInteger(data.sessionDurationMin) || Number(data.sessionDurationMin) < 5
    || Number(data.sessionDurationMin) > 240 || !Array.isArray(data.days)
    || data.days.length < 1 || data.days.length > 14) {
    throw new DomainError('failed-precondition', 'Routine blueprint is incomplete or invalid.');
  }
  const dayNumbers = new Set<number>();
  let totalExercises = 0;
  const days = data.days.map((value, index) => {
    if (!value || typeof value !== 'object' || Array.isArray(value)) {
      throw new DomainError('failed-precondition', `Day ${index + 1} is invalid.`);
    }
    const day = value as Record<string, unknown>;
    if (Object.keys(day).some(key => !['dayNumber', 'exercises'].includes(key))) {
      throw new DomainError('failed-precondition', `Day ${index + 1} contains unsupported fields.`);
    }
    const dayNumber = day.dayNumber;
    if (!Number.isInteger(dayNumber) || Number(dayNumber) < 1 || Number(dayNumber) > 14
      || dayNumbers.has(Number(dayNumber)) || !Array.isArray(day.exercises)
      || day.exercises.length < 1 || day.exercises.length > 20) {
      throw new DomainError('failed-precondition', `Day ${index + 1} is invalid.`);
    }
    dayNumbers.add(Number(dayNumber));
    totalExercises += day.exercises.length;
    const exercises = day.exercises.map(raw => {
      if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
        throw new DomainError('failed-precondition', 'A routine exercise is invalid.');
      }
      const exercise = raw as Record<string, unknown>;
      if (Object.keys(exercise).some(key => !['exerciseId', 'sets', 'reps'].includes(key))) {
        throw new DomainError('failed-precondition', 'Routine exercises may contain only an exercise ID, sets, and reps.');
      }
      try { requiredIdentifier(exercise.exerciseId, 'exerciseId'); }
      catch { throw new DomainError('failed-precondition', 'A routine exercise has an invalid ID.'); }
      if (!Number.isInteger(exercise.sets) || Number(exercise.sets) < 1 || Number(exercise.sets) > 50
        || !Number.isInteger(exercise.reps) || Number(exercise.reps) < 1 || Number(exercise.reps) > 100) {
        throw new DomainError('failed-precondition', 'Exercise sets and reps must be valid positive whole numbers.');
      }
      return { exerciseId: exercise.exerciseId as string, sets: Number(exercise.sets), reps: Number(exercise.reps) };
    });
    return { dayNumber: Number(dayNumber), exercises };
  });
  if (totalExercises > 50) throw new DomainError('failed-precondition', 'Routine is too large to publish.');
  days.sort((a, b) => a.dayNumber - b.dayNumber);
  return { name: data.name.trim(), estimatedMinutes: Number(data.sessionDurationMin), days };
}

export async function publishRoutine(
  store: DocumentStore,
  auth: { uid: string; token: Record<string, unknown> } | undefined,
  rawInput: unknown,
  clock: () => number = Date.now,
): Promise<PublishRoutineResultV1> {
  requireVerifiedEmail(auth);
  const actorId = requiredIdentifier(auth!.uid, 'actorId');
  const input = parsePublishRoutine(rawInput);
  const org = `orgs/${input.organizationId}`;
  const receiptPath = `${org}/commandReceipts/${keyOf('publishRoutine', actorId, input.requestId)}`;
  const fingerprint = keyOf(input);
  const contentId = `routine_${input.blueprintId}`;
  const contentPath = `${org}/content/${contentId}`;

  return store.transact(async tx => {
    const [user, membershipData, receipt] = await Promise.all([
      tx.get(`users/${actorId}`),
      tx.get(`${org}/members/${actorId}`),
      tx.get(receiptPath),
    ]);
    if (user?.organizationId !== input.organizationId) {
      throw new DomainError('permission-denied', 'The account is not assigned to this organization.');
    }
    const membership = requireActiveMembership(membershipData);
    if (!['admin', 'staff'].includes(membership.role)) {
      throw new DomainError('permission-denied', 'Only organization Admin or Staff can publish routines.');
    }
    if (receipt) {
      if (receipt.fingerprint !== fingerprint) {
        throw new DomainError('already-exists', 'requestId was used with a different publish command.');
      }
      return receipt.result as unknown as PublishRoutineResultV1;
    }

    const blueprint = parseBlueprint(await tx.get(`${org}/routineBlueprints/${input.blueprintId}`));
    const exerciseIds = [...new Set(blueprint.days.flatMap(day => day.exercises.map(exercise => exercise.exerciseId)))];
    const sourceExercises = await Promise.all(exerciseIds.map(id => tx.get(`${org}/exerciseVideos/${id}`)));
    const exerciseById = new Map<string, DocumentData>();
    exerciseIds.forEach((id, index) => {
      const data = sourceExercises[index];
      if (!data || data.isActive !== true || typeof data.exerciseName !== 'string' || !data.exerciseName.trim()
        || typeof data.muscleCategory !== 'string' || !data.muscleCategory.trim()) {
        throw new DomainError('failed-precondition', `Exercise ${id} is missing or inactive.`);
      }
      exerciseById.set(id, data);
    });
    const exercises = blueprint.days.flatMap(day => day.exercises.map(exercise => {
      const source = exerciseById.get(exercise.exerciseId)!;
      const videoUrl = tutorialMediaUrl(source.videoUrl);
      return {
        exerciseId: exercise.exerciseId,
        name: (source.exerciseName as string).trim(),
        category: (source.muscleCategory as string).trim(),
        muscleGroup: (source.muscleCategory as string).trim(),
        sets: exercise.sets,
        reps: exercise.reps,
        dayNumber: day.dayNumber,
        ...(videoUrl ? { videoUrl } : {}),
      };
    }));
    const publishedAtMillis = clock();
    const result: PublishRoutineResultV1 = {
      schemaVersion: 1,
      requestId: input.requestId,
      contentId,
      sourceBlueprintId: input.blueprintId,
      status: 'published',
      publishedAtMillis,
    };
    tx.set(contentPath, {
      schemaVersion: 1,
      kind: 'routine',
      status: 'published',
      sourceBlueprintId: input.blueprintId,
      title: blueprint.name,
      estimatedMinutes: blueprint.estimatedMinutes,
      exercises,
      publishedAtMillis,
      updatedAtMillis: publishedAtMillis,
    });
    tx.create(receiptPath, { fingerprint, result, createdAtMillis: publishedAtMillis });
    return result;
  });
}
