import { onCall } from 'firebase-functions/v2/https';
import { getBookingListCommand } from './booking-read-callables';
import { getCoachAvailabilityCommand } from './coach-availability-callables';

// Prepared replacements only. Retain the existing US endpoints for rollback;
// these separate reads require deployment, IAM and live parity verification
// before any client routing changes. Never export financial mutations here.
const options = { region: 'asia-southeast1', enforceAppCheck: true, preserveExternalChanges: true } as const;
export const getBookingListReadCommand = onCall(options, getBookingListCommand.run);
export const getCoachAvailabilityReadCommand = onCall(options, getCoachAvailabilityCommand.run);
