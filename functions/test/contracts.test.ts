import { readFileSync } from 'node:fs';
import Ajv from 'ajv';
import { expect, it } from 'vitest';
import { parseCreateBookingHold } from '../src/platform/validation';
import type { SubmitWorkoutSessionV1 } from '../src/modules/workouts/contracts';

const read = (path: string) => JSON.parse(readFileSync(`../contracts/${path}`, 'utf8'));
const ajv = new Ajv({ allErrors: true });
const booking = read('fixtures/create-booking-hold.v1.json');
const workout: SubmitWorkoutSessionV1 = read('fixtures/submit-workout-session.v1.json');
const validateBooking = ajv.compile(read('v1/create-booking-hold.request.schema.json'));
const validateWorkout = ajv.compile(read('v1/submit-workout-session.request.schema.json'));

it('accepts the shared booking fixture with both schema and production parser', () => {
  expect(validateBooking(booking)).toBe(true);
  expect(parseCreateBookingHold(booking)).toEqual(booking);
});
it.each([
  { requestId: 'bad/path' }, { organizationId: '..' }, { memberId: '' }, { schemaVersion: 2 },
  { startAtMillis: 1.1 }, { durationMinutes: 45 }, { checkoutPrice: 1 }, { branchId: ' branch ' },
])('rejects invalid booking payload consistently: %j', change => {
  const candidate = { ...booking, ...change };
  expect(validateBooking(candidate)).toBe(false);
  expect(() => parseCreateBookingHold(candidate)).toThrow();
});
it('accepts the versioned bounded workout summary seam', () => {
  expect(validateWorkout(workout)).toBe(true);
});
it.each([{ rawFrames: [] }, { repetitions: -1 }, { formScorePercent: 101 },
  { trackedDurationMillis: 86400001 }, { consentVersion: '' }, { memberId: 'other/path' }])(
  'rejects raw media and malformed workout summaries: %j', change => {
    expect(validateWorkout({ ...workout, ...change })).toBe(false);
  });
