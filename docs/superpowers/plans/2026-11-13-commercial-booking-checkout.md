# Member commercial checkout and selected-payment traceability

Implement directly as requested, using executing-plans and test-driven development.

**Design:** Retain reviewed60-minute booking/hold and the existing hosted Billplz creation/recovery/verification path. Introduce a server-canonical presentation selection catalog for FPX, wallets and cards; this is preference metadata, not evidence of enabled/used provider rails. No credentials or simulator controls enter GainPath. Member copy says final payment options are presented at secure checkout without exposing environment/configuration details.

**Data:** Clients submit only a known selection code; server derives category/label/icon and `selectedAt` (Unix milliseconds) and persists them once in the original transaction/invoice. Booking views join that exact transaction through existing ownership bindings; no duplicated booking financial source is introduced. New selection-mode discovery is explicitly opted into so old gateway-aware clients and legacy invoices remain compatible. Existing invoices always retain their original choice. Selection metadata cannot alter financial amount, callback evidence, booking status, refunds or references.

**UI:** Compact expandable booking summary, grouped branded placeholder cards, More banks expansion, sticky Continue, selected/pressed motion respecting reduced motion. Review CTA Continue to payment. Redirect shows method/total; return prioritizes automatic verification; success shows both confirmation labels and selected method. Admin financial detail and booking cards show category/label/icon, or Not recorded for legacy records. Reuse GainPath tokens and Barlow.

## Tasks

- [x] Backend red/green: canonical code validation, immutable selection, metadata joins, selection/provider independence, duplicate/unknown bill protection, ownership and quote/expiry regressions.
- [x] Domain/transport red/green: selected method model, optional selection-mode capability, invoice/booking decoding and stale-account protection.
- [x] Member checkout and Admin selected method UI, neutral brand icon slots; regression tests.
- [x] Responsive Flutter screenshots320/360/390dp at100/150/200percent, affected Mobile/Admin/Domain/backend/Emulator tests, analysis, Android Debug and Admin Web Release builds.
- [x] Independent review, clean-source verification, scoped logical commits and operational documentation. No live payment/settings/bookings changes or deployment/installation in this implementation task.

**Review focus:** returning to an existing invoice cannot overwrite its selection; a displayed card/wallet cannot be mistaken for verified provider evidence in Admin; stale account responses cannot leak data; selection failure cannot trigger duplicate provider POST; late paid/expired outcomes keep existing reconciliation handling; legacy30-minute records remain readable.
