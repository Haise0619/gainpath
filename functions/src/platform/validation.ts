import type { CommandV1 } from './command';
export type BookingDurationMinutes = 30 | 60;

export interface CreateBookingHoldInput extends CommandV1 {
  readonly branchId: string;
  readonly coachId: string;
  readonly memberId: string;
  readonly startAtMillis: number;
  readonly durationMinutes: BookingDurationMinutes;
}

export class InputValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'InputValidationError';
  }
}

export function requiredIdentifier(value: unknown, name: string): string {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(value)) {
    throw new InputValidationError(`${name} must use 1-128 letters, digits, underscores or hyphens`);
  }
  return value;
}

export function parseCreateBookingHold(input: unknown): CreateBookingHoldInput {
  if (input === null || typeof input !== 'object' || Array.isArray(input)) {
    throw new InputValidationError('request data must be an object');
  }
  const value = input as Record<string, unknown>;
  if (value.schemaVersion !== 1) throw new InputValidationError('schemaVersion must be 1');
  const keys = ['schemaVersion', 'requestId', 'organizationId', 'branchId', 'coachId', 'memberId', 'startAtMillis', 'durationMinutes'];
  if (Object.keys(value).some(key => !keys.includes(key))) throw new InputValidationError('Unknown command field');
  const duration = value.durationMinutes;
  if (duration !== 30 && duration !== 60) {
    throw new InputValidationError('durationMinutes must be 30 or 60');
  }
  if (
    typeof value.startAtMillis !== 'number' ||
    !Number.isSafeInteger(value.startAtMillis) ||
    value.startAtMillis <= 0 || value.startAtMillis > 8640000000000000 - 3600000
  ) {
    throw new InputValidationError('startAtMillis must be a positive integer');
  }
  return {
    schemaVersion: 1,
    requestId: requiredIdentifier(value.requestId, 'requestId'),
    organizationId: requiredIdentifier(value.organizationId, 'organizationId'),
    branchId: requiredIdentifier(value.branchId, 'branchId'),
    coachId: requiredIdentifier(value.coachId, 'coachId'),
    memberId: requiredIdentifier(value.memberId, 'memberId'),
    startAtMillis: value.startAtMillis,
    durationMinutes: duration,
  };
}
