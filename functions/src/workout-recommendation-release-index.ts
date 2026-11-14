/** Scoped Module 2/13 release entrypoint. Deploy only the approved named endpoints. */
import {initializeApp, getApps} from 'firebase-admin/app';
if (!getApps().length) initializeApp();

export {fypDatasetCommand} from './fyp-release-index';
export {module13MemberCommand, module13AdminCommand} from './modules/recommendation/canonical-recommendation-callables';
export {module9MemberCommandCallable} from './modules/coaching/module9-member-callable';
export {module13WorkoutBackupCreated, module13WorkoutConsentChanged} from './modules/recommendation/workout-backup-recommendation-events';
export {module13FypWorkoutBackupCreated, module13FypWorkoutConsentChanged} from './modules/recommendation/fyp-workout-backup-events';
