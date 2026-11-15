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
