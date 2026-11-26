import { defineSecret, defineString } from 'firebase-functions/params';
import { DomainError } from '../../platform/errors';
import { XenditBookingGateway } from './xendit-booking';

export const xenditKey = defineSecret('XENDIT_TEST_API_KEY');
export const xenditEnabled = defineString('XENDIT_BOOKING_ENABLED', { default: 'false' });
const xenditChannels = defineString('XENDIT_BOOKING_CHANNELS', { default: 'CIMB_FPX,TOUCHNGO,CARDS' });
export function requireXenditCheckout() {
  if (xenditEnabled.value() !== 'true') throw new DomainError('unavailable', 'Xendit Test checkout is disabled.');
}

export function xenditReturnUrl() {
  const project = process.env.GCLOUD_PROJECT ?? process.env.GOOGLE_CLOUD_PROJECT;
  if (!project || !/^[a-z0-9-]+$/.test(project)) {
    throw new DomainError('unavailable', 'Payment is temporarily unavailable.');
  }
  return `https://us-central1-${project}.cloudfunctions.net/billplzSandboxReturn`;
}

export function xenditGateway() {
  return new XenditBookingGateway(xenditKey.value(), xenditReturnUrl(),
    new Set(xenditChannels.value().split(',').map(channel => channel.trim())));
}
