import { initializeApp } from 'firebase-admin/app';

initializeApp();

export { bookingConsultationNotesCommand } from './modules/coaching/booking-consultation-callable';

export { bookingCommunicationCommand } from './modules/coaching/booking-communication-callable';

export { createBookingHold } from './modules/coaching/create-booking-hold';
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

export { deliverBookingNotificationWorker } from './modules/coaching/booking-notification-worker';
export { identifyEquipmentCommand } from './modules/workouts/equipment-scanner-callable';
