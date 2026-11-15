# Module 13 consent loading — client region correction

The owner observed “Could not load current consent” with disabled controls. A confirmed client defect affected ordinary Member requests: `FirebaseMemberRecommendations` uses the shared `FunctionEndpointSelector`, whose unknown-command fallback is `us-central1`. The new `module13MemberCommand` and `module13AdminCommand` were missing from the selector despite being deployed only in `asia-southeast1`. Existing direct HTTPS smoke tests used the correct Singapore URL and therefore did not exercise this client address-selection defect. FYP has its own already-pinned transport; this fix does not alter its scope or permissions.

The selector now pins exactly these two new APIs to Singapore. They are not redirected to an undeployed US endpoint by rollback flags for older services. Existing booking/payment aliases, old callable rollout/rollback behavior, validation and unknown/held command behavior remain unchanged. There is no payload, consent, data, IAM or backend deployment change.

Evidence:

- Added an endpoint regression and reproduced `us-central1` where Singapore was required before the fix.
- Seven endpoint tests pass afterward, including original booking/payment and rollback mappings.
- 51 affected Flutter checks pass, covering transport overrides, consent reads/mutations/confirmation, ownership, errors/retry and recommendation rendering.
- The Flutter checks include decoding freshly fetched live ordinary/FYP consent responses using the actual Dart repository. Snapshots remain private; no consent mutation is performed by the live probes. The ordinary account has no prior consent, which correctly parses to default-off choices.
- Twelve fresh authenticated live Auth/App Check/role/organization/isolation checks pass through the Singapore endpoints. Existing sample credentials were reused, no account/password changes or Gemini requests were made.
- Focused Dart analysis: no issues.
- Isolated Android Debug build: passed, 16.6 seconds. The isolated tree includes the preceding two backup fixes plus this selector correction; unrelated in-progress UI/assets are excluded.

Private evidence: `build/module13-consent-load-20261115/`. Live snapshots and operational logs are excluded from source control. The client screenshot's exact active account and installed binary were not inspected; real-device acceptance remains pending.

Load the updated source with **Android Studio → GainPath Member — Android → Stop → Run**, reopen **Personalized Recommendations**, and use **Reload current state**. The page must load current server choices before enabling edits; it never fabricates permission or auto-grants it to hide a read error.
