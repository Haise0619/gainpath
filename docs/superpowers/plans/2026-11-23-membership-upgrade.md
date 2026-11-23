# Membership upgrade implementation plan

**Goal**

Give verified Basic members two one-time Premium options and clearly identify existing orders before a member can continue payment.

**Approved design**

- Upgrade now and extend. Charge the current 30-day Premium price plus the Basic-to-Premium price difference prorated over the remaining Basic time. Premium begins on confirmed payment and ends 30 days after Basic's prior expiry.
- Start Premium after Basic. Charge the current 30-day Premium price once. Basic remains effective until its expiry. Premium starts automatically at that boundary or when a later payment is confirmed and lasts 30 elapsed days.
- An existing unpaid order stays payable on its original terms. Before opening it from a different selection, identify the original plan, amount and payment type. Keep same-request retries idempotent.
- Preserve any prorated-only order issued by the 20 November release. A new upgrade needs a current option and its server-issued quote. A member who retries a recovered checkout receives the bound order even if it has since closed or cleared.

**Implementation and checks**

- [x] Add service tests for authoritative quotes, changed Basic or catalogue data, settlement and callback replay, scheduled access at expiry, and recovery of a different order. Integrate both upgrade modes into the existing membership quote, payment, overview and effective-tier paths. Reuse `MembershipPurchase` for compatibility with financial readers and store the upgrade mode on the receipt.
- [x] Add a scheduled-term entitlement check to the Coach directory Rules and verify with the membership and Coach directory emulators. Schedule activation follows server time without a background writer.
- [x] Add focused Member widget cases for both upgrade entry points, a server-quoted payment breakdown, a scheduled upgrade, and the old-order confirmation. Carry the selected mode through the Firebase repository and retain compatible behavior when an old server omits upgrade support.
- [x] Verify affected Functions, Domain and Flutter tests, type checks, Rules and Android build. Record release limits and request independent review.

Use the existing Billplz Sandbox and status reconciliation. An immediate-upgrade quote is short-lived and binds the paid Basic term and both catalogue versions. An immediate upgrade whose Basic term ends before confirmation enters payment review. Only one paid future Premium term may be scheduled at a time. Existing verified Basic time and membership receipts are preserved. No recurring billing or real payment operation is part of implementing this design.

**Release sequence**

Use the current 20 November Functions deployments as packaging baselines. Stage and verify every effective-tier reader, Coach directory Rules, and both Billplz webhook regions before allowing the new payment-create flow. `getMembershipPaymentCommand` and `manageAdminBookingPaymentCommand` must also use the new settlement code before `createMembershipPaymentCommand` accepts the new modes. Old settlement code can classify a valid upgrade as a final cleared payment requiring review. Deploy the quote callable and upgrade-capable overview after the supporting readers and promote the compatible Member APK once all endpoints agree. The read-only FYP overview excludes the upgrade capability flag.

**Local verification**

- 153 Functions tests, 10 Firestore emulator tests, 74 Flutter tests, and 11 Domain tests passed. Functions source and test type checks and scoped Flutter analysis passed.
- Reviewed the upgrade options, immediate quote, scheduled membership, and 320 dp checkout at 200% text. The render suite generated 48 upgrade images across 12 viewport and text-scale combinations.
- The arm64 Android Debug APK built successfully. SHA-256 `465e7e4525f9c88b3f313babb9dc6bf3bfceefa7e58f9ddb5d435826ed6f8414`.
- Independent review covered lost Basic receipt evidence, legacy orders, recovery replay, quote errors and coordinated settlement rollout. Firebase release, physical-device acceptance and external Billplz acceptance are pending.
