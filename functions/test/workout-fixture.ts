export const time = 1790907100000;
export const actor = { uid: 'member-1', token: { email_verified: true } };
export const consentCommand = { schemaVersion: 1, requestId: 'consent-1', organizationId: 'gainpath',
  memberId: actor.uid, consentVersion: 'pose-local-summary-v1', consented: true };
export const tuple = { organizationId: 'gainpath', exerciseId: 'F3b8xIr8ynBDd3gEICKX',
  scoringVersion: 'bodyweight-squat-side-v1', cameraView: 'side', detectorId: 'blazepose-tflite',
  detectorVersion: 'mediapipe-full-e9a5c5cb-det-9ba9dd3d' };
export const submission = { schemaVersion: 2, requestId: 'upload-1', memberId: actor.uid,
  sessionId: 'session-1', ...tuple, provenance: 'real_camera', publishedRoutineId: 'routine-1',
  startedAtMillis: time - 60000, endedAtMillis: time - 1000, repetitions: 8, formScorePercent: 88,
  trackedDurationMillis: 45000, rejectedDurationMillis: 5000,
  consentVersion: 'pose-local-summary-v1', consentAcknowledgementId: 'set-in-test' };
export const workoutSeeds = {
  [`users/${actor.uid}`]: { organizationId: 'gainpath' },
  [`orgs/gainpath/members/${actor.uid}`]: { role: 'member', status: 'active', branchIds: [] },
  [`orgs/gainpath/exerciseVideos/${tuple.exerciseId}`]: { isActive: true },
  'orgs/gainpath/content/routine-1': { schemaVersion: 1, kind: 'routine', status: 'published',
    exercises: [{ exerciseId: tuple.exerciseId, sets: 3, reps: 10 }] },
};