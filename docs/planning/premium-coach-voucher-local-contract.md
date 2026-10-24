# Premium Coach voucher local contract

23 October 2026. Local implementation only. No business configuration, cloud write, deployment, payment or refund was performed. The feature is unavailable until a complete trusted policy is separately approved and published.

The existing `getBookingPaymentQuoteCommand` accepts optional boolean `includePremiumVoucher` and `usePremiumVoucher`. Including the offer preserves the full fee; explicitly applying it returns the discounted server total. Both flags require current Auth identity verification, App Check and current organization/Member/lifecycle authority. The existing `createBookingPaymentCommand` accepts optional boolean `usePremiumVoucher`; its only other purchase input remains the booking ID. A client never sends a price, percentage, tier, cycle or voucher ID. Omitted flags preserve the original full-price response fields and billing flow.

An included offer has `status` (`unavailable`, `ineligible`, `available`, `reserved`, `consumed`), and an available/reserved/consumed offer carries `voucherId`, `cycleStartAtMillis`, `cycleEndAtMillis`, `discountMinor`. An applied quote additionally returns `grossAmountMinor`, `discountMinor`, and net `amountMinor`. Payment views and existing Admin review projections retain the immutable `premiumVoucher` snapshot with the approved finance policy references. No separate voucher callable/dashboard/payment provider was introduced.

Trusted configuration belongs at `orgs/{organizationId}/settings/premiumCoachVoucher`. Every field below is required; no production record is provided or created:

| Field | Supported explicit value or decision |
|---|---|
| schemaVersion | 1 |
| policyVersion | Approved identifier, maximum 128 characters |
| enabled | Must be explicitly true after approval; absent/false disables the feature |
| currency / cycleDays | MYR / 30 |
| discountBasisPoints / maximumDiscountMinor | 1000 / 1500 |
| rounding | Explicit `floor` or `half_up` decision |
| fundingSource / coachCommissionBasis | Only the separately approved `gym` / `gross_fee` combination is executable locally |
| financeApprovalId / commissionPolicyVersion | Explicit approval identifier / exactly `sandbox-coach-80-v1`; other commission versions are unavailable |
| eligibleBranchIds / eligibleCoachIds | Explicit nonempty arrays of existing approved identifiers, maximum 100 each; no wildcard |
| eligibleDurationsMinutes | Explicit nonempty subset of 30 and 60 |
| expiry | Only explicit `cycle_end` is supported |
| stacking | Only explicit `none` is supported |
| refund | Only explicit `no_reinstatement` is supported |
| unpaidRecovery | Only explicit `provider_deleted_only` is supported |

These supported choices describe executable code paths, not approved business policy. Alternative funding, net-fee commission, stacking, rollover, reinstatement or expiry rules remain unavailable. Coach performance recognizes the supported 80% on the original gross fee, separately retaining collected cash and discount; platform recognition uses collected cash minus the Coach amount. Invalid snapshots/unsupported versions require review. No Coach payout is executed. Existing Admin payment details display the original fee, saved discount, collected/checkout amount and finance approval reference.

The membership settlement hook `preparePremiumCoachVoucherTerm(tx, organizationId, confirmedPayment, previousAccount)` reads before any transaction writes and returns an apply closure. It is a no-op for non-Premium/non-30-day receipts and absent/malformed policy. A confirmed cleared Premium payment creates one immutable `premiumCoachVoucherTerms/{paymentId}` and advances `premiumCoachVoucherHeads/{memberId}`. The earned period is `[expiresAtMillis - 30 days, expiresAtMillis)`. Renewals link prior terms and cannot overlap. Lazy quote-time evaluation walks up to 64 terms to find the currently earned cycle and revalidates its actual cleared Billplz receipt; an early renewal does not issue its future voucher immediately. No existing accounts or receipts are backfilled. Unsupported durations, missing evidence and excessive/corrupt chains yield unavailable rather than invented entitlements.

Checkout atomically reserves `premiumCoachVouchers/{hash(memberId, cycleStart)}` alongside the existing payment record. Duplicate provider attempts do not create new reservations/bills. Unknown bill creation, due bills, hold expiry and cancellation preserve the reservation. Only an independently retrieved, exactly bound, permanently deleted unpaid Billplz bill releases it; an unknown bill first requires the existing Admin recovery action. Trusted clearance consumes it once even when a closed/ineligible booking requires financial review. Refunds do not automatically restore it. Settlement uses the approved snapshot even when later policy/entitlement changes.

A Membership refund request/approval is review only and does not revoke already-cleared paid time or its existing earned cycle. Historical proof accepts retained valid paid evidence under review; actual money-return/reversal statuses are not treated as unchanged paid grants. The separate Membership refund-transfer and entitlement-reversal policy remains unresolved.

The optional mobile repository capability `PremiumVoucherBookingPaymentRepository` adds `loadVoucherQuote(...)` and `createWithPremiumVoucher(bookingId)` without changing existing repository contracts. The existing booking screen shows unavailable/ineligible/reserved/used states and an explicit apply switch only for a trusted available offer. Selection reloads the server quote; payment and Admin projections show the saved discount.

Focused validation covers missing finance decisions, actual paid evidence/history, exact cycle expiry and early renewal, rounding/cap/client tampering, current Auth/lifecycle denial, concurrent reservation, uncertain attempts, verified deleted recovery, duplicate consumption, unchanged full-price booking behavior and financial projection. The isolated emulator file tests real transaction contention and existing deny-by-default Rules. Provider Sandbox UAT, commercial approval, actual financial accounting/commission review and deployment remain separate gates.
