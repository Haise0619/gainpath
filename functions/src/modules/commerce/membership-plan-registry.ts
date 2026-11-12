import {DomainError} from '../../platform/errors';
export const SUPPORTED_PAID_MEMBERSHIP_PLANS = ['basic', 'premium'] as const;
export function isSupportedPaidPlan(value: unknown): value is 'basic' | 'premium' {
  return value === 'basic' || value === 'premium';
}
/** Only emitted before any new checkout reservation or external bill creation. */
export class MembershipCheckoutError extends DomainError {
  readonly checkoutCreated = false;
  constructor(readonly reason: 'quote_changed' | 'quote_expired' | 'promo_invalid' | 'unsupported_plan', message: string) {
    super('failed-precondition', message);
  }
}
