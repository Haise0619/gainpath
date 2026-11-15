# Module 13 published v2 Tutorial compatibility

The identified Member's genuine saved Squat reached Firestore and the automatic trigger returned successfully, but no recommendation was created. Ordinary published tutorials use `kind: routine_v2`, whereas candidate discovery and current-target resolution accepted only legacy `routine` publications.

Added one shared content-kind predicate: retain legacy `routine` behavior and admit `routine_v2` only with schema version 2. Candidate discovery, the automatic target resolver and the protected legacy target projector now use it. Published status, archive/activity checks, current catalog activity, exact exercise/index/day, instructional media, existing eligibility gates, consent and delivery receipts remain enforced. No model admission policy, score, workout, consent or ranking rule was changed.

Verification before release:

- Reproduced failed v2 automatic generation and v2 target resolution before the fix.
- 380 focused Backend tests passed across 37 files; TypeScript source/test check passed.
- 41 Flutter checks passed, including opening the existing Tutorial screen from a real parsed v2 publication contract, v1/Coach compatibility, publication and consent behavior.
- Two authenticated Firebase Emulator flows passed: ordinary Member with only v2 tutorials, and legacy FYP tutorials. Actual Firestore events, delivery receipts, Inbox, unified Admin, replay deduplication and dismissal were exercised. Twelve unrelated integration scenarios were intentionally unselected in this targeted run.
- A read-only run of the corrected engine against the identified Member's actual stored Squat and current consent selected an existing published v2 Squat tutorial. It performed zero recommendation/consent/workout writes and no Gemini calls.
- The exact selected live publication was decoded with the actual Flutter model at its bound exercise index; that check and navigation/contract checks passed (14 tests).
- Focused Flutter test analysis passed. Independent scoped review found no actionable issues.

Private evidence and reviewed source package: `build/module13-v2-tutorial-fix-20261115/`. The source archive exports the same eight endpoints with unchanged declared settings. SHA-256: `c9ba2c934f8c8de5904cd034ea2f3b8aab9cd93cb2b216645aeaa4986e7659b2`.

No production Flutter code change is needed for this compatibility fix; the current Tutorial route and SDK catalog already support v2. Unrelated in-progress Workout UI/assets are excluded. Source-only deployment and the identified workout's normal service reevaluation are recorded separately after verification. No source change authorizes fabricated delivery or bypassing privacy/cooldown checks.

## Source-only release and identified-workout recovery

The owner's instruction to directly fix the workflow followed the proposed compatibility fix, deployment and reevaluation steps. The same eight previously approved Module 13 endpoints were updated using `buildConfig.source` only. All eight are ACTIVE and their downloaded source hashes match the reviewed archive. Runtime/event settings, IAM and Firestore Rules are unchanged; all 71 unrelated Functions retain their exact metadata. Previous sources for all eight endpoints were captured for rollback. Code commit: `5e7aaf5`.

After source verification, the existing `evaluateSavedWorkout` lifecycle reevaluated only the identified Member's already-stored Squat. The maintenance wrapper allowed writes only to that exact source/owner/consent-bound recommendation, receipt, Inbox and cooldown paths. Current identity, consent, content eligibility, cooldown and idempotency were still enforced by the normal service; no hand-authored recommendation or delivered status was inserted.

Result: one content recommendation was created with a matching canonical delivery receipt and the same owner's Inbox notification. A second evaluation returned no new recommendation and produced no duplicate notification. Full before/after hashes confirm the original Workout backup and purpose-consent record are unchanged. Gemini calls: zero. This is verified in-app Inbox delivery, not a claim that the Member has opened it or that an operating-system push was displayed.

Private verification: `deployment-verified.json`, `owner-reevaluation-verified.private.json`, per-endpoint operation/status records, rollback ZIPs and `owner-reevaluation-intent.private.json` under the evidence directory. Personal identities and Workout payloads are not committed. A new camera workout exercising the newly deployed trigger remains a physical acceptance step; the updated automatic v2 event flow is covered by the authenticated Emulator test.
