import { onCall } from 'firebase-functions/v2/https';
import { getCoachRatingsCommand } from './coach-rating-callable';

// Separate opt-in export. Reuse the existing handler, including its validation,
// aggregation and pre/post authorization; retain App Check on the new wrapper.
export const getCoachRatingsPilotCommand = onCall(
  { region: 'asia-southeast1', enforceAppCheck: true },
  getCoachRatingsCommand.run,
);
