# Member Coach Booking consumer redesign

Implemented 13 November 2026. Initial source/local acceptance is recorded below; the paired live activation that followed the reported device error is recorded at the end.

## Business rules

- All new holds and new availability/quotation requests use **60 minutes**, with existing valid 30-minute start boundaries. The published server-authoritative per-session fee is unchanged: no doubling or proration.
- Historical 30-minute bookings, receipt replay, checkout, refunds and same-duration rescheduling remain supported. Replacement availability requires ownership of the original confirmed appointment and retains its coach, branch and duration.
- New booking eligibility still requires active Basic/Premium, verified email, App Check, active account/organization and shared branch access. Coach publication, credentials, current availability, member/coach overlap, capacity and advance windows remain enforced server-side.
- Membership expiry does not delete or cancel already purchased confirmed sessions. Existing ownership-authorized management remains separate from buying new sessions. Organization suspension/account revocation still restricts access.
- There is no new requirement that the appointment occur before paid membership expiry. Whether an existing purchased session grants gym admission after membership expiry is unresolved; this change grants no additional gym admission entitlement and does not shorten existing purchases.
- Member cancellation remains at least 12 hours before start; rescheduling remains at least 24 hours. Server time and exact accepted boundaries remain authoritative. Failed replacement never releases the original slot.

## Member journey

**Choose Coach → Select Date → Select Starting Time → Review Booking → Temporary Reservation → Billplz Sandbox → Verified Confirmation**

1. Selection shows actual coach and branch names, fixed session length and current price, compact horizontal dates and responsive time buttons. Internal branch IDs and repeated timezone strings are omitted. MYT is shown once. Empty dates offer another date or bounded next-available search using real server reads.
2. A separate focused review step shows date, start/end, duration, location, fee, optional eligible voucher and final server total. Selection/review alone creates no reservation or payment. A sticky primary action remains accessible at large text sizes.
3. Reserve creates an idempotent hold. Unknown transport outcomes keep the same request and retry path; toolbar/system back cannot strand that request. Entering review resets the scroll position so the new step starts at its heading.
4. Payment shows the actual hold-expiry countdown, one Continue to Payment action and optional safe unpaid cancellation. It does not automatically launch the browser. Server time plus elapsed time anchors the countdown; resume refreshes status. Reopening does not extend the hold.
5. A local elapsed timer is not proof that no money arrived. Returning to choose another time first reconciles/closes the owned hold through the server; failure retains the original reservation for status recovery.
6. Payment verification and refund progress use trusted backend evidence. Browser redirect is never booking confirmation. Paid-but-unconfirmed outcomes show Payment needs review, with status checking and a gym-support path. Existing bills are reused.

## Pricing safety and compatibility

Reviewed checkout supplies an opaque server-generated quotation fingerprint. The backend recomputes it transactionally from the current organization/member/coach/branch/duration, currency, gross/net amounts and full voucher snapshot. Client amounts are never charged as authority.

Changed or withdrawn offers fail **before** transaction creation, voucher reservation or Billplz bill creation. Callable error details survive transport as `booking-quote-changed`; the UI reloads the quote and requires explicit acceptance of the updated total. Voucher failure falls back to standard-price review with explicit consent, not silent checkout. Existing transactions return first so a later fee change cannot break idempotent recovery.

Human names, quotation tokens and payment/refund list evidence use additive, opt-in response fields so their legacy strict readers retain the original response shape. Payment create/read replies also add a server timestamp, accepted as optional by the existing payment decoder. The new client and matching Functions must be released together; no deployment was performed here.

## My Bookings, completion and refunds

- Upcoming, a distinct Awaiting Payment section and Past & Cancelled prioritize coach, friendly date/time, location and one relevant action. Full-size labels wrap/stack at large text scales rather than shrinking.
- Cards and details show supported refund states from the matching authorized transaction: under review, approved but not sent, processing, completed or needs attention. Cancellation alone does not prove refund. View Refund Details opens the existing payment status route; no arrival date is invented.
- Payment evidence is projected only for the owned/matching booking transaction and current participant/organization/branch scope. No new client writes to bookings or financial records are allowed.
- Session ended, Completed, published consultation notes and submitted review remain distinct. Ended sessions explain notes are pending; time passing does not mark service delivered. Existing coach Awaiting notes filters/indicators already expose this pending task, so no new scheduled reminder or notification job was added.
- Review authorization, once-per-booking submission, consultation notes, chat, cancellation and payment destinations remain intact. No historical data was rewritten.

## Design and screenshots

Production widgets reuse GainPath purple, Barlow typography, light surfaces, lavender accents and rounded controls. Date/time choices have visible selected states, Material interaction feedback, accessible labels and natural text wrapping. No custom continuous animation was added; existing platform/navigation and reduced-motion conventions remain.

Actual Flutter fixture captures were generated and inspected, not image mockups. They contain synthetic accounts/appointments only. The repository offline font helper substitutes bundled Barlow for Poppins/Inter fallback fonts; production fonts were not changed.

| State | Evidence directory under `build/booking-consumer-20261113/` |
| --- | --- |
| Original selection, selected time and empty date | `selection-before/` |
| New selection, selected time, empty date and review | `selection-after-final/` (24 width/scale/state scenarios, 37 scroll captures) |
| Original and new hold, verification, confirmed and refund payment screens | `payment/` (45 captures including large-text scroll segments) |
| Original My Bookings | `before/` (12 captures) |
| New Upcoming, Awaiting Payment, Past & Cancelled, cancellation/refund details | `after/` (30 captures) |

Final layouts cover **320/360/390dp at 100% and 200% text**. Old selection's fixed-height date rail overflowed by 19px at 200%; the replacement renders without that overflow. Original selection baseline was captured at normal scale after documenting that failure. Secondary screenshots include scrolled controls at 200%.

Example paths:

- Before: `selection-before/selected-390-100-0.png`
- After: `selection-after-final/available-390-100-0.png`
- Review: `selection-after-final/review-320-200-0.png`
- Hold: `payment/hold-320-1x.png`
- Refund: `after/refund-progress-320-2x.png`

The original selection images were captured before production edits. Merely setting a `before` filename against the new selection code does not recreate the old screen. Payment retains a test-only frozen baseline widget for reproducibility.

## Verification results

| Check | Result |
| --- | --- |
| Integrated Mobile booking/payment/transport/management suite, 19 files | **132 passed** |
| Same Mobile suite from isolated HEAD source plus only this task's 55 files | **132 passed** |
| Complete Domain suite | **194 passed** |
| Complete Firebase Functions suite | **2,124 passed; 1 failed** |
| Dedicated Firestore Emulator: payment, member changes, lifecycle | **12 passed** across 3 suites |
| TypeScript source and test typechecks | **Passed** |
| Changed Dart analysis, 33 files | **0 errors, 0 warnings; 8 unchanged informational string-style lints** |
| Final selection/review render test | **Passed**, all 24 scenarios |
| Payment and My Bookings fixture/render suites | **Passed**, required widths/scales and scrolled states |
| Android Debug, working checkout | **Passed**, Gradle 45.7s |
| Android Debug, isolated source excluding unrelated dirty files | **Passed**, Gradle 56.7s |
| Independent review | Uncertain-request back-navigation issue reproduced and fixed; no remaining high-confidence actionable findings |

The single Functions failure is `test/fyp-live-package.test.ts:20`, which explicitly requires `process.version` to start with `v22`; this machine runs **Node v24.19.0**. It was not hidden or changed to weaken the runtime requirement. A Node 22 full-suite rerun remains outstanding. Earlier loopback HTTP permission failures passed after the same tests ran with the required local-process permissions.

Emulator coverage includes changed quote creating no transaction/bill, concurrent reviewed checkout creating one attempt, existing checkout recovery after a price change, expiry and atomic replacement/cancellation races. No emulator result is presented as live Billplz UAT.

Logs and manifests: `backend-files.json`, `all-source-files.json`, `functions-full-elevated.log`, `booking-emulator.log`, `domain-full.log`, `analysis-final.log`, `isolated-mobile-tests.log`, `isolated-android-debug.log`. Additional integration/render logs are under repository `build/booking-*.log`. All 55 intended source blobs were compared with the isolated tested/built copy before committing.

## Commits and acceptance limits

- `f9ddb9e` — fixed-duration backend/domain/transport, reviewed prices and scoped refund projections.
- `2f03b37` — consumer selection/review, payment, list/details and regression/render coverage.

Unrelated uncommitted Admin, Home, Rewards, pose and documentation work is preserved. No live Functions/Rules/config were deployed, no payment/refund executed, no production booking modified, and no APK installed. Real provider/browser handoff, device accessibility, live callback timing and end-to-end bank refund completion still need authorized Sandbox/device acceptance. Deploy the matching backend before making the new client available to live accounts.

## Paired booking backend activation — 13 November 2026

The owner subsequently reported the redesigned Book a session screen failing immediately with “Check the booking date, duration and selected time.” Read-only reproduction using the existing synthetic Basic fixture confirmed a release mismatch: the deployed options handler accepted the legacy 60-minute request (HTTP200), but rejected the new `includeDisplayNames:true` request (HTTP400, `Unsupported scheduling field.`). This was not a date-selection error.

Under the existing standing scoped-deployment authorization, the seven existing Singapore callables were updated from committed source `38234a4`: `getMemberBookingOptionsCommand`, `getBookingPaymentQuoteCommand`, `createBookingPaymentCommand`, `getBookingPaymentCommand`, `createBookingHold`, the actual read alias `getBookingListReadCommand`, and `fitnessAssistantCommand`. This activates the paired fixed60/quotation/list contract; no Firestore migration, financial configuration, secrets, IAM or other service changes were performed.

The sealed 40-file package exports only those seven functions. SHA256: `83b2d6a4775c4fc95037ffe9dd08cdc7db9b8d1fc598b7baf986c46137ded3fe`. All seven deployed archives match it. Their existing Node22 runtime, environment, secret bindings, service settings and IAM were verified preserved; unrelated Function revisions/source remained unchanged. Each prior source archive and its config/IAM snapshot is retained for rollback under ignored `build/booking-live-fix-20261113/`.

Fresh activation checks: 190 affected service/callback regressions pass; exact-package five contract cases and seven export/App Check source checks pass; independent package review found no blocking issue. Live synthetic Basic reads now return HTTP200 for display-name options, reviewed quotation and the list's payment-detail flag. Coach/branch names resolve and the next available date has 15 real options (four dates checked). The legacy60 read still returns200 without new optional fields; new30 options reject with400; anonymous access rejects with401. No hold, bill, payment/refund or booking-data write was created by these probes.

No APK was installed for this server correction. Re-enter Book a session or use Try again to replace the cached failed request. Owner-device visual acceptance and actual Sandbox provider/payment/refund UAT remain separate; the live checks above use the existing synthetic fixture, not the owner's account. Minor pre-existing assistant wording still mentions30/60 choices although new30 requests are rejected; it does not bypass fixed60 enforcement.
