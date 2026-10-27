import { initializeApp } from 'firebase-admin/app';

initializeApp();

export { getMembershipOverviewCommand, getMembershipQuoteCommand, createMembershipPaymentCommand, getMembershipPaymentCommand, requestMembershipRefundCommand } from './modules/commerce/membership-payment-callables';
export { getMembershipAccessCommand, verifyMemberMembershipCommand } from './modules/commerce/membership-access-callables';
export { verifiedRewardsCommand } from './modules/gamification/verified-rewards-callables';

export { bookingConsultationNotesCommand } from './modules/coaching/booking-consultation-callable';

export { bookingCommunicationCommand } from './modules/coaching/booking-communication-callable';

export { createBookingHold } from './modules/coaching/create-booking-hold';
export { memberBookingChangeCommand } from './modules/coaching/member-booking-change-callable';
export { getMemberBookingOptionsCommand } from './modules/coaching/member-booking-options-callable';
export { getBookingListCommand } from './modules/coaching/booking-read-callables';
export { cancelBookingHoldCommand } from './modules/coaching/booking-lifecycle-callable';
export { cancelAssignedBookingCommand } from './modules/coaching/coach-booking-cancellation-callable';
export { expireBookingHolds } from './modules/coaching/booking-expiry-worker';
export { saveCoachProfileCommand, setCoachDirectoryStatusCommand } from './modules/coaching/coach-profile-callables';
export { getCoachAvailabilityCommand, saveCoachAvailabilityDayCommand } from './modules/coaching/coach-availability-callables';
export { getCoachRosterCommand, saveCoachRosterCommand } from './modules/coaching/coach-availability-callables';
export { paymentWebhook } from './modules/commerce/payment-webhook';
export { getBookingPaymentQuoteCommand, createBookingPaymentCommand, getBookingPaymentCommand, billplzSandboxReturn } from './modules/commerce/booking-payment-callables';
export { listAdminBookingPaymentsCommand, getAdminBookingPaymentCommand, manageAdminBookingPaymentCommand } from './modules/commerce/booking-payment-admin-callables';
export { provisionMemberRegistration } from './modules/identity/provision-member-registration';
export { getMemberAccountLifecycleCommand, requestMemberDeactivationCommand, cancelMemberDeactivationCommand } from './modules/identity/member-account-lifecycle-callables';
export { publishRoutineCommand } from './modules/content/publish-routine-callable';
export { acknowledgeWorkoutConsentCommand, revokeWorkoutConsentCommand, submitWorkoutSessionCommand } from './modules/workouts/workout-callables';

export { submitCoachCertificationCommand, archiveCoachCertificationCommand, reviewCoachCertificationCommand, getCoachCertificationsCommand, getCoachAccountSettingsCommand, saveCoachAccountSettingsCommand } from './modules/coaching/coach-management-callables';
export { getCoachPublishedPhotoCommand } from './modules/coaching/coach-management-callables';
export { getClientPostureHistoryCommand } from './modules/coaching/client-posture-callable';
export { submitBookingReviewCommand } from './modules/coaching/booking-review-callable';

export { deliverBookingNotifications } from './modules/coaching/booking-notification-worker';
export { identifyEquipmentCommand } from './modules/workouts/equipment-scanner-callable';

export { module9MemberCommandCallable } from './modules/coaching/module9-member-callable';
export { getCoachPerformanceCommand } from './modules/coaching/coach-performance-callable';
export { getCoachRatingsCommand } from './modules/coaching/coach-rating-callable';
// Local read-only regional pilot; deploy only this export after explicit approval.
export { getCoachRatingsPilotCommand } from './modules/coaching/coach-rating-pilot-callable';
export { getBookingListReadCommand, getCoachAvailabilityReadCommand } from './modules/coaching/regional-booking-reads';

export { fitnessAssistantCommand } from './modules/chatbot/chatbot-callable';

// Prepared only; deployment requires explicit owner approval.
export {googleGymConnectionCommand,googleGymOAuthCallback,syncGymBookingCommand} from './modules/coaching/google-gym-callables';
// Prepared locally; no automatic delivery until selective deployment and activation approval.
export {synchronizeGoogleBooking} from './modules/coaching/automatic-google-worker';

// Prepared workout backup only; selective deployment requires owner approval.
export { workoutBackupCommand } from './modules/workouts/workout-backup-callable';

// Prepared basic app check-in only; policy/deployment need explicit approval.
export { appCheckInCommand } from './modules/gamification/app-check-in-callable';

// Prepared read-only reporting; selective deployment needs owner approval.
export { adminReportingCommand } from './modules/analytics/admin-reporting-callable';
// Prepared aggregate-only backup analytics; deployment requires exact owner approval.
export { adminWorkoutReportingCommand } from './modules/analytics/admin-workout-reporting-callable';
// Prepared check-in aggregates only; selective deployment requires owner approval.
export { adminCheckInReportingCommand } from './modules/analytics/admin-check-in-reporting-callable';
// Prepared Admin shop publication; no configuration or deployment is implied.
export { rewardCatalogCommand } from './modules/gamification/reward-catalog-callable';
// Prepared supported-game content only; selective deployment requires owner approval.
export { miniGameContentCommand } from './modules/content/mini-game-content-callables';
