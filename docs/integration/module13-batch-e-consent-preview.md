# Module 13 Batch E: Member consent and privacy settings

2 November 2026 (Malaysia). **Local review implementation; production consent collection remains disabled.** This completes the safely implementable settings preview requested in Batch E sections 5 and 12. It does not approve a notice, establish legal compliance, enroll Members, migrate legacy consent, or release a production transport.

## Location and runtime boundary

The existing journey is `Profile > Settings > Privacy and data > Personalized Recommendations`. The existing Account Settings page and its navigation are preserved. A new tile in the previously clean Privacy & Data page calls a guarded cross-feature navigation helper. That helper accepts only the current-session predicate and opens the settings screen without a repository or notice. It has no transport/fixture switch, callable name, history reader or writer. Its four switches are disabled and off. The page explicitly says that current server state is unavailable and these are default-off preview values rather than saved account choices.

Interactive local review requires explicit constructor injection of `RpcRecommendationConsentRepository`, separate read/command functions and notice display metadata. It is labelled **Synthetic consent review** throughout; confirmations also say that they do not activate production processing. No production notice is bundled. The normal app does not instantiate this repository or substitute synthetic grants.

New source:

- `apps/mobile/lib/features/recommendation/application/recommendation_consent_repository.dart`
- `apps/mobile/lib/features/recommendation/presentation/member/personalized_recommendation_settings_screen.dart`
- `apps/mobile/lib/navigation/recommendation_privacy_navigation.dart`

Existing source changed only for disabled preview entry:

- `apps/mobile/lib/features/identity/presentation/member/privacy_and_data_settings_screen.dart`

All Batch D recommendation/inbox/navigation source and the 40 original unrelated dirty Mobile files are preserved byte for byte. The clean Privacy screen was copied before editing to `build/module13-e/privacy_and_data_settings_screen.before.dart`. Before/after preservation evidence is in `consent-source-freeze-before.json`, `consent-source-freeze-result.json` and `consent-original40-result.json` in that directory.

## Proposed Member wording, awaiting owner approval

These are the actual proposed descriptions shown by the preview, not an approved privacy notice. Each independent purpose starts off; changing one never grants any other purpose. Camera, backup and Coach-sharing choices convey no Module 13 authority.

| Purpose | Proposed description |
| --- | --- |
| Exercise Insights | Use compatible workout form scores and session evidence to describe exercises needing attention. These are educational estimates, not a medical risk assessment. |
| Recommendation Generation | Use eligible exercise evidence to prepare Coach and tutorial suggestions for Admin review. This does not book a Coach or change your workouts. |
| External AI Inference | Send minimized eligible exercise evidence and candidate descriptions to an external AI provider for semantic ranking. Provider, fields, transfer safeguards and retention require approval before release. |
| Recommendation Delivery | Receive Admin-approved suggestions in your existing Notification Center. Opening a suggestion does not create a booking, payment or reward. |

General explanation: **Each purpose is independent and starts off. Camera and backup permissions do not grant recommendation consent.**

Grant confirmation names the selected purpose, repeats its explanation, displays the injected notice/content versions and reviewed history description, and requires an unchecked acknowledgement: **I have read this purpose, notice version and history scope.** The confirmation button remains disabled until checked. Cancel writes nothing. The acknowledgement resets for every new grant. No bulk grant or inherited default exists.

Revoke confirmation: **Stop future use for this purpose. Revoking does not promise deletion of existing records; retention and deletion rules still require review.** Revoke does not require accepting a new notice and remains available for an existing grant even if grant-notice metadata is unavailable. Prior accepted notice/history metadata may remain in the server receipt; the screen labels this as a previous grant with no active history scope.

Footer: **Revocation stops future authorized use for the selected purpose. It does not confirm deletion of prior records. Retention, audit access and deletion rules are pending owner review.**

For the injected local fixture only, the history description is **Only compatible sessions captured from this grant onward.** Its IDs are `synthetic-only-policy`, `synthetic-notice-1` and `synthetic-content-1`. These identifiers exist in test support, not as a production notice registry. A reviewed retained-history policy must state its precise earliest capture boundary and rationale instead. The Member cannot submit or choose a history timestamp.

The server's accepted versions and `historyStartAtMillis` appear per purpose, with an explicit UTC date/time. This is a stored grant receipt rather than a guarantee of current evidence eligibility: trusted capture metadata, current policy compatibility, required other purpose grants and current sources remain separate server gates. Revoking any purpose does not silently change the other stored switches. B/C/D recheck the required purpose combination for their own operations.

## Exact version 2 transport contract

Read: `{schemaVersion: 2, organizationId}`. The authenticated server determines the current Member; there is no client Member ID, mode or fixture ID. It returns the exact `RecommendationConsentV2` document or `null`. Only a successful scoped `null` response means that all four purposes are server-confirmed off at revision zero. Unavailable/error/legacy/malformed/foreign records never become a saved off/on state. Non-null records require schema 2, `module13-purpose-v2-local`, exact scope/fields, total and per-purpose revisions, and complete consistent grant/revoke/notice/history metadata. Revision-zero documents are rejected; absence is represented by `null`. Future timestamps fail closed, including a device clock that cannot validate them.

Grant sends exactly:

```text
schemaVersion: 2
organizationId
commandId
expectedRevision
purpose
action: grant
noticePolicyId
acceptedNoticeVersion
acceptedContentVersion
```

Revoke sends only the six base fields with `action: revoke`. No Member ID, history start, purpose bundle, accepted legacy schema or client-supplied policy authority is transmitted. Identifiers match the server's 1–128 alphanumeric/underscore/hyphen restriction. The response must match the exact `RecommendationConsentReceipt` fields, selected purpose/action, expected global/per-purpose revision and accepted grant versions. Extra sensitive fields fail parsing.

The trusted server remains responsible for Firebase Auth, App Check, active canonical Member/account/org/session checks, policy lookup, transaction CAS, audit and durable actor-bound command receipt. The client verifies its captured session before and after each asynchronous call. Replacing a repository invalidates pending loads/intent presentation. This client is not a substitute for server authorization.

The UI serializes a confirmed intent, generates one bounded command ID and does not optimistically toggle a switch. It reloads current state after both success and failure, because a receipt describes a past command and may no longer describe the current record. CAS conflicts, unknown responses and malformed receipts display safe generic text and reload; no raw server/provider text is exposed. Failed reads clear prior state and disable mutation until a successful reload. Account drift hides all choices and prevents dispatch, including drift during confirmation. Pending old transport responses cannot replace a new session's state.

The explicit repository preserves a caller's command ID/request for durable replay. The preview never automatically retries a mutation or persists a pending grant across restarts. After an uncertain command it reads current state and asks the Member to review before making a new choice. Durable same-ID replay, changed-ID conflict behavior and current authorization are server requirements, not locally fabricated success.

## Unresolved owner decisions and activation prerequisites

1. Approve the controller, purposes, legal basis, actual notice wording, accessible presentation, notice/content versioning, change/re-acknowledgement policy and support/contact route. No real consent may be collected with the provisional text above.
2. Approve the external provider/model, exact minimized payload/provenance fields, prohibited fields, recipient/subprocessor list, region/cross-border safeguards, provider training/use and retention arrangements, and withdrawal implications for in-flight inference. The preview's generic external-provider description is insufficient for release.
3. Select and justify per-purpose `from_grant` or reviewed retained-history policy, exact earliest boundary and treatment of offline uploads/older backups. Implement trusted capture-time metadata and bounded source queries before reading payloads. Upload timestamps/client assertions cannot substitute. Legacy v1 records require an explicit separately reviewed migration; no silent upgrade/default grant is allowed.
4. Approve retention/deletion/redaction and reader access for consent records, audits, command receipts, evidence, runs, leads, prepared recipients, delivered notifications and AI provenance. State which records are retained for accountability and which are removed/redacted after revocation. No retention interval or TTL job is activated here.
5. Approve revocation behavior for queued, in-flight and already delivered recommendations; define safe cache invalidation and already-open-screen behavior. This preview refreshes on demand and after commands; it does not claim continuous server-push revocation updates.
6. Review authenticated versioned production callable registration and its App Check/token/account-lifecycle behavior; bind read/command to the exact captured Member/org session. Production activation requires a reviewed production adapter and notice registry through normal composition. It cannot be achieved through a synthetic/fixture flag. Deploy/release authority remains separate from local preparation.
7. Complete signed-in staging and physical-device UAT, screen-reader/real device nonlinear text scaling and actual notice/provider/history-scope comprehension before release. No APK was built/installed for this work.

Until these decisions and technical gates are resolved: **production consent collection and Module 13 processing remain unavailable/default off; release is NOT READY.** No policies, data, notice registry, production callables or permissions were activated by the preview.

## Local verification and visual evidence

Tests are in `recommendation_consent_repository_test.dart`, `personalized_recommendation_settings_test.dart`, `recommendation_consent_render_test.dart` and `support/recommendation_consent_fixture.dart` under `apps/mobile/test`. **86 tests pass across 9 files, zero failures/skips:** 23 consent repository, 13 consent settings, 7 actual renders, 3 existing privacy, 5 existing Member settings, 5 existing recommendation repository, 17 existing recommendation UI, 10 existing current navigation and 3 existing Notification Center checks. Exact final counts and suite paths are saved in `build/module13-e/consent-test-counts.json`; raw output is `consent-mobile-results.jsonl`. Eight-file scoped analysis reports no issues; architecture and Mobile presentation checks pass. Their output is `consent-analysis.log`, `consent-architecture.log` and `consent-presentation.log`.

Tests were written before the missing repository/screen and observed failing; strict identifier/future-time/revision parsing, pending-transport replacement and revoked-history labeling also have recorded failing regression runs (`consent-*-red.log`). The first image run exposed the shared theme's asynchronous GoogleFonts requests for unbundled Poppins/Inter assets during `runAsync`. The render fixture was corrected to load existing local Barlow/BarlowCondensed and Material Icons, GainPath purple/surface tokens and standard Material widgets directly; no shared production theme or font manifests changed.

Seven actual Flutter widget images are generated and inspected, with readable purpose explanations even while switches are disabled:

- [375px preview](../../build/module13-e/consent-preview-375.png)
- [393px preview](../../build/module13-e/consent-preview-393.png)
- [393px at 1.6× text](../../build/module13-e/consent-accessible-393.png)
- [851×393 landscape](../../build/module13-e/consent-landscape-851.png)
- [Synthetic server grant and independent off purposes](../../build/module13-e/consent-synthetic-granted.png)
- [Notice/history acknowledgement confirmation](../../build/module13-e/consent-grant-confirmation.png)
- [AI/delivery purposes and retention wording](../../build/module13-e/consent-delivery-scope.png)

The long AppBar title ellipsizes at enlarged text, while the body remains scrollable and every purpose is reachable. These are synthetic widget renders with a local font/token fixture theme, not signed-in staging, browser or physical-device screenshots. They do not prove production writes, media access or release availability.

Reproduce from `apps/mobile` with the cached Flutter tool (no dependency resolution/build):

```powershell
$env:FLUTTER_ROOT = 'C:/flutter'
& 'C:/flutter/bin/cache/dart-sdk/bin/dart.exe' 'C:/flutter/bin/cache/flutter_tools.snapshot' test --no-pub test/recommendation_consent_repository_test.dart test/personalized_recommendation_settings_test.dart test/recommendation_consent_render_test.dart test/privacy_and_data_settings_test.dart test/member_recommendation_repository_test.dart test/member_recommendation_ui_test.dart test/member_recommendation_navigation_test.dart test/member_notifications_screen_test.dart test/member_settings_flow_test.dart --reporter json
```

The SDK cache lockfile requires normal local filesystem access; the restricted sandbox's first attempt was denied before testing. No package resolution, network/provider request, real Member data, production write, deployment, build or installation was performed.
