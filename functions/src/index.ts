import { initializeApp } from 'firebase-admin/app';

initializeApp();

export { createBookingHold } from './modules/coaching/create-booking-hold';
export { paymentWebhook } from './modules/commerce/payment-webhook';
