# Member private profile and preferences CRUD repair — 2026-10-15

Source baseline: `6dd91d90980dcd351b9f3aec297f0e885aa60b30`. This is local source/test evidence. No live API, personal profile/preference write, deployment, APK build/install, staging, or commit was performed by this repair.

## Behavior and preservation

Before the repair, two sessions could load the same private record and later replace each other's unrelated edits through unconditional full-document writes. A successful save displayed submitted values without authoritative read-back. Private-record Rules also accepted an old active membership after the canonical user organization assignment changed.

After the repair:

- Loaded domain values carry optional opaque `editBaseline` provenance. `copyWith` preserves the original provenance even when the same repository later loads a newer record. The baseline belongs to one repository lifetime and contains a deep immutable full document snapshot, including existing `updatedAt`; it is never serialized.
- The existing `FitnessProfileGateway.write` port accepts the expected snapshot separately from its serialized patch. Existing domain repository save contracts remain `Future<void>`; no parallel repository/model or new dependency was introduced.
- Each Firestore transaction compares its current full snapshot to the original form snapshot on every attempt. Any difference rejects the stale form. Existing records receive only intended changed editable fields plus server `updatedAt`; creation writes the full existing schema only if the server record is still missing. There is no automatic merging or rebasing.
- Profile creation without provenance requires a successful missing-record load on that repository first. Preferences return a provenance-bearing default value for a confirmed missing record. Missing and never-loaded are distinct states; concurrent creation is rejected.
- Save completion is followed by a server load. Profile/settings UI renders the validated returned record. Failed or uncertain verification preserves the previous displayed record and keeps the form open. Conflict/deadline errors require an explicit reload; profile reload clearly discards the open draft, and settings disable further changes until reload.
- Adapters check UID and the supplied current-session guard before/after asynchronous work and inside transaction attempts. Mobile composition supplies the Member role/scope guard. Rules remain authoritative for backend assignment changes.
- Only the two private-record Rules owner predicates were changed by this Member repair: canonical `users/{uid}.organizationId` and membership `organizationId` must both equal the requested organization, in addition to existing verified/active/Member/owner checks.

## Exact physical contract

| Record | Canonical path | Unchanged serialized fields |
|---|---|---|
| Fitness profile | `orgs/{orgId}/profiles/{uid}` | `schemaVersion: 1`, `gender`, integer `age`, `heightCm`, `weightKg`, `experience`, `activity`, goal-category `goals`, server `updatedAt` |
| Preferences | `orgs/{orgId}/preferences/{uid}` | `schemaVersion: 1`, boolean `pushNotifications`, `emailUpdates`, `voiceCoaching`, server `updatedAt` |

Existing numeric ranges, enum/category allowlists, owner-only reads/writes, and denied list/delete operations are preserved. No numeric milestone goals, picture/contact fields, revision fields, collections, migrations, notification service, or workout/voice behavior were added. Identity, membership authority, accepted history, pose/core algorithms, consent/outbox, booking, and tutorial behavior are outside this patch.

## Repair paths

The repair touches these **22 source/test paths**, relative to repository root `C:/Users/Ngzhe/StudioProjects/gainpath`. This new evidence report is an additional documentation artifact.

1. `packages/gainpath_domain/lib/src/fitness_profile.dart`
2. `packages/gainpath_domain/lib/src/member_preferences.dart`
3. `packages/gainpath_data/lib/gainpath_data.dart`
4. `packages/gainpath_data/lib/src/member_document_snapshot.dart` — new shared immutable snapshot utility
5. `packages/gainpath_data/lib/src/firebase_fitness_profile_repository.dart`
6. `packages/gainpath_identity/lib/src/fitness_profile_cubit.dart`
7. `apps/mobile/lib/infrastructure/firebase/firebase_fitness_profile_gateway.dart`
8. `apps/mobile/lib/infrastructure/firebase/firebase_member_preferences_repository.dart`
9. `apps/mobile/lib/features/identity/presentation/member/account_settings_screen.dart`
10. `apps/mobile/lib/features/identity/presentation/member/save_live_profile.dart`
11. `apps/mobile/lib/features/identity/presentation/member/profile_setup_screen.dart`
12. `apps/mobile/lib/features/identity/presentation/member/fitness_profile_gate.dart`
13. `apps/mobile/lib/app/mobile_app.dart`
14. `firebase/firestore.rules` — Member ownership predicates only; other sprint changes are separately owned
15. `packages/gainpath_data/test/firebase_fitness_profile_repository_test.dart`
16. `packages/gainpath_identity/test/fitness_profile_cubit_test.dart`
17. `apps/mobile/test/firebase_member_private_documents_test.dart` — new injected SDK-boundary regression suite
18. `apps/mobile/test/member_settings_flow_test.dart`
19. `apps/mobile/test/fitness_profile_flow_test.dart`
20. `apps/mobile/test/fitness_profile_gate_test.dart`
21. `apps/mobile/test/support/fitness_profile_fake.dart`
22. `functions/emulator/firestore-rules.test.ts` — Member reassignment/malformed membership cases only

The existing mobile fixture supports an explicit initial read before direct seed creation; production never-loaded creation rejection is tested separately against the real repository. The gate test now edits its loaded value, retaining provenance.

## Executed local verification

Regression tests were run RED before production changes: authoritative read-back in profile/settings, never-loaded overwrite rejection, stale session overwrites despite a later load, concurrent creation, patch-only updates, original snapshot comparison on transaction retries, initial setup reload recovery, and explicit reload for unconfirmed transaction deadlines. The corresponding focused cases then passed.

Commands used the installed `C:/flutter/bin/cache/dart-sdk/bin/dart.exe`; Flutter commands invoked `C:/flutter/bin/cache/flutter_tools.snapshot`. SDK cache/telemetry access required normal sandbox escalation; no network/live backend test was invoked.

| Command / working directory | Observed result |
|---|---|
| `dart test --reporter expanded` / `packages/gainpath_domain` | 69 passed |
| `dart test --reporter expanded` / `packages/gainpath_data` | 80 passed |
| `flutter test --reporter expanded --no-pub` / `packages/gainpath_identity` | 21 passed |
| `flutter test --reporter expanded --no-pub` / `apps/mobile`, after final semantic deadline handling change | 367 passed, 15 skipped, no failures |
| Focused mobile adapter suite after final whitespace formatting | All 12 passed |
| Targeted `dart analyze` of every edited Dart implementation/test file | No issues found |
| `git diff --check` | Passed |

The complete mobile suite includes the focused profile/settings tests. New Member tests contain no skips. Temporary mobile stdout logs were removed after inspection; command outputs remain in the execution transcript. No retained log file is claimed.

## Boundaries and pending verification

- Parent-coordinated Firestore emulator execution owns the new Rules cases and overall Rules verification. This subtask did not start an emulator. Record the parent result separately; test source alone is not a passing emulator result.
- Adapter tests inject a deterministic Firestore SDK boundary and execute the production transaction callbacks, including a simulated retry. They verify application behavior, not a live multi-device Firestore conflict demonstration.
- No live Member profile/goals/preferences write UAT was performed. The historical [Firebase demo execution report](2026-10-15-firebase-demo-execution.md) explicitly records that boundary and is not amended by these software tests.
- A successful local save/read-back does not prove notification delivery, profile-driven recommendations, personalized coaching behavior, numeric milestone tracking, contact editing, or picture upload.
- Future live personal writes require the owner's exact approved values and before/after snapshot; synthetic source/emulator fixtures do not authorize those writes.
