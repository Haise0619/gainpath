# Xendit booking checkout

1. Add a Test Mode hosted-session adapter and test MYR amount conversion, selected-channel routing and provider-confirmed completion.
2. Route new booking payments to Xendit when configured. Keep existing Billplz bookings readable and reuse the authoritative booking settlement.
3. Wire the webhook and mobile checkout URL, and include Xendit in Admin and booking projections.
4. Run focused backend and Flutter checks. Verify actual provider channels once Test Mode credentials are configured.

## Test Mode settings

- Store the Xendit Test Mode Secret API Key with money-in Write permission in Firebase Secret Manager as `XENDIT_TEST_API_KEY`.
- Store the Xendit webhook verification token as `XENDIT_TEST_WEBHOOK_TOKEN`.
- Set `XENDIT_BOOKING_ENABLED=true` for the Functions environment after the secrets are ready. `XENDIT_BOOKING_CHANNELS` defaults to `CIMB_FPX,TOUCHNGO,CARDS`. Include `GRABPAY` or `SHOPEEPAY` only when verified in the account.
- Register the existing `paymentWebhook` URL under Test Mode → Payment Session → Completed. JSON requests go through Xendit token verification. Verify the test delivery before checkout acceptance.
- Complete one payment per enabled category and one cancel/return. Check booking status and the Admin payment record. Automatic Xendit refunds are outside this integration.

## Deployment verification

GainPath project `gainpath-0619` has both Test Mode secrets configured and Xendit enabled on the regional booking checkout callables. Clients advertise Xendit support when creating a checkout and loading the method list. Older clients continue to receive Billplz checkout options.

On 18 November 2026, Xendit created and returned active MYR sessions for CIMB FPX, Touch ’n Go and Cards. The deployed webhook rejected a wrong token and accepted an authenticated sample callback. These probes verify credentials, session creation and ingress. Payment settlement from the hosted pages still needs physical-device acceptance.

Fresh verification included 84 focused backend tests, 32 checkout-related Flutter tests and an Android arm64 debug build. The staged APK matches the signer of the currently installed GainPath APK. Rollback and source evidence is under the local ignored `build/xendit-verification/` directory.
