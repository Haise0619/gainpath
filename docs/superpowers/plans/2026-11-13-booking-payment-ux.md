# Billplz Sandbox booking checkout implementation plan

> Implement directly as requested, using executing-plans and test-driven development.

**Goal:** Review → supported payment selection → hosted Sandbox → verified confirmation.

**Design:** Reuse existing held booking, reviewed quote, scoped repository and verification screen. Add an optional repository capability for payment options and gateway-aware creation. Retrieve active Collection methods and gateway availability on the server; expose only their supported intersection. Current read-only inspection shows only `billplz` enabled, so no FPX, card or wallet choice is claimed for the configured Collection. FPX banks appear only when actually enabled. Preserve provider fallback and simulator controls outside GainPath.

**Reference compatibility:** Legacy bills keep booking/org references untouched. Only newly created, explicitly selected direct bills use version2: gateway in reference1 and a deterministic organization/booking binding in reference2, both persisted before provider creation and checked during settlement/Admin recovery/refunds. Never rewrite existing bills or change their payment method. Keep original booking/org IDs and all existing transaction fields. Unknown creation is quarantined without retrying provider POST.

**Alternatives:** A fake bank list or automatic Sandbox success violates requirements. Unversioned reference replacement breaks reconciliation. A versioned new-bill contract plus original-bill recovery supports the official direct gateway safely. No deployment/configuration change or live booking mutation is included.

## Work

- [x] Pin provider discovery, direct form/URL, invalid gateway, old/new reconciliation, duplicate creation/recovery and authorization behavior with failing tests; implement backend and contracts.
- [x] Add validated domain payment option models and optional repository capability; test transport and stale-account handling.
- [x] Add payment selection after review, polished redirect/verification and server-confirmed receipt, and real My Bookings navigation. Preserve legacy injected clients and recovery flows.
- [x] Test account switching, stale callbacks, pending/failure/expiry/quote changes and duplicate bills; run Firestore Emulator, scoped analysis, domain/backend/mobile tests and Android debug build.
- [x] Render and inspect actual Flutter screenshots at320/360/390px, including200percent text. Review payment integrity, document actual provider limits and commit scoped changes.

**Review focus:** method availability can change after selection; duplicate requests may choose another bank; provider POST may succeed before transport timeout; account can change at any await; paid after expiry must remain payment-received/booking-unconfirmed; legacy30-minute records must remain readable.
